# Performance Optimization

## Model Selection Strategy

**Opus 4.5** (Deepest reasoning, PREFERRED):
- Complex architectural decisions
- All agent workflows (planner, architect, debugger, etc.)
- Main development work
- Maximum reasoning requirements
- Research and analysis tasks

**Sonnet 4.5** (Best coding model):
- Simple code generation when Opus is not needed
- Quick edits and modifications
- Orchestrating workflows

**Haiku 4.5** (Fast and economical):
- Simple utility functions
- Documentation updates
- Quick queries

## Context Window Management

Avoid last 20% of context window for:
- Large-scale refactoring
- Feature implementation spanning multiple files
- Debugging complex interactions

Lower context sensitivity tasks:
- Single-file edits
- Independent utility creation
- Documentation updates
- Simple bug fixes

## Ultrathink + Plan Mode

For complex tasks requiring deep reasoning:
1. Use `ultrathink` for enhanced thinking
2. Enable **Plan Mode** for structured approach
3. "Rev the engine" with multiple critique rounds
4. Use split role sub-agents for diverse analysis

## Build Troubleshooting

If build fails:
1. Use **builder** agent
2. Analyze error messages
3. Fix incrementally
4. Verify after each fix
