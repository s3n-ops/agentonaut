use std/log
const CFG_MODULE_VERSION = "0.8.5"

# Loads TOML config into $env.<app_name>.
# Prioritizes ease of use over module purity by design.
#
# Usage:
#   cfg init "myapp"                   # Loads into $env.myapp
#   cfg init "myapp" "config"          # Loads myapp/config.toml into $env.myapp
#
#   $env.myapp | get section.key          # Direct access
#   $env.myapp.subsection.value           # Nested access with dot notation
#   $env.myapp.path                       # Automatically set to script root

# Load TOML config into $env.<app_name>.cfg and $env.<app_name>.cfg_idx
export def --env init [
    app_name: string
    config_name: string = "config"
    --preprocessor: closure  # Optional: process file content before parsing (e.g., decrypt)
]: any -> nothing {
    let env_name = ($app_name | str downcase)

    # Determine application root path (caller in bin/, so root is ../)
    # Note: $env.FILE_PWD points to the directory containing the script (bin/), not the script file itself.
    let root_path = ($env.FILE_PWD | path dirname)

    let config_file = (locate $app_name $config_name $root_path)

    if ($config_file | is-empty) {
        log debug $"Config file not found, skipping"
        return
    }

    log debug $"Loading config from: ($config_file)"

    let cfg = if ($preprocessor | is-not-empty) {
        try { do $preprocessor $config_file | from toml }
    } else {
        try { open $config_file }
    }

    # Add application root path automatically
    let cfg_with_path = ($cfg | upsert root_path $root_path)

    # Merge with existing config if present, otherwise use new config
    let cfg_proc = if (($env | get --optional $env_name) != null) {
        $env | get $env_name | get cfg | merge deep $cfg_with_path
    } else {
        $cfg_with_path
    }

    # Create both hierarchical and indexed variants
    let env_update = {
        ($env_name): {
            cfg: $cfg_proc,
            cfg_idx: (unfold $cfg_proc)
        }
    }
    $env_update | load-env

    log debug $"Config initialized in \$env.($env_name).cfg and \$env.($env_name).cfg_idx"
    log debug $"Config file: ($config_file)"
    log debug $"App root path set to: ($root_path)"
}

# Resolve config path using XDG priorities (Project > User > System)
def locate [app_name: string, config_name: string, root_path: string]: any -> string {
    let config_dir = if ($env.XDG_CONFIG_HOME? | is-empty) {
        $"($env.HOME)/.config"
    } else {
        $env.XDG_CONFIG_HOME
    }

    # For secrets, check for .sops.toml variant first, then regular .toml
    # Only search in user and system directories (not project dir)
    let config_files = if ($config_name | str starts-with "secrets") {
        [
            $"($config_dir)/($app_name)/($config_name).sops.toml"
            $"/etc/($app_name)/($config_name).sops.toml"
            $"($config_dir)/($app_name)/($config_name).toml"
            $"/etc/($app_name)/($config_name).toml"
        ]
    } else {
        [
            $"($root_path)/conf/($config_name).toml"
            $"($config_dir)/($app_name)/($config_name).toml"
            $"/etc/($app_name)/($config_name).toml"
            $"($root_path)/conf/($config_name).skel.toml"
        ]
    }

    let config_exists = $config_files | path exists

    let found_config = $config_exists
    | enumerate
    | where item
    | first 1

    if ($found_config | is-empty) {
        # For secrets files, return null instead of error
        if ($config_name | str starts-with "secrets") {
            return null
        }
        error make {msg: $"Config not found in: ($config_files | str join ', ')"}
    } else {
        $config_files | get ($found_config | first).index
    }
}

# Reload configuration from disk (invalidate singleton cache)
# Also updates application root path
# Recreates both hierarchical (config) and flat (config_index) variants
export def --env reload [
    app_name: string
    config_name: string = "config"
    --preprocessor: closure  # Optional: process file content before parsing (e.g., decrypt)
]: any -> nothing {

    # Use app_name (lowercase) as namespace
    let env_name = ($app_name | str downcase)

    # Determine application root path
    let root_path = ($env.FILE_PWD | path dirname)

    let config_file = (locate $app_name $config_name $root_path)
    log debug $"Reloading config from: ($config_file)"

    let cfg = if ($preprocessor | is-not-empty) {
        try { do $preprocessor $config_file | from toml }
    } else {
        try { open $config_file }
    }

    # Add application root path automatically
    let cfg_with_path = ($cfg | upsert root_path $root_path)

    # Create both hierarchical and indexed variants
    let env_update = {
        ($env_name): {
            cfg: $cfg_with_path,
            cfg_idx: (unfold $cfg_with_path)
        }
    }
    $env_update | load-env

    log info $"Config reloaded in \$env.($env_name).cfg and \$env.($env_name).cfg_idx"
    log debug $"Config file: ($config_file)"
    log debug $"App root path set to: ($root_path)"
}

