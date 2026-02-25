# Golden Flows — Regression Test Prompts

Test these prompts against any MCP-compatible coding agent. Each should trigger the expected skill and produce consistent behavior.

---

## crewly-connector

### Trigger Phrases (should activate skill)

| Prompt | Expected Behavior |
|--------|-------------------|
| "Connect to Crewly" | Asks for email, initiates OTP flow |
| "Load my spec from Crewly Codes" | Asks for email + board ID |
| "Login to crewly" | Initiates auth flow |
| "Fetch card abc-123 from crewly" | Asks for email, then fetches specific card |
| "Get my crewly spec" | Asks for email + board ID |
| "I have a spec in Crewly, let's load it" | Initiates connection flow |

### Non-Trigger Phrases (should NOT activate)

| Prompt | Why Not |
|--------|---------|
| "Create a todo app" | No crewly mention |
| "What's my API key?" | Not a connection request |
| "Help me with React" | Generic coding question |

### Golden Flow: Full Authentication

```
User: Connect to Crewly and load my PDF merger spec

Agent: What email is registered with Crewly Codes?

User: mike@example.com

Agent: [Runs scripts/auth.sh request mike@example.com]
       Check your email for a one-time code.

User: 847291

Agent: [Runs scripts/auth.sh verify mike@example.com 847291]
       [Runs scripts/fetch-specs.sh <board_id> <token>]
       [Runs scripts/verify-hash.sh <card_id> <hash> <token>]
       
       ✅ Authenticated
       ✅ Morgan verified — full traceability enabled
       
       Loaded: PDF Merger (8 pts)
       • Drag & drop upload
       • Merge multiple PDFs  
       • Download merged file
       
       Starting implementation...
       [Hands off to crewly-runner]
```

### Expected Output Contract

```json
{
  "spec": {
    "card_id": "uuid",
    "title": "Feature Title",
    "spec_json": {
      "story": { "as_a": "...", "i_want": "...", "so_that": "..." },
      "acceptance_criteria": [...],
      "dependencies": [...],
      "risks": [...]
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

---

## crewly-runner

### Trigger Phrases (should activate skill)

| Prompt | Expected Behavior |
|--------|-------------------|
| "Run the crew" | Starts DevCrew→QA loop |
| "Implement this spec" | Begins implementation cycle |
| "Execute the spec" | Starts runner |
| "Start implementation" | Begins DevCrew phase |
| [After crewly-connector loads spec] | Auto-triggers |

### Non-Trigger Phrases

| Prompt | Why Not |
|--------|---------|
| "What does this code do?" | Analysis, not implementation |
| "Fix this bug" | Direct fix, not spec-driven |
| "Review my code" | QA only, not full runner |

### Golden Flow: Implementation Cycle

```
[Spec loaded from crewly-connector]

Agent: Starting implementation...
       
       === Iteration 1/5 ===
       
       [DevCrew Phase]
       Implementing spec: PDF Merger
       Creating files...
       [Writes trace entry]
       
       Files created:
       • src/App.js (68 lines)
       • src/utils/pdfMerger.js (43 lines)
       • src/components/FileUpload.js (52 lines)
       • src/components/FileList.js (61 lines)
       
       [QA Phase]
       Validating against 7 acceptance criteria...
       [Writes trace entry, bugs.yaml]
       
       QA Result: REJECTED
       Bugs found:
       • BUG-001: No actual thumbnails (AC2)
       • BUG-002: Merge button hidden (AC3)
       
       === Iteration 2/5 ===
       
       [DevCrew Phase - Fix]
       Fixing BUG-001, BUG-002...
       [Writes trace entry]
       
       [QA Phase]
       Re-validating...
       [Writes trace entry]
       
       QA Result: APPROVED ✅
       
       ---
       **Implementation Complete**
       Iterations: 2 of 5
       Final Verdict: APPROVED
       Files: 4
       Lines: 224
       Traceability: Enabled
