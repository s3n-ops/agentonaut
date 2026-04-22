#!/usr/bin/env nu

#
# Script to check Nushell syntax for all *.nu files in bin/ and mod/
#

def main []: any -> any {
    let project_root = (pwd)
    let mod_dir = ($project_root | path join "mod")
    let directories = ["bin" "mod"]
    
    let files = (
        $directories
        | each {|dir| glob ($"($dir)/**/*.nu") }
        | flatten
    )

    if ($files | is-empty) {
        print "No Nushell files found in bin/ or mod/."
        return
    }

    print $"Checking syntax for ( $files | length ) files..."

    let results = (
        $files
        | each {|file|
            let is_module = ($file =~ "/mod/" or ($file | str ends-with "mod.nu"))
            let cmd = if $is_module {
                $"nu-check --as-module '($file)'"
            } else {
                $"nu-check '($file)'"
            }
            
            # Use 'nu -I' to ensure modules are found during check
            let result = (
                ^nu -I $mod_dir -c $cmd | complete
            )
            
            let success = ($result.exit_code == 0 and ($result.stdout | str trim) == "true")

            {
                file: $file
                status: (if $success { "OK" } else { "FAILED" })
                success: $success
                stderr: $result.stderr
            }
        }
    )

    let failed = ($results | where not success)

    if ($failed | is-empty) {
        print "All files passed syntax check."
    } else {
        print "Syntax check failed for the following files:"
        $failed | select file status | print
        
        # Show errors for failed files
        $failed | each {|it|
            print $"\n--- Errors in ($it.file) ---"
            let is_module = ($it.file =~ "/mod/" or ($it.file | str ends-with "mod.nu"))
            let cmd = if $is_module {
                $"nu-check --debug --as-module '($it.file)'"
            } else {
                $"nu-check --debug '($it.file)'"
            }
            ^nu -I $mod_dir -c $cmd
        }
        exit 1
    }
}
