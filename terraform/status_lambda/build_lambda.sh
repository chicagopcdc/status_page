#!/bin/bash

cd ./src
python -m pip install --upgrade pip
pip install poetry-plugin-export
poetry export -f requirements.txt --output requirements.txt
mkdir -p ../dist/status_lambda
pip install -r requirements.txt -t ../dist/status_lambda/ --upgrade

cp ./*.py ../dist/status_lambda