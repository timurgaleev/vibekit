---
name: code-audit
description: Deep code audit — analyze entire codebase for issues, root causes, and improvements. 전체 코드 심층 감사 — 문제점, 근본원인, 개선사항 분석.
allowed-tools: Read, Bash, Grep, Glob, Task
---

# Code Audit

**IMPORTANT: 모든 설명과 요약은 한국어로 작성하세요. 단, 코드 예시와 명령어는 원문 그대로 유지합니다.**

프로젝트의 전체 구현 코드를 심층 분석하여 문제점, 근본원인, 개선사항을 도출합니다.

## Philosophy

- **증상이 아니라 근본원인을 찾는다** — "왜?"를 5번 반복한다
- **심사숙고한다** — 성급한 판단을 피하고, 코드를 끝까지 읽은 후 결론을 내린다
- **맥락을 이해한다** — 개별 파일이 아닌 시스템 전체의 흐름을 파악한다
- **실질적 위험을 구별한다** — 이론적 문제와 실제 영향이 있는 문제를 구분한다

## Rules

- Read files completely before making judgments
- Trace call chains and data flows end-to-end
- Distinguish symptoms from root causes
- Prioritize findings by actual impact, not theoretical risk
- Do NOT suggest changes without understanding full context
- Do NOT flag style preferences as issues
- Do NOT recommend fixes for non-existent problems

## Exclude Patterns

**Important: Always skip these directories before scanning.**

| Category | Directories |
|----------|-------------|
| Dependencies | `node_modules/`, `vendor/`, `bower_components/`, `.pnp/` |
| Build outputs | `dist/`, `build/`, `out/`, `target/`, `.next/`, `.nuxt/`, `.vercel/` |
| Cache | `.cache/`, `.tmp/`, `tmp/`, `__pycache__/`, `.turbo/`, `.parcel-cache/` |
| Virtual envs | `.venv/`, `venv/`, `.env/`, `env/` |
| VCS | `.git/`, `.svn/`, `.hg/` |
| IDE | `.idea/`, `.vscode/`, `.vs/` |
| Test outputs | `coverage/`, `.nyc_output/`, `test-results/` |
| Generated | `*.min.js`, `*.bundle.js`, lock files |
| OS | `.DS_Store`, `Thumbs.db` |

## Process

### Phase 1: Reconnaissance — 프로젝트 전체 파악

프로젝트의 전체 구조, 기술 스택, 아키텍처를 파악합니다.

```bash
# Project type detection
ls -la package.json pyproject.toml go.mod Cargo.toml Makefile 2>/dev/null

# Directory structure overview
ls -la
ls -d */ 2>/dev/null
```

**Read key files:**
1. `README.md` — project purpose and setup
2. `CLAUDE.md` — project conventions (if exists)
3. Package manifest (`package.json`, `pyproject.toml`, `go.mod`, etc.)
4. Configuration files (`tsconfig.json`, `.eslintrc`, `vite.config.*`, etc.)

**Build a mental model:**
- What is the project? What problem does it solve?
- What is the tech stack?
- What are the entry points?
- What are the architectural boundaries?

### Phase 2: Deep Analysis — 병렬 심층 분석

**Team 모드를 사용하여 4개의 전문 에이전트를 병렬로 실행합니다.**

#### Team 모드 사용 (권장)

`TeamCreate` 도구가 사용 가능한 경우 Team 모드로 실행합니다:

```
1. TeamCreate로 "code-audit" 팀 생성
2. TaskCreate로 4개 감사 태스크 생성
3. Task 도구로 각 에이전트를 team_name="code-audit"으로 스폰
4. 모든 에이전트가 완료될 때까지 대기 (SendMessage 알림)
5. TeamDelete로 팀 정리
```

**Team 모드 스폰 예시:**
```
Task(
  subagent_type="Explore",
  team_name="code-audit",
  name="security-auditor",
  prompt="[Security Audit 프롬프트]"
)
```

