---
name: context-load
description: Load saved project context from ./context.md. 저장된 프로젝트 컨텍스트 로드.
allowed-tools: Read, Bash, Glob
---

# Context Load

**IMPORTANT: 모든 설명과 요약은 한국어로 작성하세요. 단, 코드 예시와 명령어는 원문 그대로 유지합니다.**

저장된 프로젝트 컨텍스트를 로드하여 프로젝트를 빠르게 이해합니다.

## Workflow

### 1. Check Context File Exists
```bash
ls -la ./context.md 2>/dev/null
```

If not found:
- Inform user: "컨텍스트 파일이 없습니다. `/context-init`을 먼저 실행하세요."
- Stop execution

### 2. Check Context Freshness
```bash
# Get last modified date
stat -f "%Sm" ./context.md 2>/dev/null || stat -c "%y" ./context.md 2>/dev/null
```

If older than 7 days, warn user:
```
⚠️ 컨텍스트가 7일 이상 지났습니다. `/context-init`으로 갱신을 권장합니다.
```

### 3. Load Context
Read the entire `./context.md` file.

### 4. Verify Recent Changes
```bash
# Check for recent changes that might not be in context
git log --oneline -5 --since="$(stat -f '%Sm' -t '%Y-%m-%d' ./context.md 2>/dev/null || date -d "$(stat -c '%y' ./context.md)" '+%Y-%m-%d')" 2>/dev/null
```

If there are commits after context was created, note:
```
📝 컨텍스트 생성 이후 N개의 커밋이 있습니다.
최근 변경사항은 반영되지 않았을 수 있습니다.
```

### 5. Report Summary

```
## Context Loaded ✅

**Project**: [Project Name]
**Last Updated**: YYYY-MM-DD
**Tech Stack**: [Languages/Frameworks]

### Quick Reference
- Build: `npm run build`
- Test: `npm test`
- Dev: `npm run dev`

컨텍스트가 로드되었습니다. 프로젝트에 대해 질문하세요.
```

## What Context Provides

After loading, you will know:

| Information | Description |
|-------------|-------------|
| **Project Overview** | What the project does |
| **Tech Stack** | Languages, frameworks, dependencies |
| **Directory Structure** | Where to find what |
| **Key Files** | Important entry points and modules |
| **Commands** | How to build, test, run |
| **Architecture** | How components interact |
| **Conventions** | Coding style and patterns |

## Limitations

Context load provides a **snapshot** of the project:

| Limitation | Workaround |
|------------|------------|
| Static snapshot | Run `/context-init` to refresh |
| Summary, not full code | Read specific files when needed |
| May be outdated | Check git log for recent changes |

## When to Refresh Context

Run `/context-init` again when:
- Major refactoring occurred
- New features added
- Dependencies changed significantly
- Architecture changed
- Context is older than 1 week

## Rules

- Always check if context file exists first
- Warn if context is stale
- Note any recent commits not in context
- Provide quick reference commands
- Be ready to read additional files if needed

## Anti-Patterns

- Do NOT assume context is always up-to-date — always verify against actual code
- Do NOT rely only on context for critical decisions — read the real files
- Do NOT skip reading actual code when making changes
- Do NOT trust documented commands without verifying they still work
