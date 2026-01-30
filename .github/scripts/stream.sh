#!/bin/bash

LOG_FILE="$1"
CHAT_ID="$2"
MSG_ID="$3"
BOT_TOKEN="$4"
TITLE="$5"

echo "Starting streamer for $TITLE..."
echo "Log file: $LOG_FILE"

while [ -f "$LOG_FILE" ]; do
  # Get last 15 lines safely
  TAIL=$(tail -n 12 "$LOG_FILE")
  
  if [ -n "$TAIL" ]; then
    # Escape strictly for JSON string
    # We use jq to handle the payload construction safely
    jq -n \
      --arg chat_id "$CHAT_ID" \
      --arg message_id "$MSG_ID" \
      --arg text "$(echo -e "$TITLE\n\n\`\`\`\n$TAIL\n\`\`\`")" \
      '{chat_id: $chat_id, message_id: $message_id, text: $text, parse_mode: "Markdown"}' > payload.json

    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/editMessageText" \
      -H "Content-Type: application/json" \
      -d @payload.json > /dev/null
  else
    echo "Log file empty or tail failed."
  fi
  
  sleep 7
done
