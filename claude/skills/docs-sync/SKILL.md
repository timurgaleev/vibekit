---
name: docs-sync
description: Analyze code and documentation, find gaps, update docs. 문서 업데이트, 코드 문서 동기화, 문서 검토.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# Documentation Sync

**IMPORTANT: 모든 설명과 요약은 한국어로 작성하세요. 단, 코드 예시와 명령어는 원문 그대로 유지합니다.**

Analyze entire codebase and documentation, find gaps, update docs.

## Philosophy

- **문서는 코드의 진실을 반영해야 한다** — 코드와 다른 문서는 문서가 없는 것보다 해롭다
- **빠진 것보다 틀린 것이 더 위험하다** — 잘못된 문서는 개발자를 잘못된 방향으로 이끈다
- **실제 동작을 확인한다** — 코드를 읽고, 문서와 대조하고, 차이를 발견한다

## Rules

- **Skip temporary/generated directories** - apply exclude patterns before scanning
- **Do NOT create new documentation files** unless explicitly requested
- Only `README.md` and `CLAUDE.md` in project root
- All other docs in `docs/` directory
- Single source of truth - no duplicate content
- Update existing docs, don't add new ones

## Exclude Patterns

**Important: Always skip these directories before scanning the codebase.**

These are auto-generated files, not source code - do not document them.

| Category | Directories |
|----------|-------------|
| Dependencies | `node_modules/`, `vendor/`, `bower_components/`, `.pnp/` |
| Build outputs | `dist/`, `build/`, `out/`, `target/`, `.next/`, `.nuxt/`, `.vercel/` |
| Cache | `.cache/`, `.tmp/`, `tmp/`, `__pycache__/`, `.turbo/`, `.parcel-cache/` |
| Virtual envs | `.venv/`, `venv/`, `.env/`, `env/` |
| VCS | `.git/`, `.svn/`, `.hg/` |
| IDE | `.idea/`, `.vscode/`, `.vs/` |
| Test outputs | `coverage/`, `.nyc_output/`, `test-results/` |
| Generated | `*.min.js`, `*.bundle.js`, lock files (`package-lock.json`, etc.) |
| OS | `.DS_Store`, `Thumbs.db` |

## Process

### 1. Analyze Code
- Apply exclude patterns first
- Scan only actual source files (src/, lib/, app/, etc.)
- Extract public APIs, functions, classes
- Find environment variables, CLI flags
- Build code inventory

### 2. Analyze Documentation
- Read README.md, CLAUDE.md, docs/*
- Extract documented items
- Check structure and index
- Build docs inventory

### 3. Verify Accuracy — 정확성 검증

**CRITICAL: 빠진 문서를 찾기 전에, 기존 문서가 정확한지 확인한다.**

For each documented item:
1. **Find the corresponding code** — does the documented function/API/config actually exist?
2. **Compare behavior** — does the code do what the docs say?
3. **Check parameters** — are function signatures, API parameters, config options accurate?
4. **Verify examples** — do documented examples actually work with current code?

**Ask "Why is this wrong?"** for each mismatch:
- Was the code changed without updating docs?
- Was the doc written based on planned (not actual) behavior?
- Has a dependency changed the behavior?

### 4. Compare & Report
```
## Gap Report

Inaccurate (PRIORITY — fix first):
- README.md says MAX_RETRY=3, code uses MAX_RETRY=5
- API docs show POST /api/users, code expects PUT /api/users

Undocumented:
- function parseConfig() in src/config.ts

Orphaned (remove from docs):
- /api/legacy in docs/API.md (endpoint deleted)
```

### 5. Update
- Fix inaccurate documentation first (highest priority)
- Remove orphaned content
- Add missing documentation
- Do NOT create new files

### 6. Verify
- Examples work
- Links valid
- No duplicates
- Documented behavior matches actual code behavior

## Structure

```
project/
├── README.md         # Overview only
├── CLAUDE.md         # AI instructions only
└── docs/
    ├── README.md     # Index
    └── *.md          # All other docs
```

## Quality

- Clear headings, no skipped levels
- Working code examples
- No duplicate content (link instead)
- Keep docs concise

## Anti-Patterns

- Do NOT assume documentation is correct — verify against code
- Do NOT add documentation for trivial/obvious code
- Do NOT create new doc files unless explicitly requested
- Do NOT document implementation details that change frequently
- Do NOT copy code into documentation — reference it
