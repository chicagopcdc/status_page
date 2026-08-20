import io
import json

import pytest

import status_lambda as sl


CONFIG = {
    "hostnames": {
        "https://portal.example.org": ["user/_status", "/"],
        "https://gearbox.example.org": ["/_status"],
    },
    "urlToTitleDataMap": {"user/_status": "fence-service", "/": "portal-service"},
}


class FakeResponse:
    def __init__(self, status_code=200, headers=None, body=None):
        self.status_code = status_code
        self.headers = headers or {}
        self._body = body

    def json(self):
        if self._body is None:
            raise ValueError("no json")
        return self._body


class FakeSession:
    """Maps a URL to a FakeResponse or an exception to raise."""

    def __init__(self, responses):
        self.responses = responses
        self.requested = []

    def get(self, url, timeout=None):
        self.requested.append(url)
        result = self.responses.get(url, FakeResponse(200))
        if isinstance(result, Exception):
            raise result
        return result

    def close(self):
        pass


class FakeS3:
    def __init__(self, stored=None, fail_get=False):
        self.stored = stored
        self.fail_get = fail_get
        self.puts = []

    def get_object(self, Bucket, Key):
        if self.fail_get or self.stored is None:
            raise RuntimeError("NoSuchKey")
        return {"Body": io.BytesIO(json.dumps(self.stored).encode("utf-8"))}

    def put_object(self, **kwargs):
        self.puts.append(kwargs)


class FakeSNS:
    def __init__(self):
        self.published = []

    def publish(self, TopicArn, Subject, Message):
        self.published.append(
            {"TopicArn": TopicArn, "Subject": Subject, "Message": Message}
        )


# -- config / targets -------------------------------------------------------
def test_build_targets_joins_urls_like_the_react_app():
    targets = sl.build_targets(CONFIG)
    urls = [t["url"] for t in targets]
    assert urls == [
        "https://portal.example.org/user/_status",
        "https://portal.example.org/",
        "https://gearbox.example.org/_status",
    ]


def test_build_targets_uses_titles_and_falls_back_to_the_path():
    targets = {t["url"]: t["service"] for t in sl.build_targets(CONFIG)}
    assert targets["https://portal.example.org/user/_status"] == "fence-service"
    # Not present in urlToTitleDataMap -> falls back to the raw endpoint.
    assert targets["https://gearbox.example.org/_status"] == "/_status"


def test_load_config_rejects_a_config_without_hostnames(tmp_path):
    path = tmp_path / "config.json"
    path.write_text(json.dumps({"hostnames": {}}))
    with pytest.raises(sl.ConfigError):
        sl.load_config(str(path))


# -- individual checks ------------------------------------------------------
def test_non_200_and_transport_errors_are_failures():
    targets = sl.build_targets(CONFIG)
    session = FakeSession(
        {
            "https://portal.example.org/user/_status": FakeResponse(503),
            "https://portal.example.org/": TimeoutError("timed out"),
        }
    )
    results = {r["url"]: r for r in sl.run_checks(targets, session)}
    assert results["https://portal.example.org/user/_status"]["status"] == sl.FAIL
    assert "HTTP 503" in results["https://portal.example.org/user/_status"]["detail"]
    assert results["https://portal.example.org/"]["status"] == sl.FAIL
    assert results["https://gearbox.example.org/_status"]["status"] == sl.SUCCESS


def test_maintenance_body_is_reported_as_maintenance_not_failure():
    targets = sl.build_targets(CONFIG)
    session = FakeSession(
        {
            "https://portal.example.org/user/_status": FakeResponse(
                200,
                {"content-type": "application/json"},
                {"status": "maintenance"},
            )
        }
    )
    results = sl.run_checks(targets, session)
    statuses = {r["url"]: r["status"] for r in results}
    assert statuses["https://portal.example.org/user/_status"] == sl.MAINTENANCE
    # Maintenance is intentional, so it must not count as down.
    assert sl.failing_urls(results) == []


def test_malformed_json_body_falls_back_to_the_status_code():
    targets = sl.build_targets(CONFIG)
    session = FakeSession(
        {
            "https://portal.example.org/": FakeResponse(
                200, {"content-type": "application/json"}, None
            )
        }
    )
    results = {r["url"]: r for r in sl.run_checks(targets, session)}
    assert results["https://portal.example.org/"]["status"] == sl.SUCCESS


