---
name: pr-create
description: Create pull request with proper format. PR 생성, 변경사항 분석, PR 메시지 작성.
allowed-tools: Read, Bash, Grep, Glob
---

# Create Pull Request

**IMPORTANT: 모든 설명과 요약은 한국어로 작성하세요. 단, 코드 예시와 명령어는 원문 그대로 유지합니다.**

## Philosophy

- **PR은 코드 리뷰의 시작이다** — 리뷰어가 맥락을 이해할 수 있도록 작성한다
- **변경의 "왜"를 설명한다** — diff는 "무엇"을 보여주지만, PR은 "왜"를 설명해야 한다
- **영향 범위를 정직하게 밝힌다** — 변경의 리스크와 한계를 숨기지 않는다

## Workflow

### 0. Run Validation First
Before creating PR, run `/validate` to ensure all checks pass:
- Lint
- Typecheck
- Tests

**If validation fails, fix all issues before proceeding.**

### 1. Gather Context
```bash
# Check current branch status
git status

# View commits since branching from main
git log origin/main..HEAD --oneline

# View full diff for PR description
git diff origin/main...HEAD --stat
git diff origin/main...HEAD
```

### 2. Deep Analysis — 변경사항 심층 분석

**CRITICAL: diff 통계만 보지 않는다. 변경의 의미를 이해한다.**

**For each changed file, read and understand:**
1. **Purpose** — why was this file changed?
2. **Impact** — what depends on this file? What could break?
3. **Completeness** — are there related changes that should be included?

**Deliberation questions:**
- What is the **single purpose** of this PR?
- Could this be broken into smaller PRs?
- What are the **risks** of merging this?
- What **edge cases** might be affected?
- Is there adequate **test coverage** for the changes?
- Are there any **breaking changes** for consumers?

### 3. Sync with Main (if needed)
```bash
git fetch origin
git rebase origin/main
# Resolve conflicts if any, then:
git push --force-with-lease
```

### 4. Craft PR Description

**Before writing, articulate:**
1. What problem does this PR solve? (Summary)
2. What specific changes were made and why? (Changes)
3. How should a reviewer verify this works? (Test Plan)
4. What risks or limitations exist? (if any)

```bash
gh pr create --title "<type>(<scope>): <subject>" --body "$(cat <<'EOF'
## Summary
- Brief description of what and WHY

## Changes
- Change 1: why this was needed
- Change 2: why this was needed

## Test Plan
- [ ] How to verify changes work
- [ ] Edge cases to test
EOF
)"
```

### 5. Verify PR
```bash
gh pr view --web
```

## PR Title Format
```
<type>(<scope>): <subject>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance

**Examples:**
```
feat(auth): add OAuth2 login support
fix(api): handle null response from server
refactor(utils): simplify date formatting logic
```

## PR Quality Checklist

Before creating:
- [ ] I can explain the purpose of every changed file
- [ ] Changes are focused (one purpose per PR)
- [ ] Test coverage exists for new/changed logic
- [ ] No secrets, debug code, or unintended files
- [ ] PR title accurately describes the change
- [ ] Description explains WHY, not just WHAT

## Rules

- Only include actual work done in the message
- Do NOT add unnecessary lines (Co-Authored-By, Generated with, etc.)
- Do NOT add promotional or attribution footers

## Anti-Patterns

- Do NOT create PR without reading the full diff
- Do NOT write vague descriptions like "various fixes"
- Do NOT include unrelated changes to pad the PR
- Do NOT skip the test plan — reviewers need it
- Do NOT hide risks or known issues from the description
