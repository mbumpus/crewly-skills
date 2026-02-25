---
name: crewly-runner
description: Orchestrates the DevCrew → QA loop with ThoughtChain traceability. Runs implementation and validation cycles until spec passes or max iterations reached. Triggers on "run crew", "implement spec", "start implementation", "execute spec", "run the crew", or auto-invoked after crewly-connector loads a spec.
---

# Crewly Runner

Orchestrates implementation cycles with full audit trail. Runs DevCrew → QA → Fix loops until acceptance criteria pass.

## Input Contract

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| spec | object | yes | Spec from crewly-connector |
| spec.card_id | string | yes | UUID of the card |
| spec.title | string | yes | Feature title |
| spec.spec_json | object | yes | Full spec with ACs |
| morgan_verified | boolean | yes | Hash verification status |
| features | object | yes | Enabled features |
| workspace | string | no | Target directory (default: cwd) |

## Output Contract

```json
{
  "spec_title": "PDF Merger",
  "iterations": 2,
  "max_iterations": 5,
  "final_verdict": "APPROVED",
  "files_created": ["src/App.js", "src/utils/pdfMerger.js"],
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

## Configuration

```yaml
crewly_runner:
  max_iterations: 5
  strategy: targeted_fixes  # or full_regen
  traceability: auto        # auto | enabled | disabled
```

`traceability: auto` = enabled if morgan_verified, disabled otherwise.

## Prerequisites

- Spec loaded (via crewly-connector or manually)
- Workspace directory identified
- Verification status known

## ThoughtChain Traceability

**When morgan_verified: true**, the runner maintains:

```
workspace/
└── crewly/
    ├── trace.jsonl    # Append-only audit trail
    └── bugs.yaml      # Bug registry
```

**When morgan_verified: false**, traceability is disabled. Crew still runs, no audit trail.

## Trace Entry Schema

Each handoff writes ONE line to `crewly/trace.jsonl`:

```json
{
  "trace_id": "uuid-v4",
  "timestamp": "2026-02-20T18:28:00.000Z",
  "actor": "DevCrew | QA",
  "action": "implement | validate | fix",
  "iteration": 1,
  "reasoning_mode": "Hybrid",
  "confidence_score": "91%",
  "confidence_signal": "🟢",
  "reasoning_steps": ["Step 1", "Step 2"],
  "files_hash": "sha256:abc123...",
  "files_changed": ["src/App.js"],
  "verdict": "APPROVED | REJECTED | null",
  "bugs_found": ["BUG-001"],
  "bugs_fixed": ["BUG-001"],
  "output_hash": "sha256:def456..."
}
```

### Computing files_hash

```bash
find src -type f \( -name "*.js" -o -name "*.ts" -o -name "*.tsx" -o -name "*.jsx" -o -name "*.css" \) \
  -exec sha256sum {} \; | sort | sha256sum | cut -d' ' -f1
```

## Realtime Status Updates + Auto-Move

When `access_token` is available, update card status AND move between columns.

**Important:** Pass `$BOARD_ID` to `update-status.sh` to enable realtime UI updates.

```bash
# === START: Move to In Progress, set building ===
./scripts/move-card.sh "$CARD_ID" "In Progress" "$BOARD_ID" "$TOKEN"
./scripts/update-status.sh "$CARD_ID" "DevCrew" "building" "Starting..." "$TOKEN" "$BOARD_ID"

# === ITERATION 1: DevCrew implements ===
./scripts/update-status.sh "$CARD_ID" "DevCrew" "building" "Iteration 1/5" "$TOKEN" "$BOARD_ID"
# ... implement ...
./scripts/update-status.sh "$CARD_ID" "DevCrew" "building" "6 files created" "$TOKEN" "$BOARD_ID"

# === QA validates ===
./scripts/update-status.sh "$CARD_ID" "QA" "reviewing" "Validating ACs" "$TOKEN" "$BOARD_ID"
# ... validate ...

# === IF REJECTED: Stay in In Progress ===
./scripts/update-status.sh "$CARD_ID" "QA" "failed" "2 bugs found" "$TOKEN" "$BOARD_ID"
./scripts/update-status.sh "$CARD_ID" "DevCrew" "building" "Fixing BUG-001, BUG-002" "$TOKEN" "$BOARD_ID"
# ... fix and loop ...

# === IF APPROVED: Move to Complete ===
./scripts/update-status.sh "$CARD_ID" "QA" "passed" "All ACs pass ✅" "$TOKEN" "$BOARD_ID"
./scripts/move-card.sh "$CARD_ID" "Complete" "$BOARD_ID" "$TOKEN"
```

**The magic:** Watch the card slide from Backlog → In Progress (pulsing amber) → Complete (green). Updates appear instantly in the web app.

Column name matching is fuzzy:
- "progress", "wip", "building" → "In Progress"
- "done", "complete", "finished" → "Complete"
- "backlog", "todo" → "Backlog"

## Execution Flow

### Initialize

```bash
mkdir -p crewly
if [[ "$morgan_verified" == "true" ]]; then
    [[ -f crewly/bugs.yaml ]] || echo "[]" > crewly/bugs.yaml
    touch crewly/trace.jsonl
