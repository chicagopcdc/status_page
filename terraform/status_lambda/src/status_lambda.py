import os

def handler(event, context):
    aws_region = os.environ.get('VAR_1', 'unknown')

    if "httpMethod" in event:
        invoked_by = "apigateway"
    elif "source" in event and event["source"] == "aws.events":
        invoked_by = "eventbridge"
    else:
        invoked_by = "unknown"

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": f"VAR_1: {aws_region}, Called by: {invoked_by}"
    }