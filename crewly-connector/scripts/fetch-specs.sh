#!/usr/bin/env bash
# crewly-connector: Fetch locked specs
# Retrieves all locked feature specs for a board
#
# Usage:
#   ./fetch-specs.sh <board_id> <access_token>
#
# Environment:
#   CREWLY_API_URL  - API base URL (default: https://api.crewly.codes)
#   CREWLY_API_KEY  - Publishable API key
#
# Output (JSON):
#   Array of specs with morgan_hash:
#   [{"card_id": "...", "title": "...", "morgan_hash": "sha256:...", "spec_json": {...}}]
#
# Exit codes:
#   0 - Success
#   1 - Invalid arguments
#   2 - API error (network, server)
#   3 - Auth/access error (no access to board, expired token)

set -euo pipefail

CREWLY_API_URL="${CREWLY_API_URL:-https://api.crewly.codes}"
CREWLY_API_KEY="${CREWLY_API_KEY:-sb_publishable_ulOfuc_3ZOZSpsxiZxpg9A_dDUbX8ep}"

usage() {
  echo "Usage: $0 <board_id> <access_token>"
  echo ""
  echo "Fetches all locked specs for the given board."
  echo "Requires valid access_token from auth.sh verify."
  exit 1
}

[[ $# -lt 2 ]] && usage

BOARD_ID="$1"
ACCESS_TOKEN="$2"

response=$(curl -s -w "\n%{http_code}" -X POST "${CREWLY_API_URL}/rest/v1/rpc/get_locked_specs" \
  -H "apikey: ${CREWLY_API_KEY}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"p_board_id\": \"${BOARD_ID}\"}")

http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

case "$http_code" in
  200)
    # Check if response is empty array
    if [[ "$body" == "[]" ]]; then
      echo '{"status": "empty", "message": "No locked specs found for this board", "specs": []}' >&2
      exit 0
    fi
    echo "$body"
    exit 0
    ;;
  401)
    echo '{"status": "error", "code": "token_expired", "message": "Access token expired. Re-authenticate."}' >&2
    exit 3
    ;;
  403)
    echo '{"status": "error", "code": "no_access", "message": "You do not have access to this board."}' >&2
    exit 3
    ;;
  404)
    echo '{"status": "error", "code": "not_found", "message": "Board not found."}' >&2
    exit 3
    ;;
  *)
    echo "{\"status\": \"error\", \"code\": \"api_error\", \"http_code\": ${http_code}, \"body\": ${body:-null}}" >&2
    exit 2
    ;;
esac
