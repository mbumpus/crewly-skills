#!/usr/bin/env bash
# crewly-connector: Update card agent status
# Updates the agent_status field on a card — triggers realtime in web app
#
# Usage:
#   ./update-status.sh <card_id> <agent> <state> [message] <access_token> [board_id]
#
# Arguments:
#   card_id      - UUID of the card
#   agent        - DevCrew | QA | crewly-runner
#   state        - building | reviewing | implementing | fixing | passed | failed
#   message      - Optional status message (e.g., "Iteration 2/5")
#   access_token - JWT from auth.sh
#   board_id     - Optional board UUID for realtime broadcast
#
# Environment:
#   CREWLY_API_URL  - API base URL (default: https://api.crewly.codes)
#   CREWLY_API_KEY  - Publishable API key
#
# Exit codes:
#   0 - Success
#   1 - Invalid arguments
#   2 - API error (network, server)
#   3 - Auth/access error

set -euo pipefail

CREWLY_API_URL="${CREWLY_API_URL:-https://api.crewly.codes}"
CREWLY_API_KEY="${CREWLY_API_KEY:-sb_publishable_ulOfuc_3ZOZSpsxiZxpg9A_dDUbX8ep}"

usage() {
  echo "Usage: $0 <card_id> <agent> <state> [message] <access_token> [board_id]"
  echo ""
  echo "Updates card agent_status for realtime display in web app."
  echo ""
  echo "Arguments:"
  echo "  card_id      UUID of the card"
  echo "  agent        DevCrew | QA | crewly-runner"
  echo "  state        building | reviewing | implementing | fixing | passed | failed"
  echo "  message      Optional status message"
  echo "  access_token JWT from auth.sh"
  echo "  board_id     Optional board UUID for realtime broadcast"
  exit 1
}

# Parse arguments
[[ $# -lt 4 ]] && usage

CARD_ID="$1"
AGENT="$2"
STATE="$3"
BOARD_ID=""

# Check if 4th arg is message or token (tokens are longer, 100+ chars)
if [[ $# -eq 4 ]]; then
  MESSAGE=""
  ACCESS_TOKEN="$4"
elif [[ $# -eq 5 ]]; then
  # Could be: message + token, or token + board_id
  if [[ ${#4} -gt 50 ]]; then
    # 4th arg is token
    MESSAGE=""
    ACCESS_TOKEN="$4"
    BOARD_ID="$5"
  else
    # 4th arg is message
    MESSAGE="$4"
    ACCESS_TOKEN="$5"
  fi
elif [[ $# -ge 6 ]]; then
  MESSAGE="$4"
  ACCESS_TOKEN="$5"
  BOARD_ID="$6"
else
  usage
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

# Build agent_status JSON
if [[ -n "$MESSAGE" ]]; then
  AGENT_STATUS=$(cat <<EOF
{
  "agent": "$AGENT",
  "state": "$STATE",
  "message": "$MESSAGE",
  "ts": "$TIMESTAMP"
}
EOF
)
else
  AGENT_STATUS=$(cat <<EOF
{
  "agent": "$AGENT",
  "state": "$STATE",
  "ts": "$TIMESTAMP"
}
EOF
)
fi

# Update card via Supabase REST API
response=$(curl -s -w "\n%{http_code}" -X PATCH \
  "${CREWLY_API_URL}/rest/v1/cards?id=eq.${CARD_ID}" \
  -H "apikey: ${CREWLY_API_KEY}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d "{\"agent_status\": ${AGENT_STATUS}, \"updated_at\": \"${TIMESTAMP}\"}")

http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

case "$http_code" in
  200|204)
    # Broadcast to web app for realtime update (if board_id provided)
    if [[ -n "$BOARD_ID" ]]; then
      curl -s -X POST \
        "${CREWLY_API_URL}/realtime/v1/api/broadcast" \
        -H "apikey: ${CREWLY_API_KEY}" \
        -H "Authorization: Bearer ${ACCESS_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"messages\": [{\"topic\": \"realtime:board-${BOARD_ID}\", \"event\": \"status-updated\", \"payload\": {\"card_id\": \"${CARD_ID}\", \"agent\": \"${AGENT}\", \"state\": \"${STATE}\"}}]}" \
        > /dev/null 2>&1 || true
    fi
    echo "{\"status\": \"updated\", \"card_id\": \"${CARD_ID}\", \"agent\": \"${AGENT}\", \"state\": \"${STATE}\"}"
    exit 0
    ;;
  401)
    echo '{"status": "error", "code": "token_expired", "message": "Access token expired."}' >&2
    exit 3
    ;;
  403)
    echo '{"status": "error", "code": "no_access", "message": "No access to this card."}' >&2
    exit 3
    ;;
  404)
    echo '{"status": "error", "code": "not_found", "message": "Card not found."}' >&2
    exit 3
    ;;
  *)
    echo "{\"status\": \"error\", \"code\": \"api_error\", \"http_code\": ${http_code}, \"body\": ${body:-null}}" >&2
    exit 2
    ;;
esac
