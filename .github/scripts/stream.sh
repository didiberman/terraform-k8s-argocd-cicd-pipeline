#!/bin/bash

LOG_FILE="$1"
CHAT_ID="$2"
MSG_ID="$3"
BOT_TOKEN="$4"
TITLE="$5"

# Validate critical args
if [ -z "$MSG_ID" ] || [ "$MSG_ID" == "null" ]; then
  echo "Error: MSG_ID is empty. Cannot stream logs to Telegram."
  exit 0
fi

echo "Starting streamer for $TITLE..."
echo "Log file: $LOG_FILE"

while [ -f "$LOG_FILE" ]; do
  TAIL=$(tail -n 12 "$LOG_FILE")
  
  if [ -n "$TAIL" ]; then
    # Construct JSON payload
    jq -n \
      --arg chat_id "$CHAT_ID" \
      --arg message_id "$MSG_ID" \
      --arg text "$(echo -e "$TITLE\n\n\`\`\`\n$TAIL\n\`\`\`")" \
      '{chat_id: $chat_id, message_id: ($message_id | tonumber), text: $text, parse_mode: "Markdown"}' > payload.json

    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/editMessageText" \
      -H "Content-Type: application/json" \
      -d @payload.json > /dev/null
  else
    echo "Log file empty or tail failed."
  fi
  
  sleep 7
done
