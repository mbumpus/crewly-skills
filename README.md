# Crewly Skills

**Wherever you code, Crewly Codes.**

Professional AI crews for your code agent. Morgan specs your features. DevCrew builds them. QA validates against acceptance criteria.

## Installation

### Option 1: npx skills (recommended)

```bash
npx skills install crewly
```

This installs all Crewly skills to your code agent's skills directory automatically.

### Option 2: Manual Installation

Clone this repo to your agent's skills directory:

**Claude Code:**
```bash
git clone https://github.com/crewlycodes/skills ~/.claude/skills/crewly
```

**Codex:**
```bash
git clone https://github.com/crewlycodes/skills ~/agents/skills/crewly
```

**GitHub Copilot:**
```bash
git clone https://github.com/crewlycodes/skills .github/skills/crewly
```

**Cursor:**
```bash
git clone https://github.com/crewlycodes/skills ~/.cursor/skills/crewly
```

**Gemini CLI:**
```bash
git clone https://github.com/crewlycodes/skills ~/.gemini/skills/crewly
```

## Skills Included

### crewly-connector
Authenticates with Crewly Codes and fetches your Morgan-generated specs.

**Triggers:** "connect to crewly", "load spec", "fetch card", "get crewly spec"

### devcrew
Implementation agent that builds features from Morgan specs, following acceptance criteria and stub suggestions.

**Triggers:** "implement this", "build this feature", "start coding", "implement the spec"

### qa
Validation agent that reviews implementations against specs, checking acceptance criteria, code quality, and security patterns.

**Triggers:** "validate this", "review the code", "QA this", "check against spec"

## Workflow

1. **Spec with Morgan** — Use [crewly.codes](https://crewly.codes) to expand your ideas into full specifications
2. **Connect** — "Connect to Crewly, board [YOUR_BOARD_ID]"
3. **Build** — "Implement the spec"
4. **Validate** — "QA this implementation"

## Requirements

- A [Crewly Codes](https://crewly.codes) account (free tier available)
- Any supported code agent (Claude Code, Codex, Copilot, Cursor, Gemini CLI, Cline, Goose)

## Supported Platforms

| Platform | Status | Skills Directory |
|----------|--------|------------------|
| Claude Code | ✅ | `~/.claude/skills/` |
| OpenAI Codex | ✅ | `~/agents/skills/` |
| GitHub Copilot | ✅ | `.github/skills/` |
| Cursor | ✅ | `~/.cursor/skills/` |
| Gemini CLI | ✅ | `~/.gemini/skills/` |
| Cline | ✅ | `.cline/skills/` |
| Goose | ✅ | `~/.goose/skills/` |

## Links

- **Website:** [crewly.codes](https://crewly.codes)
- **Documentation:** [docs.crewly.codes](https://docs.crewly.codes)
- **Agent Skills Standard:** [agentskills.io](https://agentskills.io)

## License

MIT — use it, fork it, build on it.

---

*One skill set. Every platform.*
