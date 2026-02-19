---
name: qa
description: Validates implementations against Crewly specs. Use when user says "validate this", "review the code", "QA this", "check against spec", "run QA", or after DevCrew completes implementation.
---

# QA — Validation Agent

Reviews implementations against Morgan specs, checking acceptance criteria, code quality, and security patterns.

## Prerequisites

Before running QA:

1. **Spec must be in context** — From Crewly Connector or provided directly
2. **Implementation must exist** — Files created by DevCrew or user
3. **Know what files to review** — List of implemented files

## QA Workflow

### Phase 1: Acceptance Criteria Validation

For each acceptance criterion in the spec:

1. **Locate the implementation** — Find the code that addresses this criterion
2. **Verify behavior** — Does the code actually implement what the criterion requires?
3. **Check edge cases** — Are error conditions handled?

**Report format:**
```
## Acceptance Criteria Review

### ✅ PASS: Given valid credentials, when user logs in, then redirect to dashboard
- Implementation: src/auth/login.ts:45-62
- Verified: Redirect logic correctly routes to /dashboard on success

### ❌ FAIL: Given invalid credentials, when user attempts login, then show error
- Implementation: src/auth/login.ts:63-70
- Issue: Error message not displayed to user, only logged to console
- Fix: Add error state to component and render error message

### ⚠️ PARTIAL: Given user already logged in, when visiting login page, then redirect
- Implementation: src/auth/login.ts:12-20
- Issue: Check exists but doesn't handle expired sessions
- Suggestion: Add session expiry check before redirect
```

### Phase 2: Code Quality Review

Check for common issues:

**Security:**
- [ ] No hardcoded secrets or API keys
- [ ] Input validation present
- [ ] SQL/NoSQL injection prevention
- [ ] XSS prevention (if applicable)
- [ ] Authentication/authorization checks

**Error Handling:**
- [ ] All async operations have try/catch or .catch()
- [ ] Errors are logged with context
- [ ] User-facing error messages are helpful but don't leak internals

**Code Style:**
- [ ] Follows project conventions
- [ ] Functions are reasonably sized
- [ ] Clear naming
- [ ] No commented-out code blocks

**TypeScript (if applicable):**
- [ ] Types are explicit, not `any`
- [ ] Null/undefined handled
- [ ] Interfaces match actual data shapes

### Phase 3: Metrics Alignment

Check implementation against the `metrics` in the spec:

```
## Metrics Review

### "Login success rate > 95%"
- Status: ✅ Achievable
- Implementation supports metric: Yes, success/failure paths are clear

### "Average login time < 2 seconds"
- Status: ⚠️ Risk
- Concern: No optimization for slow network conditions
- Suggestion: Add loading state, consider caching
```

### Phase 4: Security Oracle Check (if available)

If Security Oracle MCP is connected:

1. **Extract patterns** used in implementation
2. **Query Security Oracle** for each pattern
3. **Flag any issues:**
   ```
   ## Security Oracle Findings
   
   🔴 CRITICAL: Pattern 'jwt.verify(token, secret)' flagged
   - CVE: CVE-2026-0892
   - Issue: Timing attack vulnerability
   - Fix: Use constant-time comparison
   
   ✅ SAFE: Pattern 'bcrypt.hash(password, 12)' verified current
   ```

### Phase 5: Summary Report

Generate final QA report:

```
# QA Report: [Feature Title]
Date: [timestamp]

## Summary
- Acceptance Criteria: 4/5 passing
- Code Quality: 3 issues found
- Security: 1 critical finding

## Must Fix (Blocking)
1. [Critical security issue]
2. [Failed acceptance criterion]

## Should Fix (Important)
1. [Partial acceptance criterion]
2. [Code quality issue]

## Could Fix (Nice to have)
1. [Minor style issue]

## Recommendation
🔴 NOT READY — Address must-fix items before merge
```

## QA Verdicts

| Verdict | Meaning | Action |
|---------|---------|--------|
| ✅ APPROVED | All criteria pass, no critical issues | Ready to merge |
| ⚠️ CONDITIONAL | Minor issues, no blockers | Can merge with follow-up |
| 🔴 REJECTED | Critical issues or failed criteria | Must fix before merge |

## Example Session

```
User: QA the auth implementation

QA: I'll review the implementation against the spec.

## Acceptance Criteria Review

### ✅ PASS: Valid credentials → redirect to dashboard
- Found in: src/auth/login.ts:45-62
- Behavior: Correct

### ❌ FAIL: Invalid credentials → show error
- Found in: src/auth/login.ts:63-70
- Issue: Error only logged, not displayed

### ✅ PASS: Already logged in → redirect
- Found in: src/auth/login.ts:12-20
- Behavior: Correct

## Code Quality
- ⚠️ No input sanitization on email field
- ⚠️ Password field accepts empty string

## Recommendation
🔴 REJECTED — 1 failed acceptance criterion, 2 security concerns

### Must Fix:
1. Display error message to user on invalid credentials
2. Add input validation for email and password fields

Would you like me to detail the fixes needed?
```

## Integration with DevCrew

When QA finds issues:

1. **List specific fixes needed** with file paths and line numbers
2. **Offer to hand back to DevCrew** for fixes:
   - "Use DevCrew skill to implement these fixes"
3. **After fixes, re-run QA:**
   - "Use QA skill to validate the fixes"

## Reporting to Crewly (Optional)

If user wants to report QA results back to Crewly:

```
Would you like me to update the card status in Crewly?
- Mark as "In Review" with QA findings
- Add QA report as comment
```

This requires the Crewly Connector to be authenticated.
