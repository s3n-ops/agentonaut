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

    # Set GEMINI_WORKSPACE for the gemini process
    $env.GEMINI_WORKSPACE = $workspace

    # Build additional workspace arguments
    let additional_args = (
        if ("WORKSPACE_ADDITIONAL" in $env) {
            (
                $env.WORKSPACE_ADDITIONAL
                | split row ":"
                | each {|path| ["--include-directories", $path]}
                | flatten
            )
        } else {
            []
        }
    )

    cd $workspace

    log write $"Executing: gemini ($additional_args | str join ' ')"
    exec gemini ...$additional_args
}
