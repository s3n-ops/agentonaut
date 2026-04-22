# Script Module
#
# Naming note: avoid `export def "help"` (single word) in this module.
# Nushell resolves bare `help` calls within the module to the exported function
# instead of the built-in, causing infinite recursion in any function that calls
# `help <cmd>` internally. Two-word names like "help modify" or "help general" are safe.

const SCRIPT_MODULE_VERSION = "0.8.21"
const HIDDEN_NAMESPACES = ["test"]
const MAIN_CMD = "main"

# Shortens a text to the specified number of characters and removes line breaks.
# Ellipsis are appended if text has been omitted.
export def "shorten text" [text: string, max_length: int = 96]: any -> string {
    let text_length = ($text | str length)
    let text_concat = ($text | str replace --all --regex '\n' ' ')
    if $text_length <= $max_length {
        $text_concat
    } else {
        $"($text_concat | str substring 0..<($max_length - 4) | str trim --right) ..."
    }
}

# Cleans a description by taking only the first line and removing example tags.
export def "clean description" []: string -> string {
    if ($in | is-empty) { return "" }

    $in
    | lines
    | where not ($it =~ "^#?\\s*@example")
    | where not ($it =~ "^#?\\s*Example:")
    | first
    | default ""
    | str trim
}

# Returns all first-level command namespaces: names that have at least two subcommands
# but no direct definition (i.e. are not leaf commands themselves).
export def "get namespaces" []: nothing -> list<string> {
    let defined = (scope commands | where name starts-with $"($MAIN_CMD) " | get name)
    $defined
    | each {|name| $name | split row " " | get 1 }
    | uniq
    | where {|ns|
        let subs = ($defined | where {|n| $n starts-with $"($MAIN_CMD) ($ns) " })
        let is_leaf = ($MAIN_CMD + " " + $ns) in $defined
        (not $is_leaf) and (($subs | length) >= 2)
    }
}

# Replace the Usage block in Nushell help text.
def "help modify usage" [new_usage: string]: string -> string {
    let regex = '(?s)((?:\x1b\[\d+(?:;\d+)*m)*Usage(?:\x1b\[\d+(?:;\d+)*m)*:\r?\n).*?(?=\r?\n\r?\n(?:\x1b\[\d+(?:;\d+)*m)*[A-Z]|\z)'
    $in | str replace --regex $regex $"${1}($new_usage)"
}

# Replace the Subcommands block in Nushell help text.
def "help modify subcommands" [new_subcommands: string]: string -> string {
    let regex = '(?s)((?:\x1b\[\d+(?:;\d+)*m)*Subcommands(?:\x1b\[\d+(?:;\d+)*m)*:\r?\n).*?(?=\r?\n\r?\n(?:\x1b\[\d+(?:;\d+)*m)*[A-Z]|\z)'
    $in | str replace --regex $regex $"${1}($new_subcommands)"
}

# Format a single subcommand line with a colored command name.
def "format subcommand line" [cmd: record, app_name: string, indent: string = "  "]: nothing -> string {
    let display = ($cmd.name | str replace --all --regex '\bmain\b' $app_name)
    let desc = ($cmd.description | clean description)
    let colored_name = $"($indent)(ansi cyan)($display)(ansi reset)"
    if ($desc | is-empty) {
        $colored_name
    } else {
        $"($colored_name) - ($desc)"
    }
}

