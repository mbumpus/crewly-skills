---
name: crewly-connector
description: Connects to Crewly Codes to authenticate and fetch feature specs. Use when user says "connect to crewly", "load spec", "fetch card", "get crewly spec", "login to crewly", or mentions a Crewly card ID.
---

# Crewly Connector

Authenticates with Crewly Codes via email OTP and fetches feature specifications for implementation.

## Configuration

The following values are needed (user should have these from Crewly setup):

```
CREWLY_SUPABASE_URL=https://xbwbyfvxtfwpkrxjnpyq.supabase.co
CREWLY_ANON_KEY=[from crewly settings or .env]
```

## Authentication Flow

### Step 1: Initiate Connection

When user wants to connect to Crewly:

1. Ask for their **email address** (the one registered with Crewly Codes)
2. Ask for the **Board ID** they want to access

### Step 2: Request OTP

Make a POST request to Supabase to trigger OTP:

```bash
curl -X POST "${CREWLY_SUPABASE_URL}/auth/v1/otp" \
  -H "apikey: ${CREWLY_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"email": "USER_EMAIL", "create_user": false}'
```

Response on success:
```json
{"message_id": "..."}
```

Tell the user: "Check your email for a one-time code from Crewly."

### Step 3: Verify OTP

When user provides the OTP code:

```bash
curl -X POST "${CREWLY_SUPABASE_URL}/auth/v1/verify" \
  -H "apikey: ${CREWLY_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"email": "USER_EMAIL", "token": "CODE_FROM_EMAIL", "type": "email"}'
```

Response contains access token:
```json
{
  "access_token": "eyJ...",
  "token_type": "bearer",
  "expires_in": 3600,
  "user": {...}
}
```

Store `access_token` for subsequent requests.

### Step 4: Fetch Locked Specs

Call the Supabase RPC function to get specs for the board:

```bash
curl -X POST "${CREWLY_SUPABASE_URL}/rest/v1/rpc/get_locked_specs" \
  -H "apikey: ${CREWLY_ANON_KEY}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"p_board_id": "BOARD_ID"}'
```

Response is an array of locked specs for the board:
```json
[
  {
    "card_id": "uuid",
    "title": "Feature Title",
    "column_id": "uuid",
    "spec_json": {
      "story": {
        "title": "...",
        "as_a": "...",
        "i_want": "...",
        "so_that": "..."
      },
      "acceptance_criteria": ["Given X, when Y, then Z", ...],
      "dependencies": ["..."],
      "risks": ["..."],
      "open_questions": [
        {
          "id": "oq_001",
          "question": "...",
          "options": [{"label": "...", "info": "..."}],
          "selected": null,
          "flagged": false
        }
      ],
      "docs_md": "# Documentation...",
      "stub_suggestions": [
        {
          "path": "src/feature/file.ts",
          "purpose": "what this file does",
          "snippet": "// starting code"
        }
      ],
      "metrics": ["Success metric 1", ...]
    }
  }
]
```

### Step 5: Select a Spec

If multiple specs are returned, ask the user which one to load by showing titles.

Once selected, the spec is ready for DevCrew.

## After Loading Spec

Once the spec is loaded into context:

1. **Summarize** the spec for the user:
   - User story (as_a / i_want / so_that)
   - Key acceptance criteria
   - Any flagged open questions

2. **Check for blockers:**
   - Are there unresolved open questions marked as `flagged: true`?
   - Are dependencies satisfied?

3. **Hand off to DevCrew:**
   - If the spec is ready, tell the user: "Spec loaded. Use the DevCrew skill to begin implementation."
   - Include the spec in context for DevCrew to consume.

## Error Handling

| Error | Response |
|-------|----------|
| Invalid email | "That email isn't registered with Crewly. Check the address or sign up at crewlycodes.com" |
| Wrong OTP | "That code didn't work. Check your email for the latest code." |
| Expired OTP | "That code has expired. I'll request a new one." (auto-retry) |
| Card not found | "I couldn't find that card. Double-check the Card ID." |
| No access | "You don't have access to that board. Ask the owner to invite you." |

## Example Conversation

```
User: Connect to Crewly and load my auth feature card