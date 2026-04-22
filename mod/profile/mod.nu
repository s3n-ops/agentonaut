use std log
const PROFILE_MODULE_VERSION = "0.3.6"

# Profile management for nested TOML structures
#
# Converts nested TOML tables to flat lists for profile management
#
# Config format:
#   [profile.agent.claude]
#   description = "Claude AI agent"
#
#   [profile.container.gemini]
#   description = "Gemini container"
#
# Convert to list:
#   $env.myapp.cfg.profile | profile convert-to-list
#   → [{id: "claude", type: "agent", ...}, {id: "gemini", type: "container", ...}]
#
# Fetch with type safety:
#   profile fetch "gemini" $all_profiles "container"
#

#
# Nested Tables Functions
#

# Flatten nested [profile.type.name] structures into a list of records with ID and Type
# Examples:
#   $env.myapp.cfg.profile | convert-to-list
#   → Converts {container: {gemini: {...}}} to [{id: "gemini", type: "container", ...}]
export def "convert-to-list" []: record -> list {
    items {|type, items|
        $items
        | items {|name, fields|
            $fields
            | insert id $name
            | insert type $type
        }
    }
    | flatten
}

# Get profile by type and name from nested tables structure
# Examples:
#   $env.myapp.cfg.profile | get-nested "btrfs" "home"
export def "get-nested" [
    profile_type: string
    profile_name: string
]: record -> record {
    let profiles = $in
    let type_profiles = ($profiles | get --optional $profile_type)

    if ($type_profiles | is-empty) {
        error make {
            msg: $"Profile type not found: ($profile_type)"
        }
    }

    let profile = ($type_profiles | get --optional $profile_name)

    if ($profile | is-empty) {
        error make {
            msg: $"Profile not found: ($profile_type).($profile_name)"
        }
    }

    $profile
    | insert id $profile_name
    | insert type $profile_type
}

# List all profile names for a specific type from nested tables
# Examples:
#   $env.myapp.cfg.profile | list-names "btrfs"
#   → ["home", "var", "root"]
export def "list-names" [
    profile_type: string
]: record -> list<string> {
    let profiles = $in
    let type_profiles = ($profiles | get --optional $profile_type)

    if ($type_profiles | is-empty) {
        return []
    }

    $type_profiles
    | transpose name fields
    | get name
    | sort
}

# List all profile types from nested tables
# Examples:
#   $env.myapp.cfg.profile | list-types
#   → ["btrfs", "lvm"]
export def "list-types" []: record -> list<string> {
    transpose type items
    | get type
    | sort
}

# Get all profiles of a specific type as a list of records
# Examples:
#   $env.myapp.cfg.profile | list-by-type "container"
#   → [{id: "gemini", type: "container", ...}]
export def "list-by-type" [
    profile_type: string
]: record -> list<record> {
    let profiles = $in
    let type_profiles = ($profiles | get --optional $profile_type)

    if ($type_profiles | is-empty) {
        return []
    }

    $type_profiles
    | items {|id, fields|
        $fields
        | insert id $id
        | insert type $profile_type
    }

}

# Fetch single profile by ID
# Examples:
#   fetch "claude" $profiles "agent" -> finds {id: "claude", type: "agent", ...}
#   fetch "gemini" $profiles "container" -> finds {id: "gemini", type: "container", ...}
export def fetch [
    profile_id: string
    profiles: list
    profile_type?: string  # Optional type filter (REQUIRED if ID exists in multiple types)
]: any -> record {
    # Filter by type first if provided, then by ID
    let filtered = if ($profile_type | is-not-empty) {
        $profiles | where type == $profile_type and id == $profile_id
    } else {
        $profiles | where id == $profile_id
    }

    if ($filtered | is-empty) {
        if ($profile_type | is-not-empty) {
            error make {
                msg: $"Profile not found: ($profile_id) of type ($profile_type)"
            }
        } else {
            error make {
                msg: $"Profile not found: ($profile_id)"
            }
        }
    }

    $filtered | first
}

# Filter profiles by type
# Examples:
#   $profiles | filter-by-type "agent"
#   $profiles | filter-by-type "container"
export def "filter-by-type" [
    profile_type: string
]: list -> list {
    where type == $profile_type
}

# Query profiles matching field value
export def query [field: string, value: string, profiles: list]: any -> list {
    $profiles | where ($it | get $field) == $value
}

# Query profiles that have a repo
export def "query with-repo" [profiles: list]: any -> list {
    $profiles | where {|it| "repo" in $it }
}

# Extract specified fields from a profile into a new record
export def extract [profile: record, ...fields: string]: any -> record {
    $fields | reduce --fold {} {|field, acc|
        let value = ($profile | get --optional $field | default null)
        $acc | insert $field $value
    }
}

# Fetch multiple profiles by ID and return as record keyed by ID
export def "fetch multiple" [profile_ids: list, profiles: list]: any -> record {
    $profile_ids | reduce --fold {} {|id, acc|
        $acc | insert $id (fetch $id $profiles)
    }
}

# Display all profiles in a formatted table
# Optionally specify which columns to display
# Examples:
#   list $profiles -> displays all fields
#   list $profiles --columns [id type] -> displays only id and type columns
export def list [
    profiles: list
    --columns: list = []  # Optional: specific columns to display
]: any -> nothing {
    if ($profiles | is-empty) {
        print "No profiles configured"
        return
    }

    let output = if ($columns | is-empty) {
        $profiles
    } else {
        $profiles | select ...$columns
    }

    print ($output | table)
}


# Print available container profiles in a formatted list
# Example: $env.myapp.cfg.profile | profile print-container-profiles
export def "print-container-profiles" [
    --hint: string = "Run: agentonaut image build <profile_name>"  # Hint shown below the profile list
]: record -> nothing {
    log info "Available container profiles:"
    let all_containers = ($in | list-by-type "container")
    [
        ""
        ($all_containers | select id description | table)
        $hint
    ] | print --raw
}
