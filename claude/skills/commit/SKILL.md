---
name: commit
description: Create git commit with conventional format. 커밋 생성, 변경사항 분석, 커밋 메시지 작성.
allowed-tools: Read, Bash, Grep, Glob
---

# Create Commit

**IMPORTANT: 모든 설명과 요약은 한국어로 작성하세요. 단, 코드 예시와 명령어는 원문 그대로 유지합니다.**

## Philosophy

- **변경사항을 이해한 후 커밋한다** — diff를 보는 것이 아니라, 변경의 목적과 영향을 파악한다
- **커밋 메시지는 "왜"를 담는다** — 무엇을 바꿨는지가 아니라 왜 바꿨는지를 설명한다
- **하나의 커밋, 하나의 목적** — 관련 없는 변경은 분리한다

## Workflow

### 0. Run Validation First
Before committing, run `/validate` to ensure all checks pass:
- Lint
- Typecheck
- Tests

**If validation fails, fix all issues before proceeding.**

### 1. Gather Changes
```bash
# Check current status (never use -uall flag)
git status

# View staged and unstaged changes
git diff
git diff --cached

# View recent commits for message style reference
git log --oneline -10
```

### 2. Understand Changes — 변경사항 숙고

**CRITICAL: diff를 읽는 것이 아니라, 변경의 의미를 이해한다.**

For each changed file:
1. **Read the changed file** — understand the full context, not just the diff
2. **Ask "Why?"** — why was this change needed? What problem does it solve?
3. **Assess impact** — what other code depends on this? Could this break anything?
4. **Verify correctness** — is the change actually correct? Are edge cases handled?

**Deliberation checklist:**
- [ ] I understand WHY each change was made
- [ ] Changes are logically related (single purpose)
- [ ] No unintended side effects
- [ ] The change addresses the root cause, not a symptom

### 3. Security Review
Before staging:
- [ ] No secrets (API keys, passwords, tokens)
- [ ] No debug code (console.log, print statements)
- [ ] No unintended files (.env, node_modules, etc.)
- [ ] No sensitive data in error messages or comments

### 4. Stage Files
```bash
# Stage specific files (preferred)
git add path/to/file1 path/to/file2

# Or stage all changes (use with caution)
git add -A
```

**Avoid staging:**
- `.env`, `credentials.json`, secrets
- Large binaries or generated files
- Unrelated changes

### 5. Craft Commit Message

**Before writing the message, articulate:**
1. What type of change is this? (feat/fix/refactor/...)
2. What is the core purpose in one sentence?
3. Why was this change necessary? (for the body)

```bash
git commit -m "$(cat <<'EOF'
<type>: <subject>

<optional body explaining why>
EOF
)"
```

### 6. Verify Commit
```bash
git status
git log --oneline -3
```

## Commit Message Format

```
<type>: <subject>

<optional body>
```

**Types:**
| Type | Description |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `refactor` | Code refactoring (no behavior change) |
| `test` | Adding or updating tests |
| `chore` | Maintenance, dependencies |
| `perf` | Performance improvement |
| `ci` | CI/CD changes |

**Subject Rules:**
- Use imperative mood: "Add feature" not "Added feature"
- No period at the end
- Max 50 characters
- Focus on "what" and "why", not "how"

**Examples:**
```
feat: add user authentication with OAuth2
fix: handle null response from payment API
refactor: simplify date formatting logic
docs: update API documentation for v2 endpoints
test: add unit tests for user service
chore: update dependencies to latest versions
```

## Rules

- Only include actual work done in the message
- Do NOT add unnecessary lines (Co-Authored-By, Generated with, etc.)
- Do NOT add promotional or attribution footers

## Anti-Patterns

- Do NOT commit without understanding what changed and why
- Do NOT commit multiple unrelated changes together
- Do NOT use vague messages like "fix", "update", "WIP"
- Do NOT commit secrets or credentials
- Do NOT skip pre-commit hooks (--no-verify)
- Do NOT amend commits already pushed to shared branches
