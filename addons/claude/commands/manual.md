---
description: Search documentation for a topic
argument-hint: [topic]
allowed-tools: mcp__docs-mcp-server__search_docs, mcp__docs-mcp-server__list_libraries, mcp__docs-mcp-server__find_version
---

Read the documentation: $ARGUMENTS

Do not guess or speculate. Follow this priority:

1. Check if a documentation skill exists for this topic
2. Search docs-mcp-server for relevant documentation or code examples
3. Search the internet for official documentation or code examples

Always cite sources and provide concrete examples from documentation.

Never use `mcp__docs-mcp-server__fetch_url` as it consumes too many tokens. Use WebFetch or WebSearch instead.
