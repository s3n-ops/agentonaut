---
name: nushell-command-expert
description: Search and list Nushell native commands by name, description, or category. Get detailed command help and usage examples. Use when looking for Nushell commands, checking command syntax, or when user mentions Nushell built-in commands, filters, or pipeline operations.
---

# Nushell Command Expert

## Instructions

- If the `mcp-nushell` MCP server is not connected, tell the user.
- Use the `list_commands` tool of the `mcp-nushell` MCP server (`mcp-nushell_list_commands`) to list all available Nushell native commands.
- Use the `list_commands` tool of the `mcp-nushell` MCP server (`mcp-nushell_list_commands`) with the `find` parameter to find a specific Nushell native command by searching command names, descriptions and search terms.
- Use the `command_help` tool of the `mcp-nushell` MCP server (`mcp-nushell_command_help`) with the `name` parameter to get help for a specific Nushell command.

## Examples

- What Nushell command filters tables? → Search with "filter" or "table"
- How do I use the `each` command? → Get help for specific command
- List all filesystem commands → Search with "filesystem" or "directory"