```

### Expected Output Contract

```json
{
  "spec_title": "PDF Merger",
  "iterations": 2,
  "max_iterations": 5,
  "final_verdict": "APPROVED",
  "files_created": ["src/App.js", "..."],
  "total_lines": 224,
  "bugs_found": 2,
  "bugs_fixed": 2,
  "traceability_enabled": true,
  "artifacts": {
    "trace": "crewly/trace.jsonl",
    "bugs": "crewly/bugs.yaml"
  }
}
```

---

## devcrew

### Trigger Phrases (should activate skill)

| Prompt | Expected Behavior |
|--------|-------------------|
| "Implement this" | Writes code for spec/requirements |
| "Build the feature" | Implementation mode |
| "Code this spec" | Implementation mode |
| "Fix the bugs from QA" | Fix mode (iteration > 1) |
| [Handed off from crewly-runner] | Auto-activated |

### Expected Output Contract

```json
{
  "action": "implement | fix",
  "iteration": 1,
  "confidence_score": "88%",
  "confidence_signal": "🟢",
  "files_changed": ["src/App.js", "..."],
  "files_hash": "sha256:...",
  "bugs_fixed": [],
  "reasoning_steps": ["..."]
}
```

---

## qa

### Trigger Phrases (should activate skill)

| Prompt | Expected Behavior |
|--------|-------------------|
| "Validate this code" | QA review against spec |
| "QA the implementation" | Validation mode |
| "Check acceptance criteria" | AC-focused review |
| "Review against the spec" | Validation mode |
| [Handed off from crewly-runner] | Auto-activated |

### Expected Output Contract

```json
{
  "verdict": "APPROVED | REJECTED",
  "iteration": 1,
  "confidence_score": "95%",
  "ac_results": {
    "AC1": "PASS",
    "AC2": "FAIL",
    "AC3": "PASS"
  },
  "bugs_found": ["BUG-001"],
  "files_hash": "sha256:...",
  "reasoning_steps": ["..."]
}
```

---

## Error Scenarios

Test these to verify fallback behavior. Each scenario includes the test command and expected output.

### Auth Failures

#### Invalid Email (Exit 3)
```bash
./scripts/auth.sh request "nonexistent@example.com"
# stderr: {"status": "error", "code": "invalid_email", "message": "Email not registered with Crewly Codes"}
# exit: 3
```
**Agent says:** "That email isn't registered with Crewly."

#### Wrong OTP (Exit 3)
```bash
./scripts/auth.sh verify "demo@crewly.codes" "000000"
# stderr: {"status": "error", "code": "otp_invalid", "message": "Invalid OTP. Check the code and try again."}
# exit: 3
```
**Agent says:** "That code didn't work. Check your email."

#### Expired OTP (Exit 3)
```bash
./scripts/auth.sh verify "demo@crewly.codes" "123456"  # after 10 min
# stderr: {"status": "error", "code": "otp_expired", "message": "OTP expired. Request a new code."}
# exit: 3
```
**Agent behavior:** Auto-request new OTP, tell user to check email again.

#### Rate Limited (Exit 3)
```bash
./scripts/auth.sh request "demo@crewly.codes"  # 5th attempt in 1 min
# stderr: {"status": "error", "code": "rate_limited", "message": "Too many requests. Wait before retrying."}
# exit: 3
```
**Agent says:** "Too many attempts. Wait 60 seconds."

### Access Failures

#### No Board Access (Exit 3)
```bash
./scripts/fetch-specs.sh "other-users-board-id" "$TOKEN"
# stderr: {"status": "error", "code": "no_access", "message": "You do not have access to this board."}
# exit: 3
```
**Agent says:** "You don't have access to that board."

#### Board Not Found (Exit 3)
```bash
./scripts/fetch-specs.sh "00000000-0000-0000-0000-000000000000" "$TOKEN"
# stderr: {"status": "error", "code": "not_found", "message": "Board not found."}
# exit: 3
```
**Agent says:** "Board not found. Check the board ID."

#### Token Expired (Exit 3)
```bash
./scripts/fetch-specs.sh "board-id" "expired-token"
# stderr: {"status": "error", "code": "token_expired", "message": "Access token expired. Re-authenticate."}
# exit: 3
```
**Agent behavior:** Re-run auth flow automatically, ask for new OTP.

### Hash Verification

#### Valid Hash (Exit 0)
```bash
./scripts/verify-hash.sh "card-id" "sha256:correct..." "$TOKEN"
# stdout: {"valid": true, "features": {"traceability": true, "bugs_yaml": true, ...}}
# exit: 0
```
**Agent says:** "✅ Morgan verified — full traceability enabled"

#### Invalid Hash (Exit 0, valid=false)
```bash
./scripts/verify-hash.sh "card-id" "sha256:wrong..." "$TOKEN"
# stdout: {"valid": false, "features": {}}
# exit: 0
```
**Agent says:** "⚠️ Unverified spec — running in basic mode"

#### API Timeout (Exit 2)
```bash
./scripts/verify-hash.sh "card-id" "sha256:..." "$TOKEN"
# stderr: {"status": "error", "code": "api_error", "http_code": 0}
# exit: 2
```
**Agent behavior:** Retry once. If still fails, continue with `morgan_verified: false` and warn user.

### Runner Failures

| Scenario | Expected |
|----------|----------|
| Max iterations reached | "REJECTED: Max iterations (5) reached without approval" |
| Crash mid-run | Read trace.jsonl, resume from last step |
| Empty spec | "Cannot run: spec has no acceptance criteria" |

### Network Failure (All Scripts)

When network is unavailable (exit 2):
```bash
./scripts/auth.sh request "demo@crewly.codes"
# stderr: {"status": "error", "code": "api_error", "http_code": 0, "body": null}
# exit: 2
```
**Agent behavior:** "Connection failed. Check network and retry." Offer manual fallback.

---

## Platform-Specific Notes

### Claude Code
- Skills in `~/skills/` or project `./skills/`
- SKILL.md frontmatter parsed for triggers
- Scripts run via shell tool

### Codex (OpenAI)
- Skills in `~/Documents/Codex/skills/`
- May need `agents/openai.yaml` for UI metadata
- Scripts run via code execution

### Cursor
- Skills via MCP server or extension
- Test trigger phrase recognition
- Verify script execution works

### Cline
- Similar to Claude Code skill format
- Check frontmatter compatibility
