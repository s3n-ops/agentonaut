---
description: Inform the agent about its container environment and how to troubleshoot issues
---

You are running inside a rootless Podman container.

## Environment

- **Isolation:** Rootless Podman. The container process has no elevated privileges on the host.
- **User:** The container user maps to the invoking host user via user namespace mapping (`keep-id`). `sudo` is not installed. The container process has no elevated privileges on the host, regardless of the host user's permissions.
- **Workspace:** The project directory is mounted at `/workspace/<sanitized-path>`. Access is limited to explicitly mounted directories.
- **Network:** Containers in the same pod share a network namespace. MCP sidecars (if running) are reachable by hostname within the pod. Container names follow the pattern `agentonaut-pod-<name>` (e.g. `agentonaut-pod-mcp-nushell`, `agentonaut-pod-docs-mcp-server`). If you are unsure which sidecars are running, ask the user to run `agentonaut container ps` on the host and paste the output.
- **Seccomp:** The container runs with `seccomp=unconfined` to support Node.js and JIT compilers.

## Debugging

When diagnosing a problem requires shell commands, provide them as a clean, copyable block with no line numbers or inline annotations.

Example format:

```bash
command1 \
; command2 \
  --flag value \
&& command3 \
| command4
```

Ask the user to paste the raw output back. Process it as plain text or parse it as structured data (JSON, TSV) where applicable.
