"""Health checks for the D4CG status page.

The React app at d4cg-status.pedscommons.org runs these same checks, but only
while somebody has the page open. This Lambda runs them on a schedule and
emails via SNS when something breaks, so an outage is noticed without anyone
watching.

Two invocation paths:

* **EventBridge** (the cron): check every configured endpoint, compare the
  result with the previous run's state in S3, and publish to SNS *only when the
  set of failing endpoints changes*. A service that stays down does not
  re-notify every run; a recovery sends an all-clear.
* **Anything else** (API Gateway, manual invoke): run the same checks and
  return them as JSON. This path never alerts and never writes state, so
  probing by hand cannot suppress or trigger a real alert.

The endpoint list is read from ``config.json`` - the same file the React app
imports, copied into the deployment package by ``build_lambda.sh`` - so the
page and the alerts can never drift apart.
"""

from __future__ import annotations

import json
import logging
import os
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from typing import Any

import boto3
import requests


LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)

# Mirrors the React app: a check that takes longer than this counts as down.
DEFAULT_TIMEOUT_SECONDS = 3.0
DEFAULT_MAX_WORKERS = 12

SUCCESS = "success"
FAIL = "fail"
MAINTENANCE = "maintenance"

_CONFIG_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "config.json")


class ConfigError(RuntimeError):
    """Raised when the packaged configuration is missing or unusable."""


def load_config(path: str | None = None) -> dict[str, Any]:
    """Load the shared status-page configuration."""

    config_path = path or os.environ.get("CONFIG_PATH", _CONFIG_PATH)
    try:
        with open(config_path, encoding="utf-8") as handle:
            config = json.load(handle)
    except FileNotFoundError as exc:
        raise ConfigError(f"config.json not found at {config_path}") from exc
    except json.JSONDecodeError as exc:
        raise ConfigError(f"config.json at {config_path} is not valid JSON") from exc

    if not isinstance(config.get("hostnames"), dict) or not config["hostnames"]:
        raise ConfigError("config.json must contain a non-empty 'hostnames' object")
    return config


def build_targets(config: dict[str, Any]) -> list[dict[str, str]]:
    """Expand the config into a flat list of endpoints to check.

    URLs are joined exactly as the React app does, so the Lambda and the page
    check byte-identical URLs.
    """

    titles = config.get("urlToTitleDataMap") or {}
    targets: list[dict[str, str]] = []
    for host, endpoints in config["hostnames"].items():
        for endpoint in endpoints:
            url = f"{host.rstrip('/')}/{str(endpoint).lstrip('/')}"
            targets.append(
                {
                    "url": url,
                    "host": host,
                    "endpoint": endpoint,
                    # Endpoint paths repeat across hosts (several expose
                    # "/_status"), so the host is kept in the key to make each
                    # target unique.
                    "service": titles.get(endpoint, str(endpoint)),
                }
            )
    return targets


def check_endpoint(
    target: dict[str, str],
    session: Any,
    timeout: float = DEFAULT_TIMEOUT_SECONDS,
) -> dict[str, Any]:
    """Check one endpoint and classify it the same way the React app does."""

    result = {**target, "status": FAIL, "detail": ""}
    try:
        response = session.get(target["url"], timeout=timeout)
    except Exception as exc:  # noqa: BLE001 - any transport error means "down"
        result["detail"] = f"{type(exc).__name__}: {exc}"
        return result

    content_type = (response.headers or {}).get("content-type", "") or ""
    if "application/json" in content_type.lower():
        try:
            body = response.json()
            if isinstance(body, dict):
                declared = str(body.get("status", "")).lower()
                if declared == MAINTENANCE:
                    result["status"] = MAINTENANCE
                    result["detail"] = "reported maintenance"
                    return result
        except ValueError:
            # A malformed JSON body is not itself an outage; fall through to
            # the status-code check below.
            pass

    if response.status_code == 200:
        result["status"] = SUCCESS
    else:
        result["detail"] = f"HTTP {response.status_code}"
    return result


def run_checks(
    targets: list[dict[str, str]],
    session: Any,
    timeout: float = DEFAULT_TIMEOUT_SECONDS,
    max_workers: int = DEFAULT_MAX_WORKERS,
) -> list[dict[str, Any]]:
    """Check every target concurrently and return results in target order."""

    if not targets:
        return []
    workers = max(1, min(max_workers, len(targets)))
    with ThreadPoolExecutor(max_workers=workers) as pool:
        return list(pool.map(lambda t: check_endpoint(t, session, timeout), targets))


def failing_urls(results: list[dict[str, Any]]) -> list[str]:
    """URLs currently considered down.

    ``maintenance`` is deliberately excluded: it is an intentional state and
    should not page anyone.
    """

    return sorted(r["url"] for r in results if r["status"] == FAIL)


