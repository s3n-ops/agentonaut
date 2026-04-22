use std log

const MCP_MODULE_VERSION = "0.6.10"

#
# Register MCPs in running container from config
#
# Reads MCP profiles from config and registers them in the container
# using 'claude mcp add' command.
#
export def register [
    cfg_data: record           # Config bundle from cfg extract
]: any -> nothing {
    let mcps = ($cfg_data | get --optional mcps | default [])

    if ($mcps | is-empty) {
        log info "No MCPs configured for this profile"
        return
    }

    # Sanitize workspace path for container path
    let workspace_sanitized = (
        $cfg_data.workspace_path
        | str replace --regex '^/' ''
        | str replace --regex '[^a-zA-Z0-9._-]' '-' --all
        | str replace --regex '-+' '-' --all
        | str trim --char '-'
    )

    let container_workspace = $"/workspace/($workspace_sanitized)"
    let full_container_name = $"($cfg_data.agentonaut_podman_pod_name)-($cfg_data.container_name)"

    log info $"Registering ($mcps | length) MCPs in container"

    # Get agent-specific MCP command template from config
    let mcp_command_template = ($cfg_data | get --optional agent_mcp_command | default "")

    # Skip if agent doesn't support MCP commands
    if ($mcp_command_template | is-empty) {
        log info $"Agent ($cfg_data.agent_name) does not support MCP registration, skipping"
        return
    }

    let mcp_cmd_base = ($mcp_command_template | split row " " | first)
    mut registered_any = false

    # Register each MCP
    for mcp in $mcps {
        log info $"Registering MCP: ($mcp.name) \(($mcp.transport)\)"

        # Remove existing MCP to ensure clean registration with current config
        let remove_cmd = $"cd ($container_workspace) && ($mcp_cmd_base) mcp remove ($mcp.name)"
        do { ^podman exec $full_container_name bash -c $remove_cmd } | complete

        # Substitute template variables
        let mcp_command = (
            $mcp_command_template
            | str replace "{transport}" $mcp.transport
            | str replace "{name}" $mcp.name
            | str replace "{url}" $mcp.url
        )

        let cmd = $"cd ($container_workspace) && ($mcp_command)"

        let result = (
            do { ^podman exec $full_container_name bash -c $cmd } | complete
        )

        if $result.exit_code == 0 {
            log info $"MCP registered: ($mcp.name)"
            $registered_any = true
        } else {
            log warning $"Failed to register MCP ($mcp.name): ($result.stderr | str trim)"
        }
    }

    # Restart agent container if config was modified to apply changes and refresh TTY
    if $registered_any {
        log info $"Restarting agent container to apply configuration: ($full_container_name)"
        let restart_result = (^podman restart $full_container_name | complete)
        if $restart_result.exit_code != 0 {
            log error $"Failed to restart container: ($restart_result.stderr | str trim)"
        }
    }
}
