# Git Workflow

## CRITICAL: Commit & Push Policy

**NEVER commit or push without explicit user permission.**
- 사용자가 명시적으로 요청할 때만 `git commit` 실행
- 사용자가 명시적으로 요청할 때만 `git push` 실행
- 코드 변경 후 자동으로 커밋하지 않음
- "커밋해", "커밋하세요", "commit" 등 명확한 지시가 있을 때만 수행

## Commit Message Format

```
<type>: <description>

<optional body>
```

Types: feat, fix, refactor, docs, test, chore, perf, ci

## Pull Request Workflow

When creating PRs:
1. Analyze full commit history (not just latest commit)
2. Use `git diff [base-branch]...HEAD` to see all changes
3. Draft comprehensive PR summary
4. Include test plan with TODOs
5. Push with `-u` flag if new branch

## Feature Implementation Workflow

1. **Plan First**
   - Use **planner** agent to create implementation plan
   - Identify dependencies and risks
   - Break down into phases

2. **Implementation**
   - Write tests for new functionality
   - Implement functionality
   - Run tests to verify correctness
   - Verify 80%+ test coverage

3. **Code Review**
   - Use **code-reviewer** agent for quality and security review
   - Address CRITICAL and HIGH issues
   - Fix MEDIUM issues when possible

4. **Commit & Push**
   - Detailed commit messages
   - Follow conventional commits format