# -- previous-run state -----------------------------------------------------
def load_previous_failures(s3_client: Any, bucket: str, key: str) -> list[str] | None:
    """Return the previous run's failing URLs, or None when there is no state.

    None means "first run" and is treated as "no alert", so deploying the
    Lambda does not immediately email about services that were already down.
    """

    if not bucket:
        return None
    try:
        response = s3_client.get_object(Bucket=bucket, Key=key)
    except Exception as exc:  # noqa: BLE001 - missing key or first deploy
        LOGGER.info("No previous state at s3://%s/%s (%s)", bucket, key, exc)
        return None

    try:
        body = response["Body"].read()
        stored = json.loads(body)
        failures = stored.get("failing", [])
        return sorted(str(url) for url in failures)
    except Exception as exc:  # noqa: BLE001 - corrupt state must not break the run
        LOGGER.warning("Ignoring unreadable state at s3://%s/%s: %s", bucket, key, exc)
        return None


def save_state(
    s3_client: Any,
    bucket: str,
    key: str,
    failures: list[str],
    results: list[dict[str, Any]],
) -> None:
    if not bucket:
        LOGGER.warning("STATE_BUCKET is unset; state not persisted")
        return
    payload = {
        "failing": failures,
        "checked_at": datetime.now(timezone.utc).isoformat(),
        "results": results,
    }
    s3_client.put_object(
        Bucket=bucket,
        Key=key,
        Body=json.dumps(payload, indent=2).encode("utf-8"),
        ContentType="application/json",
    )


# -- notification -----------------------------------------------------------
def build_message(
    current: list[str],
    previous: list[str],
    results: list[dict[str, Any]],
) -> tuple[str, str]:
    """Build the (subject, body) describing what changed since the last run."""

    newly_down = [url for url in current if url not in previous]
    recovered = [url for url in previous if url not in current]
    by_url = {r["url"]: r for r in results}

    if not current:
        subject = "[D4CG status] RESOLVED - all services operational"
    else:
        subject = f"[D4CG status] {len(current)} service(s) DOWN"

    lines = [f"Checked at {datetime.now(timezone.utc).isoformat()}", ""]

    if newly_down:
        lines.append("Newly down:")
        for url in newly_down:
            result = by_url.get(url, {})
            detail = result.get("detail") or "no response"
            lines.append(f"  - {result.get('service', url)} ({url}) - {detail}")
        lines.append("")

    if recovered:
        lines.append("Recovered:")
        for url in recovered:
            lines.append(f"  - {by_url.get(url, {}).get('service', url)} ({url})")
        lines.append("")

    still_down = [url for url in current if url in previous]
    if still_down:
        lines.append("Still down:")
        for url in still_down:
            lines.append(f"  - {by_url.get(url, {}).get('service', url)} ({url})")
        lines.append("")

    maintenance = [r for r in results if r["status"] == MAINTENANCE]
    if maintenance:
        lines.append("In maintenance (not alerting):")
        for result in maintenance:
            lines.append(f"  - {result['service']} ({result['url']})")
        lines.append("")

    lines.append("Status page: https://d4cg-status.pedscommons.org")
    return subject, "\n".join(lines)


def publish(sns_client: Any, topic_arn: str, subject: str, body: str) -> None:
    if not topic_arn:
        LOGGER.warning("SNS_TOPIC_ARN is unset; skipping notification")
        return
    # SNS caps Subject at 100 characters.
    sns_client.publish(TopicArn=topic_arn, Subject=subject[:100], Message=body)


# -- entry point ------------------------------------------------------------
def _invoked_by(event: Any) -> str:
    if isinstance(event, dict):
        if "httpMethod" in event or "requestContext" in event:
            return "apigateway"
        if event.get("source") == "aws.events":
            return "eventbridge"
    return "unknown"


def handler(event, context):  # noqa: ANN001 - AWS Lambda signature
    invoked_by = _invoked_by(event)
    config = load_config()
    targets = build_targets(config)
    timeout = float(os.environ.get("REQUEST_TIMEOUT", DEFAULT_TIMEOUT_SECONDS))

    session = requests.Session()
    try:
        results = run_checks(targets, session, timeout=timeout)
    finally:
        session.close()

    current = failing_urls(results)
    LOGGER.info(
        "Checked %s endpoints; %s failing (invoked by %s)",
        len(results),
        len(current),
        invoked_by,
    )

    # Only the scheduled run alerts and records state. Any other invocation is
    # a read-only probe.
    if invoked_by != "eventbridge":
        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps(
                {
                    "invoked_by": invoked_by,
                    "failing": current,
                    "results": results,
                }
            ),
        }

    bucket = os.environ.get("STATE_BUCKET", "")
    key = os.environ.get("STATE_KEY", "status/last_state.json")
    topic_arn = os.environ.get("SNS_TOPIC_ARN", "")

    s3_client = boto3.client("s3")
    previous = load_previous_failures(s3_client, bucket, key)

    first_run = previous is None
    changed = (not first_run) and current != previous
    if changed:
        subject, body = build_message(current, previous or [], results)
        publish(boto3.client("sns"), topic_arn, subject, body)
        LOGGER.info("State changed %s -> %s; notification sent", previous, current)
    elif first_run:
        LOGGER.info("No previous state; recording baseline without notifying")
    else:
        LOGGER.info("No change since last run; staying quiet")

    save_state(s3_client, bucket, key, current, results)

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(
            {
                "invoked_by": invoked_by,
                "checked": len(results),
                "failing": current,
                "previous": previous,
                "notified": changed,
            }
        ),
    }