#### Fallback: Task 도구 직접 사용

`TeamCreate`가 없는 경우 Task 도구로 병렬 에이전트를 직접 스폰합니다.

---

아래 4가지 분석을 동시에 실행합니다:

#### Agent 1: Security Audit
```
Analyze the entire codebase for security issues:
1. Hardcoded secrets (API keys, passwords, tokens, connection strings)
2. Input validation gaps (user input, API parameters, file uploads)
3. Injection vulnerabilities (SQL, XSS, command injection, path traversal)
4. Authentication/authorization flaws
5. Sensitive data exposure (logs, error messages, responses)
6. Insecure dependencies (known CVEs)
7. CSRF/CORS misconfiguration
8. Cryptographic weaknesses

For each finding, trace the data flow from source to sink.
Report file paths, line numbers, and severity.
```

#### Agent 2: Architecture & Design Audit
```
Analyze the codebase architecture and design:
1. Dependency structure — circular dependencies, tight coupling
2. Module boundaries — are responsibilities clearly separated?
3. Abstraction levels — leaky abstractions, wrong abstractions, missing abstractions
4. Data flow — how data moves through the system, transformation points
5. Error propagation — how errors flow, where they get swallowed
6. State management — shared mutable state, race conditions
7. Configuration management — hardcoded values, environment handling
8. API design — consistency, versioning, contract clarity

For each finding, explain WHY it's a problem and what the systemic impact is.
Report file paths and line numbers.
```

#### Agent 3: Code Quality & Maintainability Audit
```
Analyze the codebase for quality and maintainability issues:
1. Dead code — unused functions, variables, imports, files
2. Code duplication — copy-pasted logic that should be unified
3. Complexity — functions >50 lines, files >800 lines, deep nesting >4 levels
4. Naming — unclear, misleading, or inconsistent naming
5. Type safety — use of any, missing types, type assertions
6. Error handling — empty catch blocks, swallowed errors, generic handlers
7. Mutation — mutable state where immutability is expected
8. Magic values — unexplained numbers, strings, boolean flags

For each finding, report file paths, line numbers, and specific code.
```

#### Agent 4: Testing & Reliability Audit
```
Analyze the testing strategy and reliability:
1. Test coverage — what is tested, what is NOT tested
2. Critical paths without tests — business logic, error handlers, edge cases
3. Test quality — do tests actually verify behavior or just existence?
4. Flaky test indicators — timing dependencies, shared state, order dependency
5. Missing integration tests — component interaction gaps
6. Error scenario coverage — are failure paths tested?
7. Mock accuracy — do mocks reflect real behavior?
8. Build/CI reliability — configuration issues, missing steps

Report specific untested functions/paths and their risk level.
```

#### Team 종료

Team 모드를 사용한 경우, 모든 에이전트 완료 후 팀을 정리합니다:
```
1. 각 에이전트에 SendMessage(type="shutdown_request") 전송
2. 모든 shutdown_response 확인 후 TeamDelete 실행
```

### Phase 3: Root Cause Analysis — 근본원인 추적

After gathering findings from all agents, perform root cause analysis:

**For each significant finding, apply the 5 Whys:**

```
Finding: [Description]
├── Why 1: [Direct cause]
│   ├── Why 2: [Underlying cause]
│   │   ├── Why 3: [Systemic cause]
│   │   │   ├── Why 4: [Process/design cause]
│   │   │   │   └── Why 5: [Root cause]
│   │   │   │       └── ROOT CAUSE: [Fundamental issue]
```

**Look for patterns across findings:**
- Do multiple findings share a common root cause?
- Are there systemic issues (process, architecture, tooling)?
- What is the relationship between findings?

### Phase 4: Impact Assessment — 영향도 평가

Classify each finding:

