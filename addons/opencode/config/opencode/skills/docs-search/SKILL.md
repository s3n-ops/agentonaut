---
name: docs-search
description: "Search docs-mcp-server for authoritative documentation. Use when general knowledge is insufficient: precise syntax questions, code examples that must be correct, edge cases, version-specific behavior, or discovering unknown functionality. Do not use for questions you can answer confidently from training data."
---

# Docs Search

## When to use

- Syntax details you are not certain about
- Code examples that must compile or run correctly
- Edge cases and version-specific behavior
- Discovering flags, options, or features you are not aware of

Do not use for general questions you can answer confidently.

## Instructions

1. Call the `list_libraries` tool of the `docs-mcp-server` MCP server (`docs-mcp-server_list_libraries`) to retrieve the list of indexed libraries.
2. Select the library that best matches the topic.
3. Call the `search_docs` tool of the `docs-mcp-server` MCP server (`docs-mcp-server_search_docs`) with the selected library and a focused search term.
4. If the server is unavailable or no matching library exists, inform the user.

Never use the `fetch_url` tool of the `docs-mcp-server` MCP server (`docs-mcp-server_fetch_url`), because it consumes too many tokens.
