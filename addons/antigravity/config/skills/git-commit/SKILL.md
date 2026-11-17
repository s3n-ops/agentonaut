---
name: git-commit
description: Stage changes and commit them with a concise message
argument-hint: [context]
---

Stage the changes and commit them under the user's own credentials, without any AI signature or attribution.

User context/hint: $ARGUMENTS

## Steps

1. Review the changes with `git status`, `git diff --staged` or `git diff HEAD`, and `git log` for the surrounding style.
2. Check the diff for secrets before staging: credentials, tokens, keys, passwords, connection strings, personal data. If you find one, name what and where, never the value, and stop.
3. Draft the message against the rules below.
4. Stage the files that belong to the change with `git add`, then commit with `git commit -m "<subject>"`, adding `-m "<body>"` only when the message has more than one line.
5. Report the message that was committed and the resulting status.

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

## Scope

Commit what the working tree holds. If it carries several unrelated changes, say so and propose splitting it into separate commits rather than inventing one message that covers everything.

If the repository is on its default branch, say so before committing and let the user decide whether a branch should come first.
