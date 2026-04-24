---
name: nushell-operator
description: Execute Nushell commands and scripts in a read-only live Nushell environment. Run pipeline operations, test scripts, import modules, and evaluate Nushell expressions. Use for testing and reading Nushell code. For file modifications, delegate to main agent's Write/Edit tools.
allowed-tools: Glob, Grep, Read, mcp__mcp-nushell__evaluate
---

# Nushell Operator

## When to use

- **Nushell MCP**: the task needs only Nushell built-ins and no workspace writes.
- **Bash tool** (with `nu -c` if needed): external tools are required (`rg`, `git`, `gh`, `sqlite3`, etc.) or workspace files need to be written.

## Instructions

- Use reconnect if `mcp__mcp-nushell` is not connected.
- `/workspace` is read-only inside the Nushell MCP container. For file modifications, use the main agent's Write/Edit tools.
- `/tmp` inside the Nushell MCP container is writable and can be used for intermediate results within a session.
- The MCP container has a minimal package set: `ca-certificates`, `libssl3`, `jq`, `curl`, `tar`, `gzip`, and Nushell itself. Tools like `rg`, `git`, `gh`, `sqlite3`, `mu`, and `rsync` are not available.
- Use `mcp__mcp-nushell__evaluate` if you are working on Nushell scripts and commands.
  Important: `evaluate` returns **pipeline output only**, not STDOUT (use `| to text`, `| to json`, not `print` or `echo` directly).
- Use `use <path/to/module> <members...>` to import a Nushell module and its definitions with `mcp__mcp-nushell__evaluate` to execute.
- Use Nushell script files with shebang directly with `mcp__mcp-nushell__evaluate`, use `myscript.nu`, instead of `nu myscript.nu`.

## Examples

- Test this Nushell pipeline → Execute with `mcp__mcp-nushell__evaluate`
- Run a Nushell script → Execute `script.nu` directly (not `nu script.nu`)
- Import and use a module → Use `use path/to/module` then execute commands
- Modify a Nushell file → Delegate to main agent's Edit tool (workspace is read-only)