# Setup user configuration by copying the skeleton config
export def setup [app_name: string, config_name: string = "config"]: any -> record {
    let root_path = ($env.FILE_PWD | path dirname)
    let skel_path = $"($root_path)/conf/($config_name).skel.toml"
    
    let config_dir = if ($env.XDG_CONFIG_HOME? | is-empty) {
        $"($env.HOME)/.config/($app_name)"
    } else {
        $"($env.XDG_CONFIG_HOME)/($app_name)"
    }
    
    let user_config_path = ($config_dir | path join $"($config_name).toml")

    if not ($config_dir | path exists) {
        try { mkdir $config_dir }
    }

    if not ($user_config_path | path exists) {
        cp $skel_path $user_config_path
        return {created: true, path: $user_config_path}
    } else {
        return {created: false, path: $user_config_path}
    }
}

# Check if key indicates a path value
def "is path-key" [key: string]: any -> bool {
    $key ends-with "_path"
}

# Handle date values during unfold
def "handle date" [value: any, prefix: string] {
    [{key: $prefix, value: ($value | format date "%Y-%m-%d %H:%M:%S")}]
}

# Handle path values during unfold
def "handle path" [value: string, prefix: string]: any -> list<record> {
    [{key: $prefix, value: ($value | path expand)}]
}

# Handle string values during unfold
def "handle string" [value: string, prefix: string]: any -> list<record> {
    if (is path-key $prefix) {
        handle path $value $prefix
    } else {
        [{key: $prefix, value: $value}]
    }
}

# Handle list values during unfold
def "handle list" [value: any, prefix: string]: any -> list<record> {
    if ($value | is-empty) {
        [{key: $prefix, value: []}]
    } else if ($prefix | is-empty) {
        $value | enumerate | each {|item|
            unfold recursive $item.item $item.index
        } | flatten
    } else {
        $value | enumerate | each {|item|
            unfold recursive $item.item $"($prefix).($item.index)"
        } | flatten
    }
}

# Handle record values during unfold
def "handle record" [value: any, prefix: string]: any -> list<record> {
    if ($value | columns | is-empty) {
        []
    } else if ($prefix | is-empty) {
        $value | items {|key, value|
            unfold recursive $value $key
        } | flatten
    } else {
        $value | items {|key, value|
            unfold recursive $value $"($prefix).($key)"
        } | flatten
    }
}

# Recursively unfold nested structures
def "unfold recursive" [value: any, prefix: string = ""]: any -> list<record> {
    let type = ($value | describe --detailed | get type)

    match $type {
        date => (handle date $value $prefix)
        list | table => (handle list $value $prefix)
        record => (handle record $value $prefix)
        null => [{key: $prefix, value: null}]
        string => (handle string $value $prefix)
        # Other scalar values
        _ => [{key: $prefix, value: $value}]
    }
}

# Transform nested records into a flat dot-notation map for fast lookups
# Converts hierarchical config into flat record with keys like "nested.items.0"
# Returns sorted record with all nested values accessible via dot paths
export def unfold [config: record]: any -> record {
    unfold recursive $config ""
    | reduce --fold {} {|item, acc|
        $acc | insert $item.key $item.value
    }
    | sort
}

# Extract config keys by exact match, pattern matching, or regex
# Returns a new record containing only matching keys
# Usage: $config | cfg extract "key.name"                    # exact match (default)
#        $config | cfg extract --starts-with "prefix"        # prefix matching
#        $config | cfg extract --ends-with "suffix"          # suffix matching
#        $config | cfg extract --contains "substring"        # substring matching
#        $config | cfg extract --regex 'pattern'             # regex matching
#        $config | cfg extract --output-separator "_" "key"  # with separator
export def extract [
    ...patterns: string
    --starts-with(-s)
    --ends-with(-e)
    --contains(-c)
    --regex(-r)
    --output-separator(-o): string = "."
]: record -> record {
    let config = $in

    if ($patterns | is-empty) {
        return {}
    }

    # Filter keys by pattern
    let filtered = (
        $config
        | transpose key value
        | where {|it|
            $patterns | any {|pattern|
                if $starts_with {
                    $it.key | str starts-with $pattern
                } else if $ends_with {
                    $it.key | str ends-with $pattern
                } else if $contains {
                    $it.key | str contains $pattern
                } else if $regex {
                    $it.key =~ $pattern
                } else {
                    $it.key == $pattern
                }
            }
        }
    )

    # Replace separator in output keys if not default
    let transformed = if $output_separator != "." {
        $filtered | each {|item|
            {
                key: ($item.key | str replace --all "." $output_separator)
                value: $item.value
            }
        }
    } else {
        $filtered
    }

    $transformed
    | reduce --fold {} {|item, acc|
        $acc | insert $item.key $item.value
    }
}

