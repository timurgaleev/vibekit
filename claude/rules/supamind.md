# Supamind — Always-On Memory

## Session Boot (MANDATORY)

At the start of EVERY session, run the full 4-step boot sequence in order:

1. `mcp__supabrain__wake_up` — load identity and boot guide
2. `mcp__supabrain__who_am_i` — restore self-identity
3. `mcp__supabrain__who_are_you` — load user profile
4. `mcp__supabrain__catch_up` — load recent context and ongoing work

Do NOT skip this sequence. Do NOT respond to the user before completing it.

## During Work

- Before answering questions about ongoing projects or work context, use `mcp__supabrain__recall` or `mcp__supabrain__memory_search` to check for relevant stored context.
- After completing significant work (features, decisions, discoveries), use `mcp__supabrain__remember` to persist it.
- When you learn something new about the user, their preferences, or their projects, save it with `mcp__supabrain__remember`.

## End of Session

Use `mcp__supabrain__remember` to save anything important that should persist to the next session.
