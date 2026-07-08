---
description: Generate git commit message
argument-hint: [context]
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*)
---

Write a short, concise, one-line git commit message for: $ARGUMENTS

You may use read-only git commands (status, diff, log) but do not execute write commands (add, commit, push).

Rules for the commit message:
- Imperative mood, sentence case (first word capitalized, standard English capitalization rules), no trailing period
- No type prefix or topic schema (no "feat:", "fix:", "refactor:" etc.)
- No colon-separated structure, plain sentence only
- Sound like a human wrote it, not a tool
- One line only, no bullet points, no explanation

Bad examples (do not do this):
- `refactor: deduplicate orchestrator logic`
- `fix: resolve race condition in lock acquisition`
- `harden for production: atomic lock, config validation, tests`

Good examples:
- `make lock acquisition atomic with O_EXCL`
- `validate config profiles on load`
- `restrict mount targets to configured base path`
