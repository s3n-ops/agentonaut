---
description: Save session progress to markdown document
allowed-tools: Write, Read, Bash(date:*)
---

Write a concise markdown document summarizing the current session.

Include:
1. What was accomplished
2. Files created or modified (with paths)
3. Key decisions
4. Next steps

Save the document to: `CHECKPOINT-$(date -u +%Y-%m-%dT%H-%M-%S).md`

Be precise and efficient. Enable seamless handoff to the next Claude Code instance.