fi
```

### Loop (max 5 iterations)

```
for iteration in 1..max_iterations:
    
    # === DEVCREW PHASE ===
    if iteration == 1:
        Run devcrew skill: implement full spec
    else:
        Run devcrew skill: fix bugs from previous QA
    
    [DevCrew writes trace entry before handoff]
    
    # === QA PHASE ===
    Run qa skill: validate against acceptance criteria
    
    [QA writes trace entry + bugs.yaml before verdict]
    
    # === CHECK RESULT ===
    if verdict == "APPROVED":
        break
    
    if iteration == max_iterations:
        Final verdict: REJECTED (max iterations)
        break
```

### Completion Summary → crewly/runner.md

**MUST write** `crewly/runner.md` at run completion:

```markdown
# Crewly Runner — Complete

**Spec:** {title}
**Card ID:** {card_id}
**Iterations:** {n} of {max}
**Final Verdict:** {APPROVED | REJECTED}
**Traceability:** {Enabled | Disabled}
**Completed:** {ISO timestamp}

## Files Created
| File | Lines | Purpose |
|------|-------|---------|
| src/App.js | 45 | Main app shell |

## Acceptance Criteria
- [x] AC1: ...
- [x] AC2: ...

## Iteration History
| # | Actor | Action | Verdict | Bugs |
|---|-------|--------|---------|------|
| 1 | DevCrew | implement | - | - |
| 1 | QA | validate | REJECTED | BUG-001 |
| 2 | DevCrew | fix | - | fixed BUG-001 |
| 2 | QA | validate | APPROVED | - |

## Artifacts
- Trace: `crewly/trace.jsonl`
- Bugs: `crewly/bugs.yaml`
```

Write this file BEFORE returning the JSON result. The `artifacts` object in output should include:

```json
"artifacts": {
  "trace": "crewly/trace.jsonl",
  "bugs": "crewly/bugs.yaml",
  "summary": "crewly/runner.md"
}
```

## Bug Entry Schema (bugs.yaml)

```yaml
- id: BUG-001
  reported_at: "2026-02-20T18:31:00.000Z"
  reported_by: QA
  status: open | fixed | verified
  severity: critical | high | medium | low
  confidence: high | medium | low
  ac: AC2
  file: src/components/FileList.js
  location:
    line_start: 34
    line_end: 45
  description: "Files show static icon instead of PDF thumbnails"
  suggested_fix: "Render canvas thumbnail from pdf-lib"
  verification: "Upload PDF, confirm thumbnail shows first page"
  resolved_by: DevCrew
  resolved_at: "2026-02-20T18:33:00.000Z"
```

## Handoff Protocol

**CRITICAL: Write trace BEFORE handing off**

Each actor (DevCrew, QA) must:
1. Complete their work
2. Compute files_hash of current state
3. Write their trace entry to trace.jsonl
4. THEN hand off to next actor

This ensures the audit trail reflects actual handoff moments.

## Error Handling

| Error | Response |
|-------|----------|
| Empty spec | "Cannot run: spec has no acceptance criteria" |
| No spec loaded | "Load a spec first with crewly-connector" |
| Max iterations | "REJECTED: Max iterations (5) reached without approval" |
| DevCrew crash | Log error to trace, attempt recovery |
| QA crash | Log error to trace, attempt recovery |

## Fallback Behavior

- **Crash mid-run:** Read trace.jsonl to find last completed step, resume from there
- **Max iterations reached:** Report final state, list remaining bugs
- **Traceability disabled:** Run normally without writing artifacts
- **Files hash mismatch:** Log warning, continue (possible external modification)

## Error Recovery

If runner crashes mid-execution:
1. Read trace.jsonl to find last completed step
2. Resume from that point
3. Trace shows exactly where failure occurred

## Handoff Format

### To DevCrew (implement)
```json
{
  "action": "implement",
  "iteration": 1,
  "spec": { ... },
  "morgan_verified": true
}
```

### To DevCrew (fix)
```json
{
  "action": "fix",
  "iteration": 2,
  "spec": { ... },
  "bugs": [{ "id": "BUG-001", ... }],
  "morgan_verified": true
}
```

### To QA
```json
{
  "action": "validate",
  "iteration": 1,
  "spec": { ... },
  "morgan_verified": true
}
```

## Manual Fallback

If automation fails or user prefers manual control:

1. **Run DevCrew manually:**
   - User says: "implement the spec" or "fix these bugs"
   - DevCrew implements, reports results

2. **Run QA manually:**
   - User says: "validate the code" or "QA this"
   - QA validates, reports verdict + bugs

3. **User controls iteration:**
   - If REJECTED: user says "fix the bugs" → DevCrew
   - If APPROVED: done
   - User decides when to stop

4. **Traceability still works:**
   - Each skill writes its own trace entry
   - Manual mode = same artifacts, user-controlled pacing
