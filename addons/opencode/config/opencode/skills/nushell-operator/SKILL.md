---
name: nushell-operator
description: Execute Nushell commands and scripts in a read-only live Nushell environment. Run pipeline operations, test scripts, import modules, and evaluate Nushell expressions. Use for testing and reading Nushell code. For file modifications, delegate to main agent's Write/Edit tools.
---

# Nushell Operator

## When to use

- **Nushell MCP**: the task needs only Nushell built-ins and no workspace writes.
- **Shell tool** (with `nu -c` if needed): external tools are required (`rg`, `git`, `gh`, `sqlite3`, etc.) or workspace files need to be written.

## Instructions

- If the `mcp-nushell` MCP server is not connected, tell the user.
- `/workspace` is read-only inside the Nushell MCP container. For file modifications, use the main agent's file editing tools.
- `/tmp` inside the Nushell MCP container is writable and can be used for intermediate results within a session.
- The MCP container has a minimal package set: `ca-certificates`, `libssl3`, `jq`, `curl`, `tar`, `gzip`, and Nushell itself. Tools like `rg`, `git`, `gh`, `sqlite3`, `mu`, and `rsync` are not available.
- Use the `evaluate` tool of the `mcp-nushell` MCP server (`mcp-nushell_evaluate`) if you are working on Nushell scripts and commands.
  Important: `evaluate` returns **pipeline output only**, not STDOUT (use `| to text`, `| to json`, not `print` or `echo` directly).
- Use `use <path/to/module> <members...>` to import a Nushell module and its definitions with the `evaluate` tool of the `mcp-nushell` MCP server (`mcp-nushell_evaluate`) to execute.
- Use Nushell script files with shebang directly with the `evaluate` tool of the `mcp-nushell` MCP server (`mcp-nushell_evaluate`), use `myscript.nu`, instead of `nu myscript.nu`.

## Examples

- Test this Nushell pipeline → Execute with the `evaluate` tool of the `mcp-nushell` MCP server (`mcp-nushell_evaluate`)
- Run a Nushell script → Execute `script.nu` directly (not `nu script.nu`)
- Import and use a module → Use `use path/to/module` then execute commands
- Modify a Nushell file → Delegate to main agent's file editing tools (workspace is read-only)
