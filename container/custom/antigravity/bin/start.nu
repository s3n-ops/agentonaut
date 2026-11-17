#!/usr/bin/env nu

use std log

const LOG_FILE = "~/.gemini/start.log"

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

    # Build additional workspace arguments
    let additional_args = (
        if ("WORKSPACE_ADDITIONAL" in $env) {
            (
                $env.WORKSPACE_ADDITIONAL
                | split row ":"
                | each {|path| ["--add-dir", $path]}
                | flatten
            )
        } else {
            []
        }
    )

    # Build CLI arguments
    mut agent_args = []

    if ("AGENT_SKIP_PERMISSIONS" in $env) and ($env.AGENT_SKIP_PERMISSIONS == "true") {
        $agent_args = ($agent_args | append "--dangerously-skip-permissions")
    }

    if ("AGENT_MODEL" in $env) and ($env.AGENT_MODEL | is-not-empty) {
        $agent_args = ($agent_args | append ["--model", $env.AGENT_MODEL])
    }

    if ("AGENT_PROMPT" in $env) and ($env.AGENT_PROMPT | is-not-empty) {
        $agent_args = ($agent_args | append ["-p", $env.AGENT_PROMPT])
    }

    let final_args = ($agent_args | append $additional_args)

    cd $workspace

    log write $"Executing: agy ($final_args | str join ' ')"
    exec agy ...$final_args
}
