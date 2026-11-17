#!/usr/bin/env nu

use std log

const LOG_FILE = "~/.opencode/start.log"

#
# Write log message to file with ISO timestamp
#
def "log write" [
    message: string  # Log message
] {
    let log_path = ($LOG_FILE | path expand)
    let timestamp = (date now | format date "%Y-%m-%dT%H:%M:%S")
    let log_line = $"($timestamp) ($message)\n"

    $log_line | save --append $log_path
}

# Main entry point - automatically executed when script runs
def main [] {
    # Determine workspace from WORKSPACE (generic) or PWD
    let workspace = (
        if ("WORKSPACE" in $env) {
            $env.WORKSPACE
        } else {
            $env.PWD
        }
    )

    # OpenCode has no equivalent to --add-dir
    if ("WORKSPACE_ADDITIONAL" in $env) {
        log write $"Ignoring additional workspaces, not supported by opencode: ($env.WORKSPACE_ADDITIONAL)"
    }

    # A private server per session instead of the shared background service,
    # so the server ends with the session and sees this process's environment.
    mut agent_args = ["--standalone"]

    if ("AGENT_SKIP_PERMISSIONS" in $env) and ($env.AGENT_SKIP_PERMISSIONS == "true") {
        $agent_args = ($agent_args | append "--auto")
    }

    # The TUI has no --model flag. Inline config is merged over opencode.json.
    if ("AGENT_MODEL" in $env) and ($env.AGENT_MODEL | is-not-empty) {
        $env.OPENCODE_CONFIG_CONTENT = ({ model: $env.AGENT_MODEL } | to json --raw)
    }

    if ("AGENT_PROMPT" in $env) and ($env.AGENT_PROMPT | is-not-empty) {
        $agent_args = ($agent_args | append ["--prompt", $env.AGENT_PROMPT])
    }

    cd $workspace

    log write $"Executing: opencode ($agent_args | str join ' ')"
    exec opencode ...$agent_args
}
