---
name: nushell-operator
description: Execute Nushell commands and scripts in a read-only live Nushell environment. Run pipeline operations, test scripts, import modules, and evaluate Nushell expressions. Use for testing and reading Nushell code. For file modifications, delegate to main agent's Write/Edit tools.
allowed-tools: Glob, Grep, Read, mcp__mcp-nushell__evaluate
---

# Nushell Operator

## Instructions

- Use reconnect if `mcp__mcp-nushell` is not connected.
- **IMPORTANT**: The Nushell environment has **read-only access** to workspace files. Use `mcp__mcp-nushell__evaluate` only for reading, testing, and evaluation. For file modifications, use the main agent's Write/Edit tools.
- Use `mcp__mcp-nushell__evaluate` if you are working on Nushell scripts and commands.
  Important: `evaluate` returns **pipeline output only**, not STDOUT (use `| to text`, `| to json`, not `print` or `echo` directly).
- Use `use <path/to/module> <members...>` to import a Nushell module and its definitions with `mcp__mcp-nushell__evaluate` to execute.
- Use Nushell script files with shebang directly with `mcp__mcp-nushell__evaluate`, use `myscript.nu`, instead of `nu myscript.nu`.

## Examples

- Test this Nushell pipeline → Execute with `mcp__mcp-nushell__evaluate`
- Run a Nushell script → Execute `script.nu` directly (not `nu script.nu`)
- Import and use a module → Use `use path/to/module` then execute commands
- Modify a Nushell file → Delegate to main agent's Edit tool (workspace is read-only)
