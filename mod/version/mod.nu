use std/log

const VERSION_MODULE_VERSION = "0.5.2"

#
# Select the most recent version from git ls-remote tag lines
# Lines must be sorted newest first. tag_pattern, when set, restricts the
# candidates to matching tag names, e.g. '^v2\.\d+\.\d+$' skips tags of
# other components in a monorepo.
# Example: "abc123def456  refs/tags/v0.108.1" -> "0.108.1"
#
export def "select-latest-tag" [
    tag_pattern?: string  # Regex matched against the tag name (optional)
]: list<string> -> string {
    let tags = (
        $in
        | where { |line| $line =~ 'refs/tags/' and not ($line =~ '\^{}$') }
        | each { |line| $line | str replace --regex '.*refs/tags/' '' | str trim }
        | where { |tag| ($tag_pattern | is-empty) or ($tag =~ $tag_pattern) }
    )

    if ($tags | is-empty) {
        return ""
    }

    $tags | first | str replace --regex '^v(\d)' '$1'
}

#
# Get latest release version from GitHub repository
#
export def "fetch-latest" [
    repo_url: string      # Repository URL (e.g., "https://github.com/nushell/nushell")
    tag_pattern?: string  # Regex the tag name must match (optional)
]: any -> string {
    log info $"Fetching latest version from ($repo_url)..."

    try {
        let version = (
            ^git ls-remote --tags --sort=-v:refname $repo_url
            | lines
            | select-latest-tag $tag_pattern
        )

        if ($version | is-empty) {
            log warning "No matching git tags found"
            return ""
        }

        log info $"Latest version: ($version)"
        $version
    } catch {
        log warning $"Failed to fetch version from ($repo_url)"
        ""
    }
}
