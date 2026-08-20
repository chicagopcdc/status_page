# Manual Steps
1. build the lambda function
2. terraform init
3. After `terraform apply`, go to AWS ACM console.
4. get the created certificate DNS validation TXT record rfom the output and add to the DNS provider
5. Wait until ACM cert status shows `ISSUED`.
6. switch `manual_step` to true
7. RE run the apply
8. Add a CNAME in GoDaddy:
    - Name: `your subdomain`
    - Value: your CloudFront domain (e.g., `d1234abcd.cloudfront.net`)


# Scheduled status check

The Lambda that backs the status page also runs on an EventBridge schedule
(`rate(15 minutes)` by default) and emails an SNS topic when a service goes
down or recovers.

## How it decides to alert

Every run checks each endpoint in `status_page_app/config/config.json` — the
same file the React app uses — and writes the result to a private state bucket.
An email is sent **only when the set of failing endpoints changes**:

- a service goes down → alert listing what is newly down
- another service also goes down → alert (the set changed)
- the same services stay down → **no email**, so a long outage does not repeat
  every 15 minutes
- everything recovers → one "RESOLVED" all-clear
- the very first run after deploy records a baseline and never alerts, so
  deploying does not immediately page about a pre-existing outage

`maintenance` (an endpoint returning `{"status": "maintenance"}`) is reported in
the email body but never counts as an outage.

Invocations that are *not* from EventBridge (API Gateway, manual test) run the
same checks and return them as JSON without alerting or writing state, so
probing by hand cannot suppress or trigger a real alert.

## One config, two consumers

The endpoint list lives only in `status_page_app/config/config.json`. The React
app imports it at build time; `status_lambda/build_lambda.sh` copies it into the
Lambda package. Neither copy is edited by hand, so the page and the alerts
cannot drift apart. `build_lambda.sh` fails loudly if that file is missing.

## After the first apply: confirm the subscription

SNS email subscriptions start as **pending**. AWS sends a confirmation link to
every address in `notification_emails`, and **no alerts are delivered until
someone clicks it**. For `pcdc_help@lists.uchicago.edu` this means a list
member has to confirm. Verify in the SNS console that the subscription shows
`Confirmed`.

## Relevant variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `notification_emails` | `["pcdc_help@lists.uchicago.edu"]` | Alert recipients. |
| `status_check_schedule` | `rate(15 minutes)` | How often the check runs. |
| `status_state_key` | `status/last_state.json` | State object key. |
| `status_request_timeout` | `3` | Per-endpoint timeout, matching the React app. |

## Run the Lambda tests

```shell
python -m pytest terraform/status_lambda/tests -q
```