# Extract config subtree by field value (single match)
# Finds first array element where field matches value and returns all sibling fields
# For multiple matches, use 'cfg extract query' instead
# Usage: $config | cfg extract by id "claude"                              # → record (single)
#        $config | cfg extract by --starts-with container_name "mcp-"      # prefix matching
#        $config | cfg extract by --ends-with image_tag ":latest"          # suffix matching
#        $config | cfg extract by --contains description "MCP"             # substring matching
#        $config | cfg extract by --regex id '^claude.*'                   # regex matching
#        $config | cfg extract by --scope "container.profile" id "gemini"  # scope to specific section
#        $config | cfg extract by --output-separator "_" id "claude"       # with separator
export def "extract by" [
    field: string
    value: string
    --starts-with(-s)
    --ends-with(-e)
    --contains(-c)
    --regex(-r)
    --scope: string
    --output-separator(-o): string = "."
]: record -> record {
    let config = $in

    # Use extract query and take first match
    let results = (
        $config
        | extract query $field $value
            --starts-with=$starts_with
            --ends-with=$ends_with
            --contains=$contains
            --regex=$regex
            --scope=$scope
            --output-separator=$output_separator
    )

    if ($results | is-empty) {
        error make {
            msg: $"No entry found where ($field) = ($value)"
        }
    }

    $results | first
}

# Extract all config subtrees matching field value (multi-match)
# Finds all array elements where field matches value and returns all sibling fields
# Always returns a list, even if empty or single match
# Usage: $config | cfg extract query origin "local"                           # → list<record> (all matches)
#        $config | cfg extract query --scope "container.profile" origin "local" # → list<record> (scoped)
#        $config | cfg extract query --starts-with container_name "mcp-"      # prefix matching
#        $config | cfg extract query --ends-with image_tag ":latest"          # suffix matching
#        $config | cfg extract query --contains description "MCP"             # substring matching
#        $config | cfg extract query --regex id '^claude.*'                   # regex matching
export def "extract query" [
    field: string
    value: string
    --starts-with(-s)
    --ends-with(-e)
    --contains(-c)
    --regex(-r)
    --scope: string
    --output-separator(-o): string = "."
]: record -> list<record> {
    let config = $in

    # Filter by scope if provided
    let scoped_config = if ($scope | is-not-empty) {
        $config
        | transpose key value
        | where {|it| $it.key | str starts-with $"($scope)."}
        | reduce --fold {} {|item, acc|
            $acc | insert $item.key $item.value
        }
    } else {
        $config
    }

    # Find ALL keys that end with .field and have matching value
    let matching_keys = (
        $scoped_config
        | transpose key value
        | where ($it.key | str ends-with $".($field)") and (
                if $starts_with {
                    $it.value | str starts-with $value
                } else if $ends_with {
                    $it.value | str ends-with $value
                } else if $contains {
                    $it.value | str contains $value
                } else if $regex {
                    $it.value =~ $value
                } else {
                    $it.value == $value
                }
            )
    )

    # For each matching key, extract all siblings
    $matching_keys | each {|match|
        # Extract prefix (everything before the last dot)
        let prefix = ($match.key | split row "." | drop | str join ".")

        # Extract all keys with this prefix
        let siblings = (
            $scoped_config
            | transpose key value
            | where {|it| $it.key | str starts-with $"($prefix)."}
        )

        # Build result record with cleaned keys (remove prefix and apply separator)
        let cleaned = (
            $siblings
            | each {|item|
                {
                    key: ($item.key | str replace $"($prefix)." "")
                    value: $item.value
                }
            }
        )

        # Replace separator in output keys if not default
        let transformed = if $output_separator != "." {
            $cleaned | each {|item|
                {
                    key: ($item.key | str replace --all "." $output_separator)
                    value: $item.value
                }
            }
        } else {
            $cleaned
        }

        $transformed
        | reduce --fold {} {|item, acc|
            $acc | insert $item.key $item.value
        }
    }
}

# Extract nested profile by section and name
# Designed for nested tables pattern: profile.agent.claude, profile.container.claude
# Strips the section.name prefix from keys, returning only field names
# Usage: $config | cfg extract nested "profile.agent" "claude"
#        $config | cfg extract nested "profile.container" "claude"
export def "extract nested" [
    section: string   # e.g., "profile.agent"
    name: string      # e.g., "claude"
    --output-separator(-o): string = "."
]: record -> record {
    let config = $in
    let prefix = $"($section).($name)."

    # Extract all keys starting with prefix
    let matched = (
        $config
        | extract --starts-with $prefix
    )

    # Remove prefix from keys
    $matched
    | items {|key, value|
        {
            key: ($key | str replace $prefix "")
            value: $value
        }
    }
    | reduce --fold {} {|item, acc|
        $acc | insert $item.key $item.value
    }
}
