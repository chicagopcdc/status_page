#!/bin/bash
set -euo pipefail

# Resolve paths against this script's location so the build works from any cwd.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# The React app owns config.json; the Lambda checks the same endpoints, so the
# file is copied into the deployment package at build time rather than being
# duplicated. One file in git means the page and the alerts cannot drift apart.
CONFIG_SOURCE="$REPO_ROOT/status_page_app/config/config.json"

cd "$SCRIPT_DIR/src"
python -m pip install --upgrade pip
pip install poetry-plugin-export
poetry export -f requirements.txt --output requirements.txt
mkdir -p ../dist/status_lambda
pip install -r requirements.txt -t ../dist/status_lambda/ --upgrade

cp ./*.py ../dist/status_lambda

if [ ! -f "$CONFIG_SOURCE" ]; then
  echo "ERROR: shared config not found at $CONFIG_SOURCE" >&2
  exit 1
fi
cp "$CONFIG_SOURCE" ../dist/status_lambda/config.json
echo "Bundled config.json from $CONFIG_SOURCE"
