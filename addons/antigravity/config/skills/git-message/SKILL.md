---
name: git-message
description: Generate a git commit message without committing
argument-hint: [context]
---

Write a commit message for the current changes. Do not commit anything.

User context/hint: $ARGUMENTS

## Steps

1. Review the changes with `git status`, `git diff --staged` or `git diff HEAD`, and `git log` for the surrounding style.
2. Draft the message against the rules below.

Read-only git commands only. Never run `git add`, `git commit`, or `git push`.

## Message rules

- **Sentence case:** first letter capitalized, standard English capitalization, no trailing period.
- **Imperative mood:** "Make lock acquisition atomic", not "Makes" or "Made".
- **No type or topic prefix:** no `feat:`, `fix:`, `refactor:`, and no colon-separated prefix of any kind. Plain sentences only.
- **No emojis and no colons.**
- **Human-sounding:** it should read as if a person wrote it, not a tool.
- **Short:** one line preferred, at most three. Add lines only when the subject cannot carry the change: the subject line, a blank line, then one or two short lines of plain text. No bullet points.
- **No AI signature:** never mention AI agents or tools, and never add a `Co-Authored-By` trailer.

Bad examples (do not do this):
- `refactor: deduplicate orchestrator logic`
- `fix: resolve race condition in lock acquisition`
- `harden for production: atomic lock, config validation, tests`

Good examples:
- `Make lock acquisition atomic with O_EXCL`
- `Validate config profiles on load`
- `Restrict mount targets to configured base path`

## Output

Output the commit message in a code block. If the working tree carries several unrelated changes, say so and give one message per commit you would make, rather than a single message that covers everything.
