#!/usr/bin/env nu

# Run the nutest test suite for all testable modules.
# Requires nutest in lib/nutest/ and Nushell 0.105.0+.
#
# Usage:
#   nu bin/run-tests.nu
#   nu bin/run-tests.nu --matcher sanitize
#   nu bin/run-tests.nu --fail

def main [
    --match-tests: string = ".*"  # Filter tests by name (regex)
    --fail                    # Exit with code 1 if any test fails (for CI)
] {
    let project_root = ($env.FILE_PWD | path join ".." | path expand)
    let lib_dirs = (
        [$"($project_root)/mod", $"($project_root)/lib"]
        | str join (char record_sep)
    )

    mut cmd = $"use nutest; nutest run-tests --path ($project_root)/tests --match-tests '($match_tests)' --display table"
    if $fail { $cmd = $"($cmd) --fail" }

    ^$nu.current-exe --include-path $lib_dirs --commands $cmd
}
