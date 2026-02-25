#!/usr/bin/env bash
# crewly-connector: Move card to a column
# Moves card to a column by name — triggers realtime in web app
#
# Usage:
#   ./move-card.sh <card_id> <column_name> <board_id> <access_token>
#
# Arguments:
#   card_id      - UUID of the card
#   column_name  - Target column name (e.g., "In Progress", "Complete")
#   board_id     - UUID of the board (to find columns)
#   access_token - JWT from auth.sh
#
# Column name matching:
#   - Case-insensitive
#   - Partial match (e.g., "progress" matches "In Progress")
#   - Common aliases: "done" → "Complete", "todo" → "Backlog"
#
# Exit codes:
#   0 - Success
#   1 - Invalid arguments
#   2 - API error (network, server)
#   3 - Auth/access error
#   4 - Column not found

set -euo pipefail

CREWLY_API_URL="${CREWLY_API_URL:-https://api.crewly.codes}"
CREWLY_API_KEY="${CREWLY_API_KEY:-sb_publishable_ulOfuc_3ZOZSpsxiZxpg9A_dDUbX8ep}"

usage() {
  echo "Usage: $0 <card_id> <column_name> <board_id> <access_token>"
  echo ""
  echo "Moves card to a column by name."
  echo ""
  echo "Arguments:"
  echo "  card_id      UUID of the card"
  echo "  column_name  Target column (e.g., 'In Progress', 'Complete')"
  echo "  board_id     UUID of the board"
  echo "  access_token JWT from auth.sh"
  exit 1
}

[[ $# -lt 4 ]] && usage

CARD_ID="$1"
COLUMN_NAME="$2"
BOARD_ID="$3"
ACCESS_TOKEN="$4"

# Normalize column name for matching
normalize() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr -d ' '
}

TARGET=$(normalize "$COLUMN_NAME")

# Aliases
case "$TARGET" in
  done|completed|finish|finished) TARGET="complete" ;;
  todo|backlog|new) TARGET="backlog" ;;
  wip|inprogress|working|building) TARGET="inprogress" ;;
esac

# Fetch columns for this board
columns_response=$(curl -s -w "\n%{http_code}" -X GET \
  "${CREWLY_API_URL}/rest/v1/columns?board_id=eq.${BOARD_ID}&select=id,name" \
  -H "apikey: ${CREWLY_API_KEY}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}")

http_code=$(echo "$columns_response" | tail -n1)
columns_body=$(echo "$columns_response" | sed '$d')

if [[ "$http_code" != "200" ]]; then
  echo '{"status": "error", "code": "fetch_failed", "message": "Failed to fetch columns"}' >&2
  exit 2
fi

# Find matching column
COLUMN_ID=""
MATCHED_NAME=""

# Parse columns JSON and find match
while IFS= read -r line; do
  col_id=$(echo "$line" | jq -r '.id')
  col_name=$(echo "$line" | jq -r '.name')
  col_norm=$(normalize "$col_name")
  
  # Exact match or contains
  if [[ "$col_norm" == "$TARGET" ]] || [[ "$col_norm" == *"$TARGET"* ]]; then
    COLUMN_ID="$col_id"
    MATCHED_NAME="$col_name"
    break
  fi
done < <(echo "$columns_body" | jq -c '.[]')

if [[ -z "$COLUMN_ID" ]]; then
  echo "{\"status\": \"error\", \"code\": \"column_not_found\", \"target\": \"$COLUMN_NAME\", \"available\": $columns_body}" >&2
  exit 4
fi

# Move the card
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

# Determine status based on target column
case "$TARGET" in
  complete) CARD_STATUS="completed" ;;
  inprogress) CARD_STATUS="in_progress" ;;
  backlog) CARD_STATUS="pending" ;;
  *) CARD_STATUS="" ;;
esac

# Build payload — include status if we know it
if [[ -n "$CARD_STATUS" ]]; then
  PAYLOAD="{\"column_id\": \"${COLUMN_ID}\", \"status\": \"${CARD_STATUS}\", \"updated_at\": \"${TIMESTAMP}\"}"
else
  PAYLOAD="{\"column_id\": \"${COLUMN_ID}\", \"updated_at\": \"${TIMESTAMP}\"}"
fi

move_response=$(curl -s -w "\n%{http_code}" -X PATCH \
  "${CREWLY_API_URL}/rest/v1/cards?id=eq.${CARD_ID}" \
  -H "apikey: ${CREWLY_API_KEY}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d "$PAYLOAD")

move_http_code=$(echo "$move_response" | tail -n1)

case "$move_http_code" in
  200|204)
    # Broadcast to web app for realtime update
    curl -s -X POST \
      "${CREWLY_API_URL}/realtime/v1/api/broadcast" \
      -H "apikey: ${CREWLY_API_KEY}" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"messages\": [{\"topic\": \"realtime:board-${BOARD_ID}\", \"event\": \"card-moved\", \"payload\": {\"card_id\": \"${CARD_ID}\", \"column\": \"${MATCHED_NAME}\"}}]}" \
      > /dev/null 2>&1 || true
    
    if [[ -n "$CARD_STATUS" ]]; then
      echo "{\"status\": \"moved\", \"card_id\": \"${CARD_ID}\", \"column\": \"${MATCHED_NAME}\", \"column_id\": \"${COLUMN_ID}\", \"card_status\": \"${CARD_STATUS}\"}"
    else
      echo "{\"status\": \"moved\", \"card_id\": \"${CARD_ID}\", \"column\": \"${MATCHED_NAME}\", \"column_id\": \"${COLUMN_ID}\"}"
    fi
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
  *)
    echo "{\"status\": \"error\", \"code\": \"api_error\", \"http_code\": ${move_http_code}}" >&2
    exit 2
    ;;
esac
