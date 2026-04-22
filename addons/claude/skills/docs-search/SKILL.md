---
name: docs-search
description: "Search docs-mcp-server for authoritative documentation. Use when general knowledge is insufficient: precise syntax questions, code examples that must be correct, edge cases, version-specific behavior, or discovering unknown functionality. Do not use for questions you can answer confidently from training data."
allowed-tools: mcp__docs-mcp-server__list_libraries, mcp__docs-mcp-server__search_docs
---

# Docs Search

## When to use

- Syntax details you are not certain about
- Code examples that must compile or run correctly
- Edge cases and version-specific behavior
- Discovering flags, options, or features you are not aware of

Do not use for general questions you can answer confidently.

## Instructions

1. Call `mcp__docs-mcp-server__list_libraries` to retrieve the list of indexed libraries.
2. Select the library that best matches the topic.
3. Call `mcp__docs-mcp-server__search_docs` with the selected library and a focused search term.
4. If the server is unavailable or no matching library exists, inform the user.

Never use `mcp__docs-mcp-server__fetch_url` — it consumes too many tokens.
