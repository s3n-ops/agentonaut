# String and Path Utilities
const UTIL_MODULE_VERSION = "0.2.5"

# Create a filesystem-safe directory name from an arbitrary path
# Converts: /workspace/my-path
# To: workspace-my-path
#
# Rules:
# - Removes leading slash
# - Keeps only: a-z, A-Z, 0-9, dash (-), underscore (_), dot (.)
# - Replaces all other characters with dash (-)
# - Collapses multiple consecutive dashes to single dash
# - Trims leading/trailing dashes
#
# This provides a stable, filesystem-safe alternative to systemd-escape
# without special escape sequences that can cause issues.
export def "sanitize path" []: any -> string {
    str replace --regex '^/' ''
    | str replace --regex '[^a-zA-Z0-9._-]' '-' --all
    | str replace --regex '-+' '-' --all
    | str trim --char '-'
}

# Sanitize app name to valid identifier (lowercase alphanumeric and underscores)
export def "sanitize name" []: any -> string {
    str downcase
    | str replace --all --regex '[^a-z0-9_]' '_'
}

# Determine host timezone name (e.g., Europe/Berlin)
# Falls:
# 1. /etc/timezone exists, use its content
# 2. /etc/localtime is a symlink, extract from it
# 3. Default to UTC
export def "get-host-timezone" []: nothing -> string {
    if ("/etc/timezone" | path exists) {
        return (open --raw "/etc/timezone" | str trim)
    }

    # Extract from symlink (e.g., /etc/localtime -> /usr/share/zoneinfo/Europe/Berlin)
    let localtime = (ls -l /etc/localtime | get 0.target? | default "")
    if ($localtime | str contains "/zoneinfo/") {
        return ($localtime | str replace --regex '.*zoneinfo/' '')
    }

    "UTC"
}
