#!/usr/bin/env nu

# nu-lint-project.nu: runs nu-lint (report) and nu-lint --fix on the project.
#
# Why a temp dir is needed
#
# nu-lint cannot resolve cross-file module imports when run directly on the
# project root, because the source structure (bin/ and mod/) differs from
# what nu-lint expects. This script copies files into a flattened temporary
# directory before linting.
#
# Temp dir layout
#
#   lint/   Flattened copy: all *.nu files from bin/ and all modules from mod/
#           are placed side-by-side. nu-lint reads this structure and writes
#           a report. No source files are modified.
#
#   fix/    Preserved copy: bin/ and mod/ are copied as-is. nu-lint --fix
#           rewrites files in-place here with auto-corrections applied.
#           Layout: fix/bin/ and fix/mod/ mirror the project root.
#
# Output after each run
#
#   nu-lint/nu-lint-report-<timestamp>.txt
#       Lists errors, warnings, and hints with line references.
#       Line references point into the temp lint/ dir, not the project root.
#
#   <temp_dir>/fix/
#       Contains the auto-corrected copies. Compare against the project root
#       to review what nu-lint changed. Run `main bcompare` to open the diff
#       in Beyond Compare.
#
#   The temp dir is not deleted automatically. Its path is printed at the end
#   of each run. Each run creates a new timestamped temp dir.
#
# How to use the output
#
# 1. Read the report in nu-lint/ to identify issues by category and file.
# 2. Read the fixed copies in fix/bin/ and fix/mod/ to see the suggested
#    changes side-by-side with the originals.
# 3. Apply changes selectively to the project source files.
#    Do not copy fix/ back wholesale: review each change before applying.

# Main entry point: runs lint and fix sequentially
def main [] {
    let iso_date = (date now | format date "%Y-%m-%dT%H-%M-%S")
    let temp_dir = (prepare-temp $iso_date)
    run-lint $temp_dir $iso_date
    run-fix $temp_dir
    print $"\n(ansi green)Process complete.(ansi reset)"
    print $"Temporary directory: (ansi cyan)($temp_dir)(ansi reset)"
}

# Helper to prepare the temporary directory structure
def prepare-temp [iso_date: string]: any -> any {
    let temp_dir = (mktemp --directory --tmpdir $"nu-lint-($iso_date)-XXXXX" | path expand)

    copy-to-lint $temp_dir
    copy-to-fix $temp_dir

    $temp_dir
}

# Flattened structure for nu-lint resolution
def copy-to-lint [temp_dir: string] {
    let project_root = (pwd)
    let lint_path = ($temp_dir | path join "lint")
    mkdir $lint_path

    # Copy all *.nu files from bin/
    glob ($project_root | path join "bin/*.nu") | each {|f| cp $f $lint_path }

    # Copy all modules from mod/
    let modules = (ls ($project_root | path join "mod") | where type == "dir")
    for $m in $modules {
        cp --recursive $m.name $lint_path
    }

    # Copy *.nu files directly from mod/
    glob ($project_root | path join "mod/*.nu") | each {|f| cp $f $lint_path }
}

# Original structure for easy comparison and fixing
def copy-to-fix [temp_dir: string] {
    let project_root = (pwd)
    let fix_path = ($temp_dir | path join "fix")
    mkdir $fix_path

    # Copy entire bin and mod directories to preserve structure
    cp --recursive ($project_root | path join "bin") $fix_path
    cp --recursive ($project_root | path join "mod") $fix_path
}

# Internal helper to run linting (captures output to file only)
def run-lint [temp_dir: string, iso_date: string] {
    let project_root = (pwd)
    let output_dir = ($project_root | path join "nu-lint")
    let config_file = ($project_root | path join "conf" "nu-lint.toml")
    let lint_path = ($temp_dir | path join "lint")
    
    let report_name = $"nu-lint-report-($iso_date).txt"
    let report_file = ($output_dir | path join $report_name)

    if not ($output_dir | path exists) { mkdir $output_dir }

    print $"Linting (ansi cyan)($lint_path)(ansi reset)..."

    try {
        let result = (do { nu-lint --config $config_file $lint_path } | complete)
        let output = ($"($result.stdout)\n($result.stderr)")
        $output | save --force $report_file
        print $"(ansi green)Report saved to: (ansi cyan)($report_file)(ansi reset)"
    } catch {|err|
        error make {msg: $"Error during linting process: ($err.msg)"}
    }
}

# Internal helper to run fix (silent in console)
def run-fix [temp_dir: string] {
    let project_root = (pwd)
    let config_file = ($project_root | path join "conf" "nu-lint.toml")
    let fix_path = ($temp_dir | path join "fix")

    print $"Running nu-lint fix on (ansi cyan)($fix_path)(ansi reset)..."

    try {
        # Using --fix flag as per nu-lint --help
        do { nu-lint --fix --config $config_file $fix_path } | complete
        print $"(ansi green)Auto-fix complete.(ansi reset)"
    } catch {|err|
        error make {msg: $"Error during fix process: ($err.msg)"}
    }
}

# Find the latest temporary directory and open Beyond Compare
def "main bcompare" [
    --mode: string = "fix" # Compare with 'lint' or 'fix' subdirectory
] {
    let project_root = (pwd)
    
    # Find newest nu-lint directory in /tmp
    let latest_temp = (
        ls --du /tmp/nu-lint-* 
        | sort-by modified --reverse 
        | first 
        | get name
    )

    if ($latest_temp | is-empty) {
        print --stderr $"(ansi red)Error:(ansi reset) No temporary lint directories found in /tmp."
        return
    }

    let target_path = ($latest_temp | path join $mode)
    
    if not ($target_path | path exists) {
        print --stderr $"(ansi red)Error:(ansi reset) ($target_path) not found in ($latest_temp)."
        return
    }

    print $"Comparing project with latest temp dir: (ansi cyan)($latest_temp)(ansi reset) \(Mode: ($mode)\)"

    # Comparing root directories directly is most efficient for bcompare
    # It will show 'bin' and 'mod' aligned, and others as left-only.
    run_bcompare $project_root $target_path
}

# Helper to execute bcompare (handles container limitation)
def run_bcompare [left: string, right: string] {
    if (which bcompare | is-empty) {
        error make {msg: $"(ansi yellow)Warning:(ansi reset) 'bcompare' not found in container."}
        print $"To compare manually on the host, run:"
        print $"bcompare \"($left)\" \"($right)\""
    } else {
        bcompare $left $right
    }
}
