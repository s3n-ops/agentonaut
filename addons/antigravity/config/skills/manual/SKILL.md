---
name: manual
description: Search local documentation and online resources for a topic
argument-hint: [topic]
---

Answer the user's query by consulting the most authoritative sources available, prioritizing local documentation files before searching the web.

User Query: $ARGUMENTS

Follow this priority:
1. Offline Documentation: Search local files under `~/Documents/offline-documentation/`.
2. Local workspace: Search project files, READMEs, and inline documentation.
3. Official online documentation: If local sources are insufficient, search the web for official documentation.
4. Web search: Query search engines for general topics.

Provide a concise answer. Always cite sources.
