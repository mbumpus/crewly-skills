# Crewly Codes Skills

MCP-compatible skills for AI coding agents. Works with Claude Code, Codex, Cursor, Cline, and any MCP-compatible tool.

## Quick Start (For Users)

Just say one of these:

| What You Say | What Happens |
|--------------|--------------|
| **"Connect my Crewly account"** | Authenticates via email OTP |
| **"Load my feature spec"** | Fetches your locked spec from Crewly Codes |
| **"Build this feature"** | Implements the spec with QA validation |

The agent handles the entire flow — asks for email, board ID, OTP, loads spec, starts building.

**If triggers miss**, say explicitly:
> "Use the crewly-connector skill and load my spec"

**Starter prompts** (for docs, onboarding, or your app UI):
- `Connect Crewly`
- `Load My Spec`  
- `Build This Feature`

---

## Installation

Copy the `skills/` folder to your agent's skills directory:

```bash
# Claude Code
cp -r skills/* ~/skills/crewly-codes/

# Codex
cp -r skills/* ~/Documents/Codex/skills/crewly-codes/

# Or symlink
ln -s /path/to/crewlyCodes/skills ~/skills/crewly-codes
```

## Skills

| Skill | Purpose | Triggers |
|-------|---------|----------|
| crewly-connector | Auth, fetch specs, verify hash | "connect to crewly", "load spec" |
| crewly-runner | Orchestrates DevCrew → QA loops | "run crew", "implement spec" |
| devcrew | Implements features from specs | "implement this", "build" |
| qa | Validates against acceptance criteria | "validate", "QA this" |

## Architecture

```
skills/
├── README.md                    # This file
├── GOLDEN-FLOWS.md              # Regression test prompts
├── crewly-connector/
│   ├── SKILL.md                 # Skill definition
│   └── scripts/
│       ├── auth.sh              # OTP request/verify
│       ├── fetch-specs.sh       # Get locked specs
│       └── verify-hash.sh       # Morgan hash verification
├── crewly-runner/
│   └── SKILL.md
├── devcrew/
│   └── SKILL.md
└── qa/
    └── SKILL.md
```

## Key Features

### Deterministic Scripts

Auth, API calls, and hash verification use shell scripts for consistency:

```bash
# Request OTP
./crewly-connector/scripts/auth.sh request user@example.com

# Verify OTP
./crewly-connector/scripts/auth.sh verify user@example.com 847291

# Fetch specs
./crewly-connector/scripts/fetch-specs.sh <board_id> <token>

# Verify Morgan hash
./crewly-connector/scripts/verify-hash.sh <card_id> <hash> <token>
```

### Input/Output Contracts

Each skill defines explicit contracts:

- **Input Contract** — Required fields and types
- **Output Contract** — JSON schema of results
- **Handoff Format** — What's passed to the next skill

### ThoughtChain Traceability

When `morgan_verified: true`, the runner maintains:

```
workspace/
└── crewly/
    ├── trace.jsonl    # Append-only audit trail
    └── bugs.yaml      # Bug registry with lifecycle
```

### Golden Flows

See `GOLDEN-FLOWS.md` for regression test prompts. Use these to verify skills work correctly on any platform.

## Workflow

1. **crewly-connector** authenticates and loads a spec
2. Auto-hands off to **crewly-runner**
3. Runner orchestrates **devcrew** → **qa** loops
4. Continues until APPROVED or max iterations

```
User: Connect to Crewly and load my PDF merger spec

[crewly-connector]
  → Authenticates via OTP
  → Fetches locked specs
  → Verifies Morgan hash
  → Auto-hands off to crewly-runner

[crewly-runner]
  → Iteration 1: devcrew implements, qa validates
  → Bug found? Iteration 2: devcrew fixes, qa re-validates
  → Continue until APPROVED or max iterations
  
Result: Working code + audit trail
```

## Configuration

Environment variables (optional, defaults baked in):

```bash
CREWLY_API_URL=https://api.crewly.codes
CREWLY_API_KEY=sb_publishable_ulOfuc_3ZOZSpsxiZxpg9A_dDUbX8ep
```

## Testing

Run golden flows against your target platform:

1. Open `GOLDEN-FLOWS.md`
2. Try each trigger phrase
3. Verify expected behavior
4. Document any platform-specific quirks

## Cross-Platform Notes

### Claude Code
- Skills in `~/skills/` or project `./skills/`
- SKILL.md frontmatter parsed for triggers
- Scripts run via shell tool

### Codex (OpenAI)
- Skills in `~/Documents/Codex/skills/`
- Optional `agents/openai.yaml` for UI metadata
- Scripts run via code execution

### Cursor
- Skills via MCP server or extension
- Test trigger phrase recognition

### Cline
- Similar to Claude Code skill format
- Check frontmatter compatibility

## Cross-Platform Portability

No universal skill standard exists yet. This package follows a **portable core + adapters** pattern:

**Portable (works everywhere):**
- `SKILL.md` — name + description (trigger signals) + contracts
- `scripts/` — deterministic auth/API behavior
- `GOLDEN-FLOWS.md` — regression test prompts

**Platform-specific (add as needed):**
- Discovery conventions (folder layout)
- Metadata files (`openai.yaml` for Codex UI)
- Permission models (shell access, env vars)

Current skills work on Claude Code and Codex without adapters. Add platform-specific files to `adapters/<platform>/` if needed later.

## License

MIT
