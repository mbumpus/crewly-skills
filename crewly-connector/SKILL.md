---
name: crewly-connector
description: Connects to Crewly Codes to authenticate, fetch feature specs, and verify Morgan hash for full traceability. Triggers on "connect to crewly", "load spec", "fetch card", "get crewly spec", "login to crewly", "load my spec from crewly", or any mention of a Crewly card/board ID.
---

# Crewly Connector

Authenticates with Crewly Codes via email OTP, fetches feature specifications, and verifies Morgan hash for ThoughtChain traceability.

## Input Contract

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| email | string | yes | User's registered email |
| board_id | string | yes | UUID of the board to access |
| card_id | string | no | Specific card to fetch (optional) |

## Output Contract

```json
{
  "spec": {
    "card_id": "uuid",
    "title": "Feature Title",
    "morgan_hash": "sha256:...",
    "spec_json": {
      "story": { "as_a": "...", "i_want": "...", "so_that": "..." },
      "acceptance_criteria": [...],
      "dependencies": [...],
      "risks": [...],
      "open_questions": [...],
      "stub_suggestions": [...]
    }
  },
  "morgan_verified": true,
  "features": {
    "traceability": true,
    "bugs_yaml": true,
    "trace_jsonl": true,
    "thoughtchain": true
  },
  "access_token": "jwt..."
}
```

## Configuration

Baked-in values (no user configuration needed):

```bash
CREWLY_API_URL="https://api.crewly.codes"
CREWLY_API_KEY="sb_publishable_ulOfuc_3ZOZSpsxiZxpg9A_dDUbX8ep"
```

The API key is publishable (RLS controls access).

## Scripts

Use deterministic scripts for all API operations:

| Script | Purpose |
|--------|---------|
| `scripts/auth.sh request <email>` | Request OTP |
| `scripts/auth.sh verify <email> <otp>` | Verify OTP, get token |
| `scripts/fetch-specs.sh <board_id> <token>` | Fetch locked specs |
| `scripts/verify-hash.sh <card_id> <hash> <token>` | Verify Morgan hash |
| `scripts/update-status.sh <card_id> <agent> <state> [msg] <token> [board_id]` | Update card status (realtime) |
| `scripts/move-card.sh <card_id> <column> <board_id> <token>` | Move card to column (realtime) |

### Realtime Updates

Pass `board_id` to `update-status.sh` and `move-card.sh` to enable realtime updates in the web app:

```bash
# With board_id — triggers instant UI update
./scripts/update-status.sh "$CARD_ID" "DevCrew" "building" "Iteration 1/5" "$TOKEN" "$BOARD_ID"

# Without board_id — updates database only, UI updates on refresh
./scripts/update-status.sh "$CARD_ID" "DevCrew" "building" "Iteration 1/5" "$TOKEN"
```

The `move-card.sh` script always broadcasts (board_id is required).

## Authentication Flow

### Step 1: Collect Info

Ask user for:
1. **Email address** (registered with Crewly Codes)
2. **Board ID** they want to access

### Step 2: Request OTP

```bash
./scripts/auth.sh request "user@example.com"
```

**Success:** `{"status": "sent", "message": "OTP sent to user@example.com"}`

Tell user: "Check your email for a one-time code from Crewly."

### Step 3: Verify OTP

```bash
./scripts/auth.sh verify "user@example.com" "847291"
```

**Success:** Returns JSON with `access_token`

Store token for subsequent requests.

### Step 4: Fetch Locked Specs

```bash
./scripts/fetch-specs.sh "board-uuid" "$ACCESS_TOKEN"
```

**Success:** Returns array of specs with `morgan_hash`

### Step 5: Verify Morgan Hash

```bash
./scripts/verify-hash.sh "card-uuid" "sha256:abc..." "$ACCESS_TOKEN"
```

**Success:** 
```json
{"valid": true, "features": {"traceability": true, "bugs_yaml": true, ...}}
```

### Step 6: Select & Bundle

If multiple specs, show titles and let user choose.

Bundle spec with verification:
```json
{
  "spec": { ... },
  "morgan_verified": true,
  "features": { ... }
}
```

## After Loading Spec

1. **Summarize** the spec:
   - User story (as_a / i_want / so_that)
   - Key acceptance criteria
   - Any flagged open questions

2. **Report verification status:**
   - ✅ "Morgan verified — full traceability enabled"
   - ⚠️ "Unverified spec — running in basic mode"

3. **Hand off — AUTOMATIC:**
   - After spec is loaded and verified, **immediately proceed to crewly-runner skill**
   - Do NOT wait for user confirmation
   - Say: "Spec loaded and verified. Starting implementation..."

## Error Handling

| Error | Script Exit | Response |
|-------|-------------|----------|
| Invalid email | 3 | "That email isn't registered with Crewly." |
| Wrong OTP | 3 | "That code didn't work. Check your email." |
| Expired OTP | 3 | "Code expired. Requesting new one." (auto-retry) |
| Rate limited | 3 | "Too many attempts. Wait 60 seconds." |
| No board access | 3 | "You don't have access to that board." |
| Board not found | 3 | "Board not found." |
| Token expired | 3 | Re-authenticate automatically |
| Hash invalid | 0 | "⚠️ Spec verification failed. Running in basic mode." |
| Network error | 2 | "Connection failed. Check network and retry." |

## Fallback Behavior

- **OTP expired:** Automatically request new OTP
- **Token expired mid-session:** Re-run auth flow
- **Hash verification fails:** Continue with `morgan_verified: false`
- **API timeout:** Retry once, then fail with clear error
- **Empty specs:** "No locked specs found. Lock a card in the web app first."

## Handoff Format

Pass to crewly-runner:

```json
{
  "spec": { ... },
  "morgan_verified": true,
  "features": {
    "traceability": true,
    "bugs_yaml": true,
    "trace_jsonl": true
  },
  "access_token": "..."
}
```

## Manual Fallback

If scripts or API are completely unavailable:

1. **Ask user to paste spec JSON directly:**
   - "API unavailable. Please paste the spec JSON from Crewly Codes web app."
   - Web app: Board → Card → "Copy Spec JSON" button

2. **Accept pasted spec:**
   ```json
   {
     "title": "Feature Name",
     "spec_json": { "story": {...}, "acceptance_criteria": [...] }
   }
   ```

3. **Set verification status:**
   - `morgan_verified: false` (cannot verify without API)
   - Warn: "Running in basic mode without traceability."

4. **Proceed to crewly-runner** with unverified spec.
