---
name: validate
description: Run lint, typecheck, and tests. Fix all issues automatically. 린트, 타입체크, 테스트 실행. 문제 자동 수정.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# Validate

**IMPORTANT: 모든 설명과 요약은 한국어로 작성하세요. 단, 코드 예시와 명령어는 원문 그대로 유지합니다.**

Run lint, typecheck, and tests. Fix all failures. Repeat until all pass.

## Philosophy

- **증상이 아니라 근본원인을 고친다** — lint 경고를 suppress하는 것이 아니라, 경고의 원인을 제거한다
- **실패 메시지를 끝까지 읽는다** — 에러 메시지에 답이 있다
- **연쇄 실패를 구별한다** — 하나의 근본원인이 여러 실패를 만들 수 있다

## Rules

- Read files completely before fixing
- Fix root causes, not symptoms
- Make minimal, focused changes
- Never skip or ignore failures
- Re-run checks after each fix

## Process

### 1. Detect Project Type
Scan for configuration files to determine project type:

| File | Project Type | Tools |
|------|--------------|-------|
| `package.json` | Node.js | npm/pnpm scripts |
| `pyproject.toml` / `setup.py` | Python | pytest, mypy, ruff/pylint |
| `go.mod` | Go | go vet, golangci-lint, go test |

### 2. Run Lint
```bash
# Node.js (Primary)
npm run lint
pnpm lint
npx eslint .

# Python
ruff check .
pylint **/*.py

# Go
golangci-lint run
go vet ./...
```

On failure — **Root Cause Analysis:**
1. Read error messages carefully — what rule is violated and why?
2. Read the entire affected file — understand the context
3. **Ask "Why?"** — why does this code violate the rule?
   - Is it a genuine issue? → Fix the code
   - Is the rule misconfigured? → Fix the config (rare, justify clearly)
   - Is it a false positive? → Add targeted exception with comment explaining why
4. Fix with minimal changes
5. Re-run lint

### 3. Run Typecheck
```bash
# Node.js (TypeScript) (Primary)
npm run typecheck
pnpm typecheck
npx tsc --noEmit

# Python
mypy .
pyright

# Go (built-in)
go build ./...
```

On failure — **Root Cause Analysis:**
1. Read type error messages — trace the type flow
2. **Identify the root error** — one type error can cascade into many
   - Fix the earliest error first, then re-run (cascading failures may resolve)
3. Read the file and understand what the code is trying to do
4. **Ask "Why?"** — why does the type not match?
   - Is the type definition wrong? → Fix the definition
   - Is the usage wrong? → Fix the usage
   - Is a dependency's type incomplete? → Add declaration or fix import
5. Do NOT use `any` or `@ts-ignore` to silence errors — fix the actual type
6. Re-run typecheck

### 4. Run Tests
```bash
# Node.js (Primary)
npm test
pnpm test
npx jest
npx vitest

# Python
pytest

# Go
go test ./...
```

On failure — **Root Cause Analysis:**
1. Read test failure output completely
2. **Identify: is the test wrong or the implementation wrong?**
   - Read the test code — what behavior does it expect?
   - Read the implementation — what does it actually do?
   - Read recent changes — did a change break the contract?
3. **Apply 5 Whys:**
   ```
   Test fails: expected "hello" got "Hello"
   └── Why? → Function now capitalizes first letter
       └── Why? → Recent refactor changed string handling
           └── Why? → Root cause: refactor didn't update test expectations
   ```
4. Fix the root cause (update test if spec changed, fix code if regression)
5. Re-run tests

### 5. Identify Cascading Failures

**Before fixing each failure individually, look for patterns:**

- Do multiple lint errors come from the same root cause?
- Do type errors cascade from a single type definition?
- Do test failures share a common setup or dependency?

**Fix the root cause first**, then re-run to see how many other failures resolve automatically.

### 6. Final Validation
Re-run all checks in sequence:
1. Lint
2. Typecheck
3. Tests

All must pass before completion.

### 7. Report Summary
```
## Validation Summary

Checks Run:
- Lint: PASS (fixed 3 issues)
- Typecheck: PASS
- Tests: PASS (15 tests)

Root Causes Fixed:
- [Root cause 1]: description (resolved N lint/type/test failures)
- [Root cause 2]: description

Files Modified:
- src/utils.ts: Fixed unused variable
- src/api.ts: Fixed type error
- src/config.ts: Fixed missing return type
```

## Common Fixes

### Lint Issues
- Unused variables: Remove or use them
- Missing semicolons: Add them (if required by style)
- Inconsistent quotes: Standardize
- Import order: Sort alphabetically

### Type Issues
- Missing types: Add explicit type annotations
- Type mismatch: Fix the source of mismatch
- Null/undefined: Add proper null checks
- Generic inference: Add explicit type parameters

### Test Issues
- Assertion failures: Fix code or update test expectation
- Timeout: Optimize or increase timeout
- Missing mocks: Add proper mocks/stubs
- Flaky tests: Fix race conditions

## Anti-Patterns

- Do NOT disable lint rules without justification
- Do NOT use `any` type to bypass type errors
- Do NOT skip failing tests
- Do NOT add `// @ts-ignore` without fixing root cause
- Do NOT modify test expectations without understanding why
- Do NOT fix each failure in isolation — look for shared root causes first
