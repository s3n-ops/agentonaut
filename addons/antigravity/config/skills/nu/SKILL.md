---
name: nu
description: Interact with the Nushell shell
argument-hint: [expression]
---

Execute the user's request using the local `nu` command.

User Request: $ARGUMENTS

**When to use Nushell:**
- The task requires structured data processing or Nushell's native features.

**Usage:**
- Run the expression using `run_command` with `nu -c "<expression>"`.

**Agentonaut containers:**
- `nu` is installed in the agent container, along with `nu_plugin_formats` and `nu-lint`.
- The `mcp-nushell` sidecar runs in the same pod when launched with a kube profile that includes it. Its Nushell environment is separate: `/workspace` is read-only there and external tools (`rg`, `git`, `gh`, `sqlite3`) are absent. Use the local `nu` for anything that writes to the workspace or needs those tools.
