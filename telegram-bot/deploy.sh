#!/usr/bin/env bash
set -euo pipefail

FUNCTION_NAME="k8s-telegram-bot"
REGION="eu-central-1"

cd "$(dirname "$0")"

echo "Installing dependencies..."
npm install --omit=dev

echo "Packaging Lambda function..."
rm -f function.zip
zip -r function.zip handler.js lib/ node_modules/ package.json

echo "Uploading to Lambda..."
aws lambda update-function-code \
  --function-name "$FUNCTION_NAME" \
  --zip-file fileb://function.zip \
  --region "$REGION"

echo "Deploy complete."
