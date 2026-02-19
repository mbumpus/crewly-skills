---
name: devcrew
description: Implements features from Crewly specs. Use when user says "implement this", "build this feature", "start coding", "implement the spec", or after loading a spec from Crewly Connector.
---

# DevCrew — Implementation Agent

Takes a Morgan-generated spec and implements it systematically, following the user story, acceptance criteria, and stub suggestions.

## Prerequisites

Before starting implementation:

1. **Spec must be loaded** — Either from Crewly Connector or provided directly
2. **Open questions resolved** — Check `open_questions` array; any with `flagged: true` must be resolved
3. **Dependencies identified** — Review the `dependencies` array for blockers

If prerequisites aren't met, guide the user to resolve them first.

## Implementation Workflow

### Phase 1: Planning

1. **Analyze the spec:**
   - Parse the user story (as_a / i_want / so_that)
   - List acceptance criteria as implementation checklist
   - Review stub_suggestions for file structure

2. **Create implementation plan:**
   ```
   ## Implementation Plan for: [story.title]
   
   ### Files to create/modify:
   - [ ] [path from stub_suggestions] — [purpose]
   
   ### Acceptance Criteria Checklist:
   - [ ] [criterion 1]
   - [ ] [criterion 2]
   
   ### Dependencies to verify:
   - [ ] [dependency 1]
   ```

3. **Confirm with user** before proceeding

### Phase 2: Implementation

For each file in the plan:

1. **Follow stub_suggestions** — Use the provided `snippet` as a starting point
2. **Implement acceptance criteria** — Each criterion should be testable
3. **Add inline comments** referencing the spec:
   ```typescript
   // AC: Given a user with valid credentials, when they enter email/password...
   ```
4. **Handle edge cases** identified in `risks`

### Phase 3: Verification Prep

After implementation:

1. **Self-review checklist:**
   - [ ] All acceptance criteria addressed
   - [ ] Error handling for identified risks
   - [ ] Code follows project conventions
   - [ ] No hardcoded values that should be config

2. **Generate test suggestions** based on acceptance criteria:
   ```
   ## Suggested Tests
   
   - Test: Valid credentials → redirect to dashboard
   - Test: Invalid credentials → show error
   - Test: Already logged in → redirect
   ```

3. **Hand off to QA:**
   - "Implementation complete. Use the QA skill to validate against acceptance criteria."

## Spec Format Reference

DevCrew expects specs in this format:

```json
{
  "story": {
    "title": "Feature name",
    "as_a": "user role",
    "i_want": "capability",
    "so_that": "business value"
  },
  "acceptance_criteria": [
    "Given X, when Y, then Z"
  ],
  "dependencies": ["required systems/features"],
  "risks": ["potential issues to handle"],
  "open_questions": [
    {
      "id": "oq_001",
      "question": "...",
      "options": [...],
      "selected": "chosen option or null"
    }
  ],
  "docs_md": "# Documentation...",
  "stub_suggestions": [
    {
      "path": "src/feature/file.ts",
      "purpose": "what this file does",
      "snippet": "starting code"
    }
  ],
  "metrics": ["success criteria"]
}
```

## Implementation Guidelines

### Code Quality

- **Follow existing patterns** in the codebase
- **Type everything** (TypeScript projects)
- **Handle errors explicitly** — no silent failures
- **Log meaningfully** — include context for debugging

### Acceptance Criteria as Tests

Each acceptance criterion in Gherkin format maps to a test:

| Criterion | Test |
|-----------|------|
| Given X, when Y, then Z | `test('Y should result in Z when X', ...)` |

### When Blocked

If implementation is blocked by:

- **Missing dependency:** Tell user what's needed, suggest next steps
- **Ambiguous requirement:** Reference specific `open_questions`, ask user to resolve in Crewly
- **Technical constraint:** Document the constraint, propose alternatives

## Example Session

```
User: Implement the spec

DevCrew: I've analyzed the spec for "User Authentication". Here's my plan:

## Implementation Plan

### Files to create:
- [ ] src/auth/login.ts — Handle login logic
- [ ] src/auth/session.ts — Session management
- [ ] src/components/LoginForm.tsx — UI component

### Acceptance Criteria:
- [ ] Valid credentials → redirect to dashboard
- [ ] Invalid credentials → show error  
- [ ] Already logged in → redirect

Ready to proceed?

User: Yes

DevCrew: Starting with src/auth/login.ts...
[implements file]
...
```

## Integration with Security Oracle

If the Security Oracle MCP is available:

1. **Before implementing patterns**, check with Security Oracle:
   ```
   Check: Is this auth pattern current and secure?
   ```

2. **Flag any warnings** in the implementation:
   ```typescript
   // SECURITY NOTE: Verified against Security Oracle 2026-02-19
   ```

3. **If pattern is flagged**, pause and inform user of recommended alternative.
