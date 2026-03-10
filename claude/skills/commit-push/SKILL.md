---
name: commit-push
description: Create git commit and push to remote. 커밋 생성 후 리모트에 푸시.
allowed-tools: Read, Bash, Grep, Glob
---

# Commit and Push

**IMPORTANT: 모든 설명과 요약은 한국어로 작성하세요. 단, 코드 예시와 명령어는 원문 그대로 유지합니다.**

## Philosophy

- **푸시는 되돌리기 어렵다** — 커밋보다 더 신중해야 한다
- **공유 브랜치에 영향을 준다** — 내 변경이 팀 전체에 전파된다
- **푸시 전에 한 번 더 확인한다** — 커밋 후 push 전 최종 점검

## Workflow

### Phase 1: Commit — `/commit` 워크플로우 수행

**`/commit` 스킬의 전체 워크플로우를 따른다:**

1. **Validation** — lint, typecheck, tests 통과 확인
2. **Gather Changes** — `git status`, `git diff` 확인
3. **Understand Changes** — 변경사항 숙고, "왜?"를 묻고, 영향 파악
4. **Security Review** — secrets, debug code 확인
5. **Stage & Commit** — 파일 스테이징, conventional commit 메시지 작성
6. **Verify Commit** — 커밋 결과 확인

**Commit Message Format:**
```
<type>: <subject>

<optional body explaining why>
```

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `perf`, `ci`

### Phase 2: Pre-Push Deliberation — 푸시 전 숙고

**CRITICAL: 커밋 후 바로 푸시하지 않는다. 한 번 더 생각한다.**

```bash
# Review what will be pushed
git log origin/$(git branch --show-current)..HEAD --oneline 2>/dev/null || git log --oneline -3

# Verify branch
git branch --show-current
```

**Push deliberation checklist:**
- [ ] Correct branch? (main/master에 직접 push가 의도된 것인지 확인)
- [ ] All commits are intentional? (실수로 포함된 커밋 없는지)
- [ ] No force push needed? (force push는 명시적 요청 시에만)
- [ ] CI/CD will be triggered — are changes ready for that?

### Phase 3: Push

```bash
# Push to remote (set upstream if new branch)
git push -u origin $(git branch --show-current)
```

### Phase 4: Verify

```bash
git status
git log --oneline -3
```

## Pre-Push Safety Rules

| Rule | Reason |
|------|--------|
| No force push to main/master | Shared history destruction |
| No push with failing tests | Breaks CI for entire team |
| No push of secrets | Once pushed, consider compromised |
| Verify target branch | Wrong branch push is hard to undo |

## Rules

- Only include actual work done in the message
- Do NOT add unnecessary lines (Co-Authored-By, Generated with, etc.)
- Do NOT add promotional or attribution footers
- Do NOT force push to main/master branches

## Anti-Patterns

- Do NOT push without understanding what will be pushed
- Do NOT push immediately after commit without reviewing
- Do NOT commit multiple unrelated changes together
- Do NOT use vague messages like "fix", "update", "WIP"
- Do NOT commit secrets or credentials
- Do NOT skip pre-commit hooks (--no-verify)
- Do NOT force push (--force) unless explicitly requested
- Do NOT amend commits already pushed to shared branches