# -- state-change alerting --------------------------------------------------
def _run_cron(monkeypatch, session, s3, sns, tmp_path):
    config_path = tmp_path / "config.json"
    config_path.write_text(json.dumps(CONFIG))
    monkeypatch.setenv("CONFIG_PATH", str(config_path))
    monkeypatch.setenv("STATE_BUCKET", "state-bucket")
    monkeypatch.setenv("STATE_KEY", "status/last_state.json")
    monkeypatch.setenv("SNS_TOPIC_ARN", "arn:aws:sns:us-east-2:1:topic")
    monkeypatch.setattr(sl.requests, "Session", lambda: session)
    monkeypatch.setattr(
        sl.boto3, "client", lambda name: s3 if name == "s3" else sns
    )
    return sl.handler({"source": "aws.events"}, None)


def test_first_run_records_baseline_without_notifying(monkeypatch, tmp_path):
    session = FakeSession({"https://portal.example.org/": FakeResponse(500)})
    s3, sns = FakeS3(stored=None), FakeSNS()
    response = _run_cron(monkeypatch, session, s3, sns, tmp_path)
    body = json.loads(response["body"])
    # Something is down, but with no prior state we must not alert - otherwise
    # every deploy would page about pre-existing outages.
    assert body["notified"] is False
    assert body["failing"] == ["https://portal.example.org/"]
    assert sns.published == []
    assert len(s3.puts) == 1


def test_unchanged_failures_do_not_re_notify(monkeypatch, tmp_path):
    session = FakeSession({"https://portal.example.org/": FakeResponse(500)})
    s3 = FakeS3(stored={"failing": ["https://portal.example.org/"]})
    sns = FakeSNS()
    response = _run_cron(monkeypatch, session, s3, sns, tmp_path)
    assert json.loads(response["body"])["notified"] is False
    assert sns.published == []


def test_new_failure_notifies(monkeypatch, tmp_path):
    session = FakeSession({"https://portal.example.org/": FakeResponse(500)})
    s3, sns = FakeS3(stored={"failing": []}), FakeSNS()
    response = _run_cron(monkeypatch, session, s3, sns, tmp_path)
    assert json.loads(response["body"])["notified"] is True
    assert len(sns.published) == 1
    assert "DOWN" in sns.published[0]["Subject"]
    assert "Newly down:" in sns.published[0]["Message"]
    assert "portal-service" in sns.published[0]["Message"]


def test_recovery_sends_an_all_clear(monkeypatch, tmp_path):
    session = FakeSession({})  # everything healthy now
    s3 = FakeS3(stored={"failing": ["https://portal.example.org/"]})
    sns = FakeSNS()
    response = _run_cron(monkeypatch, session, s3, sns, tmp_path)
    assert json.loads(response["body"])["notified"] is True
    assert "RESOLVED" in sns.published[0]["Subject"]
    assert "Recovered:" in sns.published[0]["Message"]


def test_additional_failure_notifies_and_lists_still_down(monkeypatch, tmp_path):
    session = FakeSession(
        {
            "https://portal.example.org/": FakeResponse(500),
            "https://gearbox.example.org/_status": FakeResponse(500),
        }
    )
    s3 = FakeS3(stored={"failing": ["https://portal.example.org/"]})
    sns = FakeSNS()
    _run_cron(monkeypatch, session, s3, sns, tmp_path)
    message = sns.published[0]["Message"]
    assert "Newly down:" in message
    assert "https://gearbox.example.org/_status" in message
    assert "Still down:" in message


def test_subject_is_truncated_to_the_sns_limit():
    sns = FakeSNS()
    sl.publish(sns, "arn:topic", "x" * 250, "body")
    assert len(sns.published[0]["Subject"]) == 100


# -- non-cron invocations ---------------------------------------------------
def test_api_gateway_invocation_never_alerts_or_writes_state(monkeypatch, tmp_path):
    config_path = tmp_path / "config.json"
    config_path.write_text(json.dumps(CONFIG))
    monkeypatch.setenv("CONFIG_PATH", str(config_path))
    monkeypatch.setenv("STATE_BUCKET", "state-bucket")
    monkeypatch.setenv("SNS_TOPIC_ARN", "arn:aws:sns:us-east-2:1:topic")
    session = FakeSession({"https://portal.example.org/": FakeResponse(500)})
    s3, sns = FakeS3(stored={"failing": []}), FakeSNS()
    monkeypatch.setattr(sl.requests, "Session", lambda: session)
    monkeypatch.setattr(sl.boto3, "client", lambda name: s3 if name == "s3" else sns)

    response = sl.handler({"httpMethod": "GET"}, None)

    body = json.loads(response["body"])
    assert body["invoked_by"] == "apigateway"
    assert body["failing"] == ["https://portal.example.org/"]
    # A manual probe must not suppress or trigger a real alert.
    assert sns.published == []
    assert s3.puts == []