| Severity | Impact | Examples |
|----------|--------|----------|
| **CRITICAL** | Immediate risk to production, data loss, security breach | SQL injection, exposed secrets, data corruption |
| **HIGH** | Significant reliability/security risk, likely to cause incidents | Missing auth checks, unhandled errors in critical paths, race conditions |
| **MEDIUM** | Degrades maintainability, increases tech debt, potential bugs | Code duplication, missing tests for core logic, tight coupling |
| **LOW** | Minor quality issues, future maintenance burden | Naming inconsistencies, minor dead code, style violations |

**Assess each finding:**
1. **Likelihood** — how likely is this to cause a real problem?
2. **Blast radius** — if it fails, what is affected?
3. **Reversibility** — how hard is it to fix after the fact?
4. **Urgency** — does this need immediate attention?

### Phase 5: Report — 감사 보고서 작성

```markdown
# Code Audit Report

> Project: {project name}
> Date: {date}
> Scope: Full codebase analysis

## Executive Summary

[2-3 sentences: overall health assessment, key risks, recommended actions]

## Findings by Severity

### CRITICAL ({count})

#### 1. {Finding Title} — {file}:{line}
- **문제**: [What is wrong]
- **근본원인**: [Root cause from 5 Whys analysis]
- **영향**: [What happens if not fixed]
- **권장 조치**: [Specific fix recommendation]

### HIGH ({count})
...

### MEDIUM ({count})
...

### LOW ({count})
...

## Root Cause Patterns

[Group findings by common root causes]

### Pattern 1: {Root Cause Category}
- **영향받는 영역**: {list of affected areas}
- **근본원인**: {systemic explanation}
- **개선 방향**: {strategic recommendation}

### Pattern 2: ...

## Positive Highlights

[What the project does well — balanced review]

- ✅ {Good practice 1}
- ✅ {Good practice 2}

## Recommended Action Plan

### Immediate (CRITICAL)
1. {Action item with specific file/line references}

### Short-term (HIGH)
1. {Action item}

### Medium-term (MEDIUM)
1. {Action item}

## Metrics Summary

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| Security Issues | {n} | 0 | {status} |
| Test Coverage | {n}% | ≥80% | {status} |
| Files >800 lines | {n} | 0 | {status} |
| Functions >50 lines | {n} | 0 | {status} |
| Dead code files | {n} | 0 | {status} |
| Code duplication | {n} spots | minimal | {status} |
```

## Audit Dimensions Checklist

### Security
- [ ] No hardcoded secrets
- [ ] All inputs validated at boundaries
- [ ] No injection vulnerabilities
- [ ] Auth/authz properly implemented
- [ ] Sensitive data not exposed in logs/errors
- [ ] Dependencies free of known CVEs

### Architecture
- [ ] Clear module boundaries
- [ ] No circular dependencies
- [ ] Consistent data flow patterns
- [ ] Proper separation of concerns
- [ ] Configuration externalized

### Code Quality
- [ ] No dead code
- [ ] Minimal duplication
- [ ] Functions <50 lines
- [ ] Files <800 lines
- [ ] Nesting depth <4 levels
- [ ] Consistent naming

### Error Handling
- [ ] No swallowed errors
- [ ] Specific error types used
- [ ] Error messages informative
- [ ] Failure paths tested

### Testing
- [ ] Core logic tested
- [ ] Critical paths tested
- [ ] Edge cases covered
- [ ] Error scenarios tested
- [ ] Coverage ≥80%

### Type Safety
- [ ] No `any` types
- [ ] Proper null handling
- [ ] Return types explicit
- [ ] API contracts typed

## Anti-Patterns

- Do NOT treat every finding as critical — prioritize honestly
- Do NOT suggest fixes without understanding the codebase's constraints
- Do NOT flag intentional patterns as issues (e.g., framework conventions)
- Do NOT recommend massive refactoring without justifying ROI
- Do NOT ignore the project's stage — MVP code has different standards than production
- Do NOT confuse "different from my preference" with "wrong"
- Do NOT skip positive highlights — balanced reviews build trust
