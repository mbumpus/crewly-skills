#!/usr/bin/env bash
# crewly-connector: Authentication script
# Handles OTP request and verification flow
#
# Usage:
#   ./auth.sh request <email>           # Request OTP
#   ./auth.sh verify <email> <otp>      # Verify OTP, outputs access_token
#
# Environment:
#   CREWLY_API_URL  - API base URL (default: https://api.crewly.codes)
#   CREWLY_API_KEY  - Publishable API key
#
# Exit codes:
#   0 - Success
#   1 - Invalid arguments
#   2 - API error (network, server)
#   3 - Auth failure (invalid email, wrong OTP, expired)

set -euo pipefail

CREWLY_API_URL="${CREWLY_API_URL:-https://api.crewly.codes}"
CREWLY_API_KEY="${CREWLY_API_KEY:-sb_publishable_ulOfuc_3ZOZSpsxiZxpg9A_dDUbX8ep}"

usage() {
  echo "Usage: $0 <command> [args]"
  echo "Commands:"
  echo "  request <email>         Request OTP sent to email"
  echo "  verify <email> <otp>    Verify OTP, output access_token JSON"
  exit 1
}

request_otp() {
  local email="$1"
  
  response=$(curl -s -w "\n%{http_code}" -X POST "${CREWLY_API_URL}/auth/v1/otp" \
    -H "apikey: ${CREWLY_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"email\": \"${email}\", \"create_user\": false}")
  
  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')
  
  case "$http_code" in
    200|201)
      echo '{"status": "sent", "message": "OTP sent to '"${email}"'"}'
      exit 0
      ;;
    400)
      echo '{"status": "error", "code": "invalid_email", "message": "Email not registered with Crewly Codes"}' >&2
      exit 3
      ;;
    429)
      echo '{"status": "error", "code": "rate_limited", "message": "Too many requests. Wait before retrying."}' >&2
      exit 3
      ;;
    *)
      echo "{\"status\": \"error\", \"code\": \"api_error\", \"http_code\": ${http_code}, \"body\": ${body:-null}}" >&2
      exit 2
      ;;
  esac
}

verify_otp() {
  local email="$1"
  local otp="$2"
  
  response=$(curl -s -w "\n%{http_code}" -X POST "${CREWLY_API_URL}/auth/v1/verify" \
    -H "apikey: ${CREWLY_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"email\": \"${email}\", \"token\": \"${otp}\", \"type\": \"email\"}")
  
  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')
  
  case "$http_code" in
    200)
      # Extract access_token from response
      echo "$body"
      exit 0
      ;;
    400|401)
      # Check if it's expired or invalid
      if echo "$body" | grep -q "expired"; then
        echo '{"status": "error", "code": "otp_expired", "message": "OTP expired. Request a new code."}' >&2
      else
        echo '{"status": "error", "code": "otp_invalid", "message": "Invalid OTP. Check the code and try again."}' >&2
      fi
      exit 3
      ;;
    *)
      echo "{\"status\": \"error\", \"code\": \"api_error\", \"http_code\": ${http_code}}" >&2
      exit 2
      ;;
  esac
}

# Main
[[ $# -lt 1 ]] && usage

case "$1" in
  request)
    [[ $# -lt 2 ]] && { echo "Error: email required" >&2; usage; }
    request_otp "$2"
    ;;
  verify)
    [[ $# -lt 3 ]] && { echo "Error: email and otp required" >&2; usage; }
    verify_otp "$2" "$3"
    ;;
  *)
    usage
    ;;
esac