# Build a formatted subcommand block.
# Without namespace: groups commands by namespace with colored headers.
# With namespace: returns a flat colored list for namespace-level help.
def "build subcommands" [app_name: string, namespace: string = ""]: nothing -> string {
    let cmd_prefix = if ($namespace | is-empty) { $MAIN_CMD } else { $"($MAIN_CMD) ($namespace)" }
    let namespaces = (get namespaces)

    let all_cmds = (
        scope commands
        | where name starts-with $"($cmd_prefix) "
        | where {|cmd|
            let first_word = ($cmd.name | split row " " | get 1)
            not ($first_word in $HIDDEN_NAMESPACES)
        }
        | select name description
    )

    if ($namespace | is-not-empty) {
        $all_cmds
        | each {|cmd| format subcommand line $cmd $app_name }
        | sort
        | str join "\n"
    } else {
        let leaf_lines = (
            $all_cmds
            | where {|cmd|
                let parts = ($cmd.name | split row " ")
                (($parts | length) == 2) or (not (($parts | get 1) in $namespaces))
            }
            | each {|cmd| format subcommand line $cmd $app_name }
            | sort
        )

        let ns_group_lines = (
            $namespaces
            | sort
            | each {|ns|
                let ns_cmds = (
                    $all_cmds
                    | where name starts-with $"($MAIN_CMD) ($ns) "
                    | each {|cmd| format subcommand line $cmd $app_name "    " }
                    | sort
                )
                if ($ns_cmds | is-not-empty) {
                    let header = $"  (ansi green)($ns | str capitalize)(ansi reset):"
                    [$header ...$ns_cmds] | str join "\n"
                } else {
                    ""
                }
            }
            | where {|it| $it | is-not-empty }
            | str join "\n\n"
        )

        let has_leaves = ($leaf_lines | is-not-empty)
        let has_groups = ($ns_group_lines | is-not-empty)
        let leaf_text = ($leaf_lines | str join "\n")

        if $has_leaves and $has_groups {
            $"($leaf_text)\n\n($ns_group_lines)"
        } else if $has_leaves {
            $leaf_text
        } else {
            $ns_group_lines
        }
    }
}

# Display top-level app help.
# Takes Nushell's built-in help output and replaces Usage and Subcommands blocks.
# Subcommands are sourced from scope to avoid Nushell's duplication bug.
export def "help general" [app_name: string]: nothing -> nothing {
    let new_usage = $"  > ($app_name) {flags} [command]"
    let new_subs = (build subcommands $app_name)
    help $MAIN_CMD
    | str replace --all --regex '\bmain\b' $app_name
    | str replace --all $"($app_name).nu" $app_name
    | help modify usage $new_usage
    | help modify subcommands $new_subs
    | print --raw
}

# Display help for a command namespace by listing its subcommands.
# Falls back to general help if the namespace has no subcommands.
export def "help namespace" [namespace: string, app_name: string]: nothing -> nothing {
    let subs = (build subcommands $app_name $namespace)
    if ($subs | is-empty) {
        help general $app_name
        return
    }
    [$"(ansi green)Subcommands:(ansi reset)" $subs ""]
    | str join "\n"
    | print --raw
}


# Require the current process to run with elevated privileges.
export def "require admin" []: any -> nothing {
    if (not (is-admin)) {
        error make {
            msg: "This command requires elevated privileges."
            label: {text: "called here", span: (metadata $in).span}
        }
    }
}

# Helper: Set value at nested path in record (recursively)
export def "set-nested-path" [record: record, path_parts: list<any>, value: any]: any -> any {
    if ($path_parts | is-empty) {
        return $value
    }

    let first_key = ($path_parts | first)
    let remaining = ($path_parts | skip 1)

    let current_value = ($record | get --optional $first_key | default {})

    if ($remaining | is-empty) {
        $record | upsert $first_key $value
    } else {
        let updated_value = (set-nested-path $current_value $remaining $value)
        $record | upsert $first_key $updated_value
    }
}

# Allow environment variable to override configuration value
# Usage: env override "myapp" "section.key"
# Looks for: MYAPP_SECTION_KEY in environment
# Updates: $env.myapp.section.key
export def --env "env override" [app_name: string, config_path: string]: any -> nothing {
    let app_name_upper = ($app_name | str upcase)
    let config_path_upper = ($config_path | str upcase | str replace --all "." "_")
    let env_var_name = $"($app_name_upper)_($config_path_upper)"

    if not ($env_var_name in $env) { return }

    let env_value = ($env | get --optional $env_var_name)
    let app_namespace = ($app_name | str downcase)
    let current_config = ($env | get --optional $app_namespace | default {})
    let path_parts = ($config_path | split row '.')
    let updated_config = (set-nested-path $current_config $path_parts $env_value)

    {($app_namespace): $updated_config} | load-env
}
