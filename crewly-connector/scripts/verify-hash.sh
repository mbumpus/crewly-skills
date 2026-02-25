#!/usr/bin/env bash
# crewly-connector: Verify Morgan hash
# Validates spec hash and returns feature flags for traceability
#
# Usage:
#   ./verify-hash.sh <card_id> <morgan_hash> <access_token>
#
# Environment:
#   CREWLY_API_URL  - API base URL (default: https://api.crewly.codes)
#   CREWLY_API_KEY  - Publishable API key
#
# Output (JSON):
#   {"valid": true, "features": {"traceability": true, "bugs_yaml": true, ...}}
#   or
#   {"valid": false, "features": {}}
#
# Exit codes:
#   0 - Success (valid or invalid hash — check JSON)
#   1 - Invalid arguments
#   2 - API error (network, server)
#   3 - Auth error (expired token)

set -euo pipefail

CREWLY_API_URL="${CREWLY_API_URL:-https://api.crewly.codes}"
CREWLY_API_KEY="${CREWLY_API_KEY:-sb_publishable_ulOfuc_3ZOZSpsxiZxpg9A_dDUbX8ep}"

usage() {
  echo "Usage: $0 <card_id> <morgan_hash> <access_token>"
  echo ""
  echo "Verifies the Morgan hash for a spec card."
  echo "Returns feature flags when valid."
  exit 1
}

[[ $# -lt 3 ]] && usage

CARD_ID="$1"
MORGAN_HASH="$2"
ACCESS_TOKEN="$3"

response=$(curl -s -w "\n%{http_code}" -X POST "${CREWLY_API_URL}/rest/v1/rpc/verify_morgan_hash" \
  -H "apikey: ${CREWLY_API_KEY}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"p_card_id\": \"${CARD_ID}\", \"p_hash\": \"${MORGAN_HASH}\"}")

http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

case "$http_code" in
  200)
    echo "$body"
    exit 0
    ;;
  401)
    echo '{"status": "error", "code": "token_expired", "message": "Access token expired. Re-authenticate."}' >&2
    exit 3
    ;;
  *)
    echo "{\"status\": \"error\", \"code\": \"api_error\", \"http_code\": ${http_code}, \"body\": ${body:-null}}" >&2
    exit 2
    ;;
esac
