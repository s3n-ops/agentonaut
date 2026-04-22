---
description: Generate git commit message
argument-hint: [context]
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*)
---

Write a short, concise, one-line `git commit` message for: $ARGUMENTS

You may use read-only git commands (status, diff, log) but do not execute write commands (add, commit, push).
