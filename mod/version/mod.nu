use std log

const VERSION_MODULE_VERSION = "0.4.7"

#
# Get latest release version from GitHub repository
#
export def "fetch-latest" [
    repo_url: string    # Repository URL (e.g., "https://github.com/nushell/nushell")
]: any -> string {
    log info $"Fetching latest version from ($repo_url)..."

    try {
        let all_tags = (
            ^git ls-remote --tags --sort=-v:refname $repo_url
            | lines
            | where { |line| $line =~ 'refs/tags/' and not ($line =~ '\^{}$') }
        )

        if ($all_tags | is-empty) {
            log warning "No git tags found"
            return ""
        }

        # Get first (most recent) tag
        let tag_line = ($all_tags | first)

        # Extract version from tag reference
        # Example: "abc123def456  refs/tags/v0.108.1" → "0.108.1"
        let version = (
            $tag_line
            | str replace --regex '.*refs/tags/v?' ''
            | str trim
        )

        if ($version | is-empty) {
            log warning "Could not extract version from git tags"
            return ""
        }

        log info $"Latest version: ($version)"
        $version
    } catch {
        log warning $"Failed to fetch version from ($repo_url)"
        ""
    }
}

#
# Get cached version from file
#
export def "get-cached" [
    cache_file: path # Path to cache file
]: any -> string {
    if ($cache_file | path exists) {
        try { open $cache_file | str trim } catch { "" }
    } else {
        ""
    }
}

#
# Save version to cache file
#
export def "save-cached" [
    version: string     # Version string to cache
    cache_file: path # Path to cache file
]: any -> nothing {
    let cache_dir = ($cache_file | path dirname)
    if not ($cache_dir | path exists) {
        try { mkdir $cache_dir }
    }

    try { $version | save --force $cache_file }

    log info $"Cached version: ($version) in ($cache_file)"
}

#
# Check current version of a repository
# Returns the latest version string, or empty string on error
#
export def "check-version" [
    repo_url: string    # Repository URL
]: any -> string {
    fetch-latest $repo_url
}

#
# Check if update is available (upstream version differs from cached)
# Returns: {update_available: bool, upstream: string, cached: string}
#
export def "check-update" [
    repo_url: string    # Repository URL
    cache_file: string  # Path to cache file
]: any -> record {
    let cached = (get-cached $cache_file)
    let upstream = (fetch-latest $repo_url)

    let update_available = (
        $upstream != "" and $upstream != $cached
    )

    {
        update_available: $update_available
        upstream: $upstream
        cached: $cached
    }
}

#
# Get version from container image environment variable
#
export def "get-from-image" [
    image_tag: string   # Image tag (e.g., "localhost/mcp-nushell:latest")
    env_var: string     # Environment variable name
]: any -> string {
    let exists = (^podman image exists $image_tag | complete | get exit_code) == 0
    if not $exists {
        return ""
    }

    try {
        let result = (
            ^podman run --rm --entrypoint "/bin/sh" $image_tag -c $"printenv ($env_var)"
            | str trim
        )

        if ($result | is-empty) {
            ""
        } else {
            $result
        }
    } catch {
        log warning $"Could not get version from image ($image_tag)"
        ""
    }
}

#
# Check if image update is available (upstream version differs from image version)
# Returns: {update_available: bool, upstream: string, image: string}
#
export def "check-image-update" [
    repo_url: string    # Repository URL
    image_tag: string   # Image tag to check
    env_var: string     # Environment variable name in image
]: any -> record {
    let image_version = (get-from-image $image_tag $env_var)
    let upstream = (fetch-latest $repo_url)

    let update_available = (
        $upstream != "" and $upstream != $image_version
    )

    {
        update_available: $update_available
        upstream: $upstream
        image: $image_version
    }
}

# Evaluate if an image build is required based on version checks
# Returns: {should_build: bool, version: any, reason: string}
export def "evaluate-build-requirement" [
    version_check: any
    image_tag: string
    force_rebuild: bool
]: any -> record<should_build: bool, version: any, reason: string> {
    if ($version_check | is-empty) {
        return {should_build: true, version: null, reason: "No version check configured, building by default"}
    }

    let repo = ($version_check | get repo)
    let build_arg = ($version_check | get build_arg)

    let check = (
        check-image-update
            $repo
            $image_tag
            $build_arg
    )

    let should_rebuild = ($force_rebuild or $check.update_available)

    let reason = if $should_rebuild {
        if $check.image != "" and $check.upstream != "" {
            $"Version changed: ($check.image) -> ($check.upstream)"
        } else if $check.image == "" or $check.image == "unknown" {
            "Building for first time"
        } else {
            "Force rebuild requested"
        }
    } else {
        $"Version unchanged \(($check.image)\), skipping rebuild. Use --force-rebuild to rebuild anyway"
    }

    {should_build: $should_rebuild, version: $check.upstream, reason: $reason}
}
