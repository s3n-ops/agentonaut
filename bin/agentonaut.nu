#!/usr/bin/env nu

use std/log

use cfg
use script
use util
use podman
use profile
use git
use version
use mcp

const AGENTONAUT_VERSION = "0.39.8"

# Initialize configuration (singleton - loads once)
cfg init "agentonaut"

# Optional: Allow environment variable overrides
# Examples:
#   AGENTONAUT_CHAT_BASE_PATH=~/MyChat agentonaut chat
#   AGENTONAUT_PODMAN_NETWORK=my-net agentonaut container ps
# script-env-var "agentonaut" "chat.base_path"
# script-env-var "agentonaut" "agentonaut.podman.network"

# List active pods and containers for a quick overview
def "main container ps" []: nothing -> nothing {
    log info "Podman pods:"
    let pods = (^podman pod ps | complete)
    if $pods.exit_code != 0 { 
        log error $"Failed to list pods: ($pods.stderr)" 
    } else { 
        $pods.stdout | print 
    }

    log info "Podman containers:"
    let containers = (^podman ps | complete)
    if $containers.exit_code != 0 { 
        log error $"Failed to list containers: ($containers.stderr)" 
    } else { 
        $containers.stdout | print 
    }
}

# Stop a container or pod
@example "agentonaut container stop gemini-pod" { agentonaut container stop gemini-pod }
@example "agentonaut container stop gemini" { agentonaut container stop gemini }
def "main container stop" [
    name: string  # Container or pod name
]: nothing -> nothing {
    let is_pod = (podman pod exists $name)

    if $is_pod {
        podman pod stop $name
    } else {
        podman stop $name
    }
}

# List all pods
@example "agentonaut pod ps" { agentonaut pod ps }
def "main pod ps" []: nothing -> string {
    log info "Podman pods:"
    let result = (podman pod ps)
    if ($result | is-empty) {
        log warning "No pods found or failed to list pods."
        return ""
    }
    $result
}

# Stop a pod
@example "agentonaut pod stop claude-pod" { agentonaut pod stop claude-pod }
def "main pod stop" [
    pod_name: string  # Pod name
]: nothing -> nothing {
    podman pod stop $pod_name | ignore
}

# Remove a pod (stops and removes all containers first)
@example "agentonaut pod rm claude-pod" { agentonaut pod rm claude-pod }
def "main pod rm" [
    pod_name: string  # Pod name
]: nothing -> nothing {
    log info $"Removing pod: ($pod_name)"

    # Stop the pod first (stops all containers in it)
    let stop_result = (podman pod stop $pod_name)
    if $stop_result != 0 {
        log warning $"Failed to stop pod: ($pod_name)"
    }

    # Remove the pod
    let rm_result = (podman pod rm $pod_name)
    if $rm_result != 0 {
        log error $"Failed to remove pod: ($pod_name)"
    }
}

# Download a single upstream container profile by ID, or list available profiles
@example "agentonaut git download claude-contrib" { agentonaut git download claude-contrib }
@example "agentonaut git download" { agentonaut git download }
def "main git download" [
    profile_name?: string    # Profile to download. Omit to list available profiles.
]: nothing -> nothing {
    let upstream_profiles = (
        $env.agentonaut.cfg.profile
        | profile list-by-type "container"
        | where origin == "upstream"
    )

    if ($profile_name | is-empty) {
        log info "Available upstream container profiles:"
        [
            ""
            ($upstream_profiles | select id repo description | table)
            "Run: agentonaut git download <profile_name>"
        ] | print --raw
        return
    }

    let profile = ($upstream_profiles | where id == $profile_name | first)

    if ($profile | is-empty) {
        error make { msg: $"Profile not found or not upstream: ($profile_name)" }
    }

    let repo_dir = if $profile.containerfile =~ "/" {
        $profile.containerfile | path dirname
    } else {
        "."
    }

    let repo_branch = ($profile.repo_branch? | default "main")

    let local_path = ($env.agentonaut.cfg.root_path | path join $profile.local_dir)
    git download dir $profile.repo $repo_dir $repo_branch $local_path
}

# Download container profiles filtered by field
@example "agentonaut git download by origin upstream" { agentonaut git download by origin upstream }
@example "agentonaut git download by origin local" { agentonaut git download by origin local }
def "main git download by" [
    field?: string    # Filter field name (e.g., "origin")
    value?: string    # Filter value (e.g., "upstream")
]: nothing -> nothing {
    let container_profiles = ($env.agentonaut.cfg.profile | profile list-by-type "container")

    if ($field | is-empty) {
        [
            ""
            ($container_profiles | select id origin | sort-by origin | table)
            "Run: agentonaut git download by <field> <value>"
        ] | print --raw
        return
    }

    if ($value | is-empty) {
        let values = ($container_profiles | get --optional $field | compact | uniq | sort)
        print $"Available values for ($field): ($values | str join ', ')"
        return
    }

    log info $"Downloading container profiles where ($field) = ($value)..."

    let selected = (profile query $field $value $container_profiles)
    let profiles = ($selected | where ($it | get --optional repo | default "") != "")

    if ($profiles | is-empty) {
        log warning $"No container profiles found where ($field) = ($value)"
        return
    }

    log info $"Found ($profiles | length) profiles to download"

    $profiles | each {|p|
        log info $"Downloading: ($p.id)"

        let repo_dir = if $p.containerfile =~ "/" {
            $p.containerfile | path dirname
        } else {
            "."
        }

        let repo_branch = $p.repo_branch? | default "main"

        let local_path = ($env.agentonaut.cfg.root_path | path join $p.local_dir)
        git download dir $p.repo $repo_dir $repo_branch $local_path
    }

    log info "All profiles downloaded successfully"
}

# Download all upstream container profiles
@example "agentonaut git download all" { agentonaut git download all }
def "main git download all" []: nothing -> nothing {
    let root_path = $env.agentonaut.cfg.root_path
    let container_profiles = (
        $env.agentonaut.cfg.profile
        | profile list-by-type "container"
        | each { |p| $p | upsert local_dir ($root_path | path join $p.local_dir) }
    )
    git download all ...$container_profiles
}

# Download documentation repository by ID
@example "agentonaut docs download nushell" { agentonaut docs download nushell }
@example "agentonaut docs download" { agentonaut docs download }
def "main docs download" [
    doc_id?: string  # Documentation profile name from config.toml
]: nothing -> nothing {
    let all_docs = ($env.agentonaut.cfg.profile | profile list-by-type "docs")

    if ($doc_id | is-empty) {
        print ($all_docs | select id description | sort-by id)
        return
    }

    let doc_profile = (
        try {
            ($env.agentonaut.cfg.profile | profile get-nested "docs" $doc_id)
        } catch {
            log error $"Documentation profile not found: ($doc_id)"
            return
        }
    )

    let base_dir = ($env.agentonaut.cfg.docs.base_dir | path expand)
    let target_dir = ($base_dir | path join $doc_profile.target_dir)
    let branch = ($doc_profile.branch? | default "main")
    let depth = ($doc_profile.depth? | default null)

    let repo = ($doc_profile.repo? | default "")
    if ($repo | is-empty) {
        log warning $"No repo configured for ($doc_id), skipping download"
        return
    }

    log info $"Downloading documentation: ($doc_profile.description)"

    if ($depth != null) {
        git clone repo $repo $target_dir --branch $branch --depth $depth
    } else {
        git clone repo $repo $target_dir --branch $branch
    }
}

# Download all documentation repositories
@example "agentonaut docs download all" { agentonaut docs download all }
def "main docs download all" []: nothing -> nothing {
    log info "Downloading all documentation repositories..."

    let all_docs = ($env.agentonaut.cfg.profile | profile list-by-type "docs")
    let count = ($all_docs | length)
    log info $"Found ($count) documentation profiles"

    $all_docs | each {|profile|
        log info $"Downloading: ($profile.id)"
        main docs download $profile.id
    }

    log info "All documentation repositories downloaded successfully"
}

# Show download and index status for all documentation profiles
@example "agentonaut docs status" { agentonaut docs status }
def "main docs status" []: nothing -> nothing {
    let base_dir = ($env.agentonaut.cfg.docs.base_dir | path expand)
    let all_docs = ($env.agentonaut.cfg.profile | profile list-by-type "docs")

    let rows = (
        $all_docs
        | each {|doc|
            let has_repo = ($doc.repo? | is-not-empty)
            let downloaded = if $has_repo {
                ($base_dir | path join $doc.target_dir | path exists)
            } else {
                false
            }
            {
                id: $doc.id
                downloaded: (if $has_repo { $downloaded } else { "n/a" })
                library_name: ($doc.library_name? | default "")
                mcp_url: ($doc.mcp_url? | default "")
            }
        }
    )

    let web_url = ($env.agentonaut.cfg.profile | profile get-nested "mcp" "docs-mcp-server" | get --optional web_url | default "")
    [
        ($rows | table)
        $"docs-mcp-server dashboard: ($web_url)"
    ] | print --raw
}

# List available docs profiles or index a single profile
#
# Without argument: lists profiles with library_name and mcp_url.
# With argument: indexes the given profile via docs-mcp-server scrape.
# Requires the pod to be running when indexing (start with: agentonaut launch --profile devops).
@example "agentonaut docs index" { agentonaut docs index }
@example "agentonaut docs index nushell" { agentonaut docs index nushell }
def "main docs index" [
    doc_id?: string  # Documentation profile to index. Omit to list available profiles.
]: nothing -> nothing {
    if ($doc_id | is-empty) {
        let all_docs = ($env.agentonaut.cfg.profile | profile list-by-type "docs")
        let available = (
            $all_docs
            | each {|d|
                {
                    id: $d.id
                    library_name: ($d.library_name? | default "")
                    mcp_url: ($d.mcp_url? | default "")
                }
            }
        )
        let web_url = ($env.agentonaut.cfg.profile | profile get-nested "mcp" "docs-mcp-server" | get --optional web_url | default "")
        [
            ""
            ($available | table)
            "Run: agentonaut docs index <id>  |  agentonaut docs index all"
            ""
            $"docs-mcp-server dashboard: ($web_url)"
        ] | print --raw
        return
    }

    let pod_name = $env.agentonaut.cfg.agentonaut.podman.pod_name
    let mcp_profile = ($env.agentonaut.cfg.profile | profile get-nested "mcp" "docs-mcp-server")
    let container_name = $"($pod_name)-($mcp_profile.container)"

    let doc = (
        try {
            ($env.agentonaut.cfg.profile | profile get-nested "docs" $doc_id)
        } catch {
            error make {msg: $"Documentation profile not found: ($doc_id)"}
        }
    )
    if ($doc.library_name? | is-empty) or ($doc.mcp_url? | is-empty) {
        error make {msg: $"Profile ($doc_id) has no library_name or mcp_url configured"}
    }

    let target_dir = ($doc.target_dir? | default "")
    if ($target_dir | is-not-empty) {
        let local_path = ($env.agentonaut.cfg.docs.base_dir | path expand | path join $target_dir)
        if not ($local_path | path exists) {
            log warning $"Skipping ($doc_id), not downloaded. Download with `agentonaut docs download ($doc_id)`"
            return
        }
    }

    log info $"Indexing: ($doc.library_name) from ($doc.mcp_url)"
    let exec_args = [
        "exec" "--workdir" "/app" $container_name
        "node" "--enable-source-maps" "dist/index.js"
        "scrape" $doc.library_name $doc.mcp_url
    ]
    let result = (^podman ...$exec_args | complete)
    if $result.exit_code != 0 {
        log error $"Failed to index ($doc.library_name): ($result.stderr | str trim)"
    } else {
        log info $"Indexed: ($doc.library_name)"
    }
}

# Index all documentation profiles with docs-mcp-server
#
# Requires the pod to be running (start with: agentonaut launch --profile devops).
@example "agentonaut docs index all" { agentonaut docs index all }
def "main docs index all" []: nothing -> nothing {
    let docs_base = ($env.agentonaut.cfg.docs.base_dir | path expand)
    let all_docs = (
        $env.agentonaut.cfg.profile
        | profile list-by-type "docs"
        | where {|d| ($d.library_name? | is-not-empty) and ($d.mcp_url? | is-not-empty)}
        | where {|d|
            let target_dir = ($d.target_dir? | default "")
            ($target_dir | is-not-empty) and ($docs_base | path join $target_dir | path exists)
        }
    )

    if ($all_docs | is-empty) {
        log warning "No indexable documentation profiles found (library_name and mcp_url required)"
        return
    }

    $all_docs | each {|doc|
        main docs index $doc.id
    }

    let web_url = ($env.agentonaut.cfg.profile | profile get-nested "mcp" "docs-mcp-server" | get --optional web_url | default "")
    [
        ""
        $"docs-mcp-server dashboard: ($web_url)"
        ""
        "Run `agentonaut docs download` for a list of available documentation profiles."
        "Run `agentonaut docs download <id>` to download a specific profile."
    ] | print --raw
}

# List libraries currently indexed in the running docs-mcp-server
#
# Requires the pod to be running (start with: agentonaut launch --profile devops).
@example "agentonaut docs index status" { agentonaut docs index status }
def "main docs index status" []: nothing -> nothing {
    let pod_name = $env.agentonaut.cfg.agentonaut.podman.pod_name
    let mcp_profile = ($env.agentonaut.cfg.profile | profile get-nested "mcp" "docs-mcp-server")
    let container_name = $"($pod_name)-($mcp_profile.container)"

    let exec_args = [
        "exec" "--workdir" "/app" $container_name
        "node" "--enable-source-maps" "dist/index.js" "list"
    ]
    ^podman ...$exec_args
    print ""
    print $"docs-mcp-server dashboard: ($mcp_profile | get --optional web_url | default "")"
}


# Create the container network defined in config
def "main network create" []: nothing -> nothing {
    podman network ensure $env.agentonaut.cfg.agentonaut.podman.network
}

# Remove the container network defined in config
def "main network remove" []: nothing -> nothing {
    podman network remove $env.agentonaut.cfg.agentonaut.podman.network
}

# Show build status for all container image profiles
@example "agentonaut image status" { agentonaut image status }
def "main image status" []: nothing -> nothing {
    let profiles = ($env.agentonaut.cfg.profile | profile list-by-type "container")

    let images_raw = (^podman images --format "{{.Repository}}:{{.Tag}}|||{{.Size}}|||{{.CreatedSince}}" | complete)
    if $images_raw.exit_code != 0 {
        log error $"Failed to list images: ($images_raw.stderr)"
        return
    }

    let all_images = (
        $images_raw.stdout
        | lines
        | parse "{tag}|||{size}|||{created}"
    )

    let rows = (
        $profiles
        | each {|profile|
            let matches = ($all_images | where tag == $profile.image_tag)
            let built = ($matches | is-not-empty)
            {
                id: $profile.id
                built: $built
                size: (if $built { ($matches | first | get size) } else { "" })
                created: (if $built { ($matches | first | get created) } else { "" })
                image_tag: $profile.image_tag
            }
        }
    )

    $rows | table | print --raw
}

# Build a container image from a profile
@example "agentonaut image build claude-contrib" { agentonaut image build claude-contrib }
@example "agentonaut image build" { agentonaut image build }
def "main image build" [
    profile_name?: string    # Profile to build. Omit to list available profiles.
    --force-rebuild(-f)      # Rebuild even if the version has not changed
    --no-deps                # Skip building profile dependencies
]: nothing -> int {

    if ($profile_name | is-empty) {
        $env.agentonaut.cfg.profile | profile print-container-profiles
        return
    }

    if not ($profile_name =~ '^[a-z0-9_-]+$') {
        error make { msg: $"Invalid profile name: '($profile_name)'" }
    }

    let profile = (
        try {
            ($env.agentonaut.cfg.profile | profile get-nested "container" $profile_name)
        } catch {
            error make { msg: $"Profile not found: ($profile_name)" }
        }
    )

    # Resolve dependencies first
    let dependencies = ($profile | get --optional depends_on | default [])
    if (not $no_deps) and ($dependencies | is-not-empty) {
        log info $"Resolving ($dependencies | length) dependencies for ($profile_name)..."
        for dep in $dependencies {
            log info $"Building dependency: ($dep)"
            let dep_result = (main image build $dep --force-rebuild=$force_rebuild)
            if $dep_result != 0 {
                log error $"Failed to build dependency: ($dep)"
                return 1
            }
        }
    }

    log info $"Building profile: ($profile_name)"

    # Check for upstream updates
    if ($profile | get --optional origin) == "upstream" {
        log warning "Upstream profile detected. Sources are not updated automatically."
        log info "To update, run: agentonaut git download by origin upstream"
    }

    let image_tag = ($profile | get image_tag)
    let containerfile = ($env.agentonaut.cfg.root_path | path join ($profile | get local_dir) ($profile | get containerfile))
    let context = ($env.agentonaut.cfg.root_path | path join ($profile | get local_dir) ($profile | get context))
    let base_image_override = ($profile | get --optional base_image_override | default "")

    let strategy = (version evaluate-build-requirement ($profile | get --optional version_check) $image_tag $force_rebuild)

    log info $strategy.reason

    if not $strategy.should_build {
        return 0
    }

    # Build image
    let version_args = if ($strategy.version | is-not-empty) {
        let build_arg_name = ($profile | get version_check | get build_arg)
        {($build_arg_name): $strategy.version}
    } else {
        {}
    }

    let build_args = (
        $version_args
        | merge { TZ: (util get-host-timezone) }
    )

    let build_result = if $force_rebuild {
        (
            podman build containerfile
                $image_tag
                $containerfile
                $context
                --base-image-override $base_image_override
                --build-args $build_args
                --no-cache
        )
    } else {
        (
            podman build containerfile
                $image_tag
                $containerfile
                $context
                --base-image-override $base_image_override
                --build-args $build_args
        )
    }

    if $build_result == 0 {
        log info "Cleaning up after build..."
        main image cleanup dangling
    }

    $build_result
}

# Build all container images from profiles in config
@example "NU_LOG_LEVEL=debug agentonaut image build all" { NU_LOG_LEVEL=debug agentonaut image build all }
@example "agentonaut image build all --force-rebuild" { agentonaut image build all --force-rebuild }
@example "agentonaut image build all" { agentonaut image build all }
def "main image build all" [
    --force-rebuild(-f)  # Force rebuild even if versions haven't changed
]: nothing -> nothing {
    log info "Building all container profiles..."

    let profiles = ($env.agentonaut.cfg.profile | profile list-by-type "container")

    if ($profiles | is-empty) {
        log warning "No container profiles found in config"
        return
    }

    log info $"Found ($profiles | length) container profiles"

    $profiles | each {|profile|
        if $force_rebuild {
            main image build $profile.id --force-rebuild --no-deps
        } else {
            main image build $profile.id --no-deps
        }
    }

    log info "All profiles built"
}

# Build container images filtered by field
@example "agentonaut image build by origin upstream --force-rebuild" { agentonaut image build by origin upstream --force-rebuild }
@example "agentonaut image build by origin upstream" { agentonaut image build by origin upstream }
@example "agentonaut image build by origin local" { agentonaut image build by origin local }
def "main image build by" [
    field?: string             # Filter field name (e.g., "origin")
    value?: string             # Filter value (e.g., "upstream", "local")
    --force-rebuild(-f)        # Force rebuild even if versions haven't changed
]: nothing -> nothing {
    let container_profiles = ($env.agentonaut.cfg.profile | profile list-by-type "container")

    if ($field | is-empty) {
        [
            ""
            ($container_profiles | select id origin | sort-by origin | table)
            "Run: agentonaut image build by <field> <value>"
        ] | print --raw
        return
    }

    if ($value | is-empty) {
        let values = ($container_profiles | get --optional $field | compact | uniq | sort)
        print $"Available values for ($field): ($values | str join ', ')"
        return
    }

    log info $"Building container profiles where ($field) = ($value)..."

    let profiles = (profile query $field $value $container_profiles)

    if ($profiles | is-empty) {
        log warning $"No container profiles found where ($field) = ($value)"
        return
    }

    log info $"Found ($profiles | length) profiles"

    $profiles | each {|p|
        if $force_rebuild {
            main image build $p.id --force-rebuild
        } else {
            main image build $p.id
        }
    }

    log info "All profiles built"
}

# Remove a container image by profile name
@example "agentonaut image remove" { agentonaut image remove }
@example "agentonaut image remove claude-contrib" { agentonaut image remove claude-contrib }
@example "agentonaut image remove claude --force" { agentonaut image remove claude --force }
def "main image remove" [
    profile_name?: string    # Profile whose image to remove. Omit to list available profiles.
    --force(-f)              # Remove even if the image is in use by stopped containers
]: nothing -> nothing {

    if ($profile_name | is-empty) {
        log info "Available container profiles:"
        let all_containers = ($env.agentonaut.cfg.profile | profile list-by-type "container")
        [
            ""
            ($all_containers | select id description | table)
            "Run: agentonaut image remove <profile_name>"
        ] | print --raw
        return
    }

    if not ($profile_name =~ '^[a-z0-9_-]+$') {
        error make {
            msg: $"Invalid profile name: '($profile_name)'"
        }
    }

    let profile = (
        try {
            ($env.agentonaut.cfg.profile | profile get-nested "container" $profile_name)
        } catch {
            error make {
                msg: $"Profile not found: ($profile_name)"
            }
        }
    )

    let image_tag = ($profile | get image_tag)
    log info $"Removing: ($image_tag)"

    let rmi_args = if $force { ["rmi" "--force" $image_tag] } else { ["rmi" $image_tag] }
    let result = (^podman ...$rmi_args | complete)
    if $result.exit_code != 0 {
        log error $"Failed to remove image: ($result.stderr | str trim)"
    } else {
        log info "Image removed"
    }
    return
}

# Remove all container images from profiles
@example "agentonaut image remove all" { agentonaut image remove all }
@example "agentonaut image remove all --force" { agentonaut image remove all --force }
def "main image remove all" [
    --force(-f)  # Force remove images even if in use by stopped containers
]: nothing -> nothing {
    log info "Removing all container images..."

    let profiles = ($env.agentonaut.cfg.profile | profile list-by-type "container")

    if ($profiles | is-empty) {
        log warning "No container profiles found in config"
        return
    }

    log info $"Found ($profiles | length) container profiles"

    $profiles | each {|profile|
        log info $"Removing: ($profile.image_tag)"
        let rmi_args = if $force { ["rmi" "--force" $profile.image_tag] } else { ["rmi" $profile.image_tag] }
        let result = (^podman ...$rmi_args | complete)
        if $result.exit_code != 0 {
            if ($result.stderr | str contains "image not known") {
                log debug $"($profile.image_tag) not found, skipping"
            } else {
                log warning $"Failed to remove ($profile.image_tag): ($result.stderr | str trim)"
            }
        }
    }

    log info "All images processed"
}

# Remove container images filtered by field
@example "agentonaut image remove by origin upstream" { agentonaut image remove by origin upstream }
@example "agentonaut image remove by origin local" { agentonaut image remove by origin local }
@example "agentonaut image remove by origin local --force" { agentonaut image remove by origin local --force }
def "main image remove by" [
    field?: string      # Filter field name (e.g., "origin")
    value?: string      # Filter value (e.g., "upstream", "local")
    --force(-f)         # Force remove even if image is in use
]: nothing -> nothing {
    let container_profiles = ($env.agentonaut.cfg.profile | profile list-by-type "container")

    if ($field | is-empty) {
        [
            ""
            ($container_profiles | select id origin | sort-by origin | table)
            "Run: agentonaut image remove by <field> <value>"
        ] | print --raw
        return
    }

    if ($value | is-empty) {
        let values = ($container_profiles | get --optional $field | compact | uniq | sort)
        print $"Available values for ($field): ($values | str join ', ')"
        return
    }

    log info $"Removing container images where ($field) = ($value)..."

    let profiles = (profile query $field $value $container_profiles)

    if ($profiles | is-empty) {
        log warning $"No container profiles found where ($field) = ($value)"
        return
    }

    log info $"Found ($profiles | length) profiles to remove"

    $profiles | each {|p|
        log info $"Removing: ($p.image_tag)"
        let rmi_args = if $force { ["rmi" "--force" $p.image_tag] } else { ["rmi" $p.image_tag] }
        let result = (^podman ...$rmi_args | complete)
        if $result.exit_code != 0 {
            if ($result.stderr | str contains "image not known") {
                log debug $"($p.image_tag) not found, skipping"
            } else {
                log warning $"Failed to remove ($p.image_tag): ($result.stderr | str trim)"
            }
        }
    }

    log info "All images removed"
}

# Remove dangling (untagged) images that belong to profiles defined in config.toml
@example "agentonaut image cleanup dangling" { agentonaut image cleanup dangling }
@example "agentonaut image cleanup dangling --dry-run" { agentonaut image cleanup dangling --dry-run }
@example "agentonaut image cleanup dangling --force" { agentonaut image cleanup dangling --force }
def "main image cleanup dangling" [
    --dry-run(-n)  # Show what would be deleted without actually deleting
    --force(-f)    # Force remove images even if in use by stopped containers
]: nothing -> nothing {
    let profiles = ($env.agentonaut.cfg.profile | profile list-by-type "container")

    if ($profiles | is-empty) {
        log warning "No container profiles found in config"
        return
    }

    let defined_repos = (
        $profiles
        | get image_tag
        | each {|tag|
            $tag | parse "{first}:{_}" | get first
        }
        | uniq
    )

    log debug $"Scanning for dangling images in ($defined_repos | length) repositories..."

    let images_raw = (^podman images --format "{{.Repository}}:{{.Tag}} {{.ID}} {{.Dangling}}" | complete)
    if $images_raw.exit_code != 0 {
        log error $"Failed to list images: ($images_raw.stderr)"
        return
    }

    let all_images = (
        $images_raw.stdout
        | lines
        | parse "{repo}:{tag} {id} {dangling}"
    )

    let dangling_images = (
        $all_images
        | where dangling == "true"
        | where repo in $defined_repos or repo == "<none>"
    )

    if ($dangling_images | is-empty) {
        log debug "No dangling images found"
        return
    }

    log debug $"Found ($dangling_images | length) dangling images"

    if $dry_run {
        $dangling_images | each {|img|
            log info $"Would remove: ($img.id) from ($img.repo)"
        }
        log info "Dry run complete"
    } else {
        let results = (
            $dangling_images
            | each {|img|
                let result = if $force {
                    ^podman rmi --force $img.id | complete
                } else {
                    ^podman rmi $img.id | complete
                }

                if $result.exit_code != 0 {
                    log debug $"Could not remove ($img.id): ($result.stderr | str trim)"
                }

                {id: $img.id, success: ($result.exit_code == 0)}
            }
        )

        let removed = ($results | where success | length)
        if $removed > 0 {
            log info $"Removed ($removed) dangling image\(s\)"
        }
    }
}


# List configured agents
@example "agentonaut list agents" { agentonaut list agents }
def "main list agents" []: nothing -> nothing {
    let default_agent = $env.agentonaut.cfg.agentonaut.default_agent
    let agents = (
        $env.agentonaut.cfg.profile
        | profile list-by-type "agent"
        | select id container
        | each {|row|
            $row | insert default ($row.id == $default_agent)
        }
    )
    print ($agents | table)
}

# List configured kube profiles
@example "agentonaut list profiles" { agentonaut list profiles }
def "main list profiles" []: nothing -> nothing {
    let default_profile = $env.agentonaut.cfg.kube.default_profile
    let profiles = (
        $env.agentonaut.cfg.profile
        | profile list-by-type "kube"
        | each {|row|
            let mcp_list = (
                $row.mcp_profiles
                | if ($in | is-empty) { "(none)" } else { str join ", " }
            )
            {
                id: $row.id
                default: ($row.id == $default_profile)
                description: $row.description
                mcps: $mcp_list
            }
        }
    )
    print ($profiles | table)
}


#
# Validate agent name against configured profiles
#
def validate-agent [
    agent: string  # Agent name to validate (e.g. claude, gemini)
]: nothing -> nothing {
    let agent_profiles = ($env.agentonaut.cfg.profile | profile list-by-type "agent")
    let available_agents = ($agent_profiles | get id)

    if $agent not-in $available_agents {
        let agent_list = ($available_agents | str join ', ')
        error make {
            msg: $"Invalid agent: ($agent)"
            help: $"Valid agents: ($agent_list)"
        }
    }
}


# Copy addons (skills, commands, hooks) for an agent to its data directory
@example "agentonaut agent setup claude" { agentonaut agent setup claude }
@example "agentonaut agent setup gemini" { agentonaut agent setup gemini }
def "main agent setup" [
    agent?: string   # Agent name (e.g. claude, gemini). Omit to list available agents.
    --overwrite(-o)  # Overwrite existing files
]: nothing -> nothing {
    if ($agent | is-empty) {
        let agent_profiles = ($env.agentonaut.cfg.profile | profile list-by-type "agent")
        log info "Available agents:"
        $agent_profiles | select id | print
        [
            ""
            "Run: agentonaut agent setup <agent>"
        ] | print --raw
        return
    }

    validate-agent $agent

    let addons_path = ($env.agentonaut.cfg.root_path | path join "addons" $agent)

    if not ($addons_path | path exists) {
        log warning $"No addons found for agent: ($agent)"
        return
    }

    let agent_profile = ($env.agentonaut.cfg.profile | profile get-nested "agent" $agent)
    let data_path = ($agent_profile.data_path_host | path expand)

    let addon_files = (
        glob $"($addons_path)/**/*"
        | where { |f| ($f | path type) == "file" }
    )

    if ($addon_files | is-empty) {
        log info $"No addon files found in: ($addons_path)"
        return
    }

    for file_path in $addon_files {
        let relative = ($file_path | path relative-to $addons_path)
        let target_path = ($data_path | path join $relative)
        let target_dir = ($target_path | path dirname)

        if not ($target_dir | path exists) {
            mkdir $target_dir
        }

        let display_path = ($target_path | str replace $env.HOME "~")

        if ($target_path | path exists) and (not $overwrite) {
            log info $"Skipped \(already exists\): ($display_path)"
        } else {
            cp $file_path $target_path
            log info $"Copied: ($display_path)"
        }
    }

    let skipped = (
        $addon_files
        | where { |f|
            let t = ($data_path | path join ($f | path relative-to $addons_path))
            ($t | path exists) and (not $overwrite)
        }
    )

    if ($skipped | is-not-empty) {
        log info $"($skipped | length) file\(s\) skipped. Use --overwrite to replace existing files."
    }

    log info "Done."
}


# Start an AI agent container with the given directory mounted as workspace
@example "agentonaut launch ~/my-project --agent <agent>" { agentonaut launch ~/my-project --agent <agent> }
@example "agentonaut launch ~/my-project --agent gemini" { agentonaut launch ~/my-project --agent gemini }
@example "agentonaut launch ~/my-project" { agentonaut launch ~/my-project }
def "main launch" [
    workspace_path: string              # Project directory to mount as workspace
    --name(-n): string = ""             # Container name override (default: derived from profile)
    --agent(-a): string = ""            # Agent to use (default: agentonaut.default_agent in config)
    --profile(-r): string = ""          # Kube profile name (default: kube.default_profile in config)
    --add-workspace(-w): list<string> = []  # Additional paths to mount read-only
]: nothing -> nothing {

    let agent = if ($agent | is-empty) {
        $env.agentonaut.cfg.agentonaut.default_agent
    } else {
        $agent
    }

    validate-agent $agent

    log info $"Using agent: ($agent)"

    let agent_profile = (
        ($env.agentonaut.cfg.profile | profile get-nested "agent" $agent)
    )

    let container_profile = (
        ($env.agentonaut.cfg.profile | profile get-nested "container" $agent_profile.container)
    )

    let container_name = if ($name | is-empty) {
        $container_profile
        | get --optional container_name
        | default $agent_profile.container
    } else {
        $name
    }

    let agent_home_dir = $container_profile.home_path
    let agent_config_path_expanded = ($agent_profile.config_path | path expand)
    let agent_data = {
        agent_name: $agent_profile.id
        agent_data_path_host: ($agent_profile.data_path_host | path expand)
        agent_config_path: $agent_config_path_expanded
        agent_mcp_command: $agent_profile.mcp_command
        agent_data_path_container: $agent_profile.data_path_container
        agent_workspace_env: "WORKSPACE"
        agent_config_mount_path: (
            if ($agent_config_path_expanded | path exists) {
                $"($agent_home_dir)/.($agent_profile.id).json"
            } else {
                ""
            }
        )
    }

    let container_data = {
        "container_name": $container_name
        "container_image": ($container_profile | get image_tag)
    }

    if not ($workspace_path | path exists) {
        error make {msg: "Workspace path does not exist."}
    }

    let workspace_path = ($workspace_path | path expand)
    let workspace_container_path = $"/workspace/($workspace_path | util sanitize path)"


    let workspace_data = {
        "workspace_path": $workspace_path
        "workspace_container_path": $workspace_container_path
    }

    # Validate and process additional workspaces
    let additional_workspaces = (
        $add_workspace
        | each {|dir|
            let expanded = ($dir | path expand)
            if not ($expanded | path exists) {
                error make {msg: $"Additional workspace does not exist: ($dir)"}
            }
            {
                host_path: $expanded
                container_path: $"/workspace/($expanded | util sanitize path)"
            }
        }
    )

    # Determine kube profile ID
    let profile_id = if ($profile | is-empty) {
        $env.agentonaut.cfg.kube.default_profile
    } else {
        $profile
    }

    log info $"Using kube profile: ($profile_id)"

    # Fetch kube profile
    let kube_profile = (
        ($env.agentonaut.cfg.profile | profile get-nested "kube" $profile_id)
    )

    let additional_volumes = if ("docs" in $env.agentonaut.cfg) {
        let docs_base = ($env.agentonaut.cfg.docs.base_dir | path expand)
        let volumes_base = ($docs_base | path dirname | path join "volumes")
        {
            "docs_mcp_server_data_path": ($volumes_base | path join "docs-mcp-server")
            "offline_documentation_path": $docs_base
        }
    } else {
        {
            "docs_mcp_server_data_path": ""
            "offline_documentation_path": ""
        }
    }

    # Build MCP data for template
    let mcps_data = (
        $kube_profile.mcp_profiles
        | each {|mcp_id|
            let mcp_local_id = $mcp_id

            # Extract MCP profile data from config
            let mcp_data = (
                ($env.agentonaut.cfg.profile | profile get-nested "mcp" $mcp_id)
            )

            # Fetch container profile for args and container_name
            let container_id = ($mcp_data | get --optional container)
            let container_data = if ($container_id | is-not-empty) {
                let container_profile = (
                    ($env.agentonaut.cfg.profile | profile get-nested "container" $container_id)
                )
                {
                    args: (
                        $container_profile
                        | get --optional container_args
                        | default []
                    )
                    container_name: (
                        $container_profile
                        | get --optional container_name
                        | default $container_id
                    )
                }
            } else {
                {args: [], container_name: $mcp_local_id}
            }

            $mcp_data
            | merge {
                local_id: $mcp_local_id
                container_name: $container_data.container_name
                args: $container_data.args
            }
        }
    )

    # Merge all data for template
    let cfg_data = (
        $env.agentonaut.cfg_idx
        | cfg extract --starts-with --output-separator "_"
            "agentonaut.podman"
            "kube.default_profile"
            "kube.tmp_file_path"
            "kube.template_dir"
        | merge $agent_data
        | merge $container_data
        | merge $workspace_data
        | merge $additional_volumes
        | merge {
            mcps: $mcps_data
            additional_workspaces: $additional_workspaces
        }
    )

    # Render master pod template
    log info "Rendering pod YAML..."
    let master_template_path = ($env.agentonaut.cfg.root_path | path join $env.agentonaut.cfg.kube.template_dir "pod.yaml.j2")
    podman kube render template $master_template_path $cfg_data $env.agentonaut.cfg.kube.tmp_file_path

    # Ensure network exists
    podman network ensure $env.agentonaut.cfg.agentonaut.podman.network

    # Execute podman kube play
    log info "Starting pod with podman kube play..."
    log warning "First start may take several minutes (--userns=keep-id ownership mapping)."
    let play_result = (^podman kube play --replace $env.agentonaut.cfg.kube.tmp_file_path | complete)

    if $play_result.exit_code != 0 {
        log error $"Failed to start pod: ($play_result.stderr | str trim)"
        error make {msg: "Failed to start pod with podman kube play"}
    }

    log info "Pod started, setting up MCPs..."

    # Register MCPs in container from config
    mcp register $cfg_data

    log info "Attaching to container..."

    # Build full container name: pod_name-container_name (deterministic)
    let full_container_name = $"($env.agentonaut.cfg.agentonaut.podman.pod_name)-($container_name)"

    # Attach to container
    podman run attach $full_container_name

    # Cleanup after session ends
    log info "Cleaning up pod..."

    try {
        podman pod stop $env.agentonaut.cfg.agentonaut.podman.pod_name
        podman pod rm $env.agentonaut.cfg.agentonaut.podman.pod_name
        log info "Pod removed"
    } catch {
        log warning $"Could not remove pod ($env.agentonaut.cfg.agentonaut.podman.pod_name) - may already be stopped"
    }

}

# Start an agent session stored under chat.base_path/<date> from config.toml
@example "agentonaut chat --agent <agent>" { agentonaut chat --agent <agent> }
@example "agentonaut chat" { agentonaut chat }
def "main chat" [
    --agent(-a): string = ""  # Agent to use (default: agentonaut.default_agent in config)
]: nothing -> nothing {

    let agent = if ($agent | is-empty) {
        $env.agentonaut.cfg.agentonaut.default_agent
    } else {
        $agent
    }

    # Get agent profile and create chat directory
    let agent_profile = ($env.agentonaut.cfg.profile | profile get-nested "agent" $agent)
    let agent_profile_expanded = (
        $env.agentonaut.cfg_idx
        | cfg extract nested "profile.agent" $agent_profile.id
    )
    let chat_base = $agent_profile_expanded.chat_base_path
    let today = (date now | format date "%Y-%m-%d")
    let chat_dir = ($chat_base | path join $today)

    if not ($chat_dir | path exists) {
        try { mkdir $chat_dir }
        log info $"Created chat directory: ($chat_dir)"
    }

    let chat_dir_abs = ($chat_dir | path expand)

    main launch $chat_dir_abs --agent $agent
}


# Stop and remove the pod started by the last launch or chat command
@example "agentonaut abort" { agentonaut abort }
def "main abort" []: nothing -> nothing {
    let pod_name = $env.agentonaut.cfg.agentonaut.podman.pod_name
    log info $"Stopping pod ($pod_name)..."

    let stop_result = (^podman pod stop $pod_name | complete)
    if $stop_result.exit_code != 0 {
        log warning $"Could not stop pod ($pod_name): ($stop_result.stderr | str trim)"
    } else {
        log info "Pod stopped."
    }

    let rm_result = (^podman pod rm $pod_name | complete)
    if $rm_result.exit_code != 0 {
        log warning $"Could not remove pod ($pod_name): ($rm_result.stderr | str trim)"
    } else {
        log info "Pod removed."
    }
}


# Check config, paths, image availability, and tool versions
@example "agentonaut doctor" { agentonaut doctor }
def "main doctor" []: nothing -> nothing {
    let cfg_loaded = ($env.agentonaut?.cfg? | is-not-empty)

    let config_dir_base = if ($env.XDG_CONFIG_HOME? | is-empty) {
        $"($env.HOME)/.config"
    } else {
        $env.XDG_CONFIG_HOME
    }

    # Reconstruct which config file was loaded (mirrors cfg locate search order)
    let config_file_path = if $cfg_loaded {
        let root_path = $env.agentonaut.cfg.root_path
        let candidates = [
            $"($root_path)/conf/config.toml"
            $"($config_dir_base)/agentonaut/config.toml"
            $"/etc/agentonaut/config.toml"
            $"($root_path)/conf/config.skel.toml"
        ]
        $candidates | where {|p| $p | path exists} | get --optional 0 | default "(unknown)"
    } else {
        "(not loaded)"
    }

    let project_root = if $cfg_loaded { $env.agentonaut.cfg.root_path } else { "(unknown)" }

    let agentonaut_env_vars = (
        $env
        | transpose key value
        | where {|it| $it.key | str starts-with "AGENTONAUT_"}
    )

    let config_dir_path = $"($config_dir_base)/agentonaut"
    let data_dir_path = $"($env.HOME)/.local/share/agentonaut"

    let nu_version = (version | get version)

    let podman_version = (
        try {
            ^podman --version | str trim | str replace "podman version " ""
        } catch {
            "(not found)"
        }
    )

    let wrapper_result = (which agentonaut | get --optional 0)
    let wrapper_path = if ($wrapper_result | is-not-empty) {
        $wrapper_result.path
    } else {
        "(not found)"
    }

    let network_name = if $cfg_loaded {
        $env.agentonaut.cfg.agentonaut.podman.network
    } else {
        "(unknown)"
    }

    let network_exists = if $cfg_loaded {
        try {
            ^podman network ls --format "{{.Name}}" | lines | any {|n| $n == $network_name}
        } catch {
            false
        }
    } else {
        false
    }

    let ok = $"(ansi green)yes(ansi reset)"
    let no = $"(ansi red)no(ansi reset)"
    let found = $"(ansi green)exists(ansi reset)"
    let not_found = $"(ansi red)not found(ansi reset)"

    # Configuration
    [
        $"(ansi yellow)Configuration(ansi reset)"
        $"  loaded:  (if $cfg_loaded { $ok } else { $no })"
        $"  path:    ($config_file_path)"
        ""
    ] | print --raw

    if $cfg_loaded {
        $env.agentonaut.cfg_idx | transpose key value | print
        print ""
    }

    # Environment
    [
        $"(ansi yellow)Environment(ansi reset)"
        $"  project root:  ($project_root)"
    ] | print --raw

    if ($agentonaut_env_vars | is-empty) {
        print "  AGENTONAUT_*:  (none set)"
    } else {
        $agentonaut_env_vars
        | each {|v| $"  ($v.key):  ($v.value)"}
        | print --raw
    }
    print ""

    # Directories
    [
        $"(ansi yellow)Directories(ansi reset)"
        $"  ~/.config/agentonaut:       (if ($config_dir_path | path exists) { $found } else { $not_found })"
        $"  ~/.local/share/agentonaut:  (if ($data_dir_path | path exists) { $found } else { $not_found })"
        ""
    ] | print --raw

    # Runtime
    [
        $"(ansi yellow)Runtime(ansi reset)"
        $"  nushell:  ($nu_version)"
        $"  podman:   ($podman_version)"
        $"  wrapper:  ($wrapper_path)"
        ""
    ] | print --raw

    # Network
    [
        $"(ansi yellow)Network(ansi reset)"
        $"  ($network_name):  (if $network_exists { $found } else { $not_found })"
        ""
    ] | print --raw
}

# Verify that config and data directories exist for the given agent
@example "agentonaut host check gemini" { agentonaut host check gemini }
@example "agentonaut host check claude" { agentonaut host check claude }
def "main host check" [
    agent: string  # Agent name (e.g. claude, gemini)
]: nothing -> nothing {

    # Get agent configuration
    let agent_profile = ($env.agentonaut.cfg.profile | profile get-nested "agent" $agent)
    let agent_profile_expanded = (
        $env.agentonaut.cfg_idx
        | cfg extract nested "profile.agent" $agent_profile.id
    )
    let agent_data_path_host = ($agent_profile.data_path_host | path expand)
    let agent_config_path = $agent_profile_expanded.config_path
    let agent_config_dir = ($agent_config_path | path dirname)

    let config_exists = ($agent_config_dir | path exists)
    let data_exists = ($agent_data_path_host | path exists)
    let file_exists = ($agent_config_path | path exists)

    if not $config_exists or not $data_exists or not $file_exists {
        log error $"Agent directories not set up for: ($agent)"
        if not $config_exists {
            log error $"  Missing config dir: ($agent_config_dir)"
        }
        if not $data_exists {
            log error $"  Missing data path: ($agent_data_path_host)"
        }
        if not $file_exists {
            log error $"  Missing config file: ($agent_config_path)"
        }
        log error ""
        log error "Please run: agentonaut host setup"
        log error ""
        error make {
            msg: $"Host setup required for agent: ($agent)"
            help: "Run 'agentonaut host setup' to create required directories and config files"
        }
    }

    log info $"Host setup verified for agent: ($agent)"
    log info $"  Config dir: ($agent_config_dir)"
    log info $"  Data path: ($agent_data_path_host)"
    log info $"  Config file: ($agent_config_path)"
}

# Create agent config and data directories and generate config.toml from the skeleton
@example "agentonaut host setup" { agentonaut host setup }
def "main host setup" []: nothing -> nothing {
    let home = (
        $env.HOME
        | path expand
    )

    let workspace_dir = ($home | path join ".claude-workspace")

    log info "Setting up host for agentonaut..."

    # Create user configuration from skeleton
    let setup_result = (cfg setup "agentonaut")
    if $setup_result.created {
        log info $"Created user configuration from skeleton: ($setup_result.path)"
        log info "Review configuration and adjust paths if needed."
    } else {
        log info $"User configuration already exists: ($setup_result.path)"
    }

    let agent_profiles = ($env.agentonaut.cfg.profile | profile list-by-type "agent")

    # Create config directories for each agent
    let agents = ($agent_profiles | get id)
    for agent in $agents {
        # Get agent configuration
        let agent_profile = ($env.agentonaut.cfg.profile | profile get-nested "agent" $agent)
        let agent_profile_expanded = (
            $env.agentonaut.cfg_idx
            | cfg extract nested "profile.agent" $agent_profile.id
        )
        let agent_data_path_host = ($agent_profile.data_path_host | path expand)
        let agent_config_path = $agent_profile_expanded.config_path
        let agent_config_dir = ($agent_config_path | path dirname)

        if not ($agent_config_dir | path exists) {
            log info $"Creating config directory: ($agent_config_dir)"
            try { mkdir $agent_config_dir }
        } else {
            log info $"Config directory already exists: ($agent_config_dir)"
        }

        if not ($agent_data_path_host | path exists) {
            log info $"Creating data path: ($agent_data_path_host)"
            try { mkdir $agent_data_path_host }
        } else {
            log info $"Data path already exists: ($agent_data_path_host)"
        }

        if not ($agent_config_path | path exists) {
            log info $"Creating config file: ($agent_config_path)"
            try { "{}" | save --force $agent_config_path }
        } else {
            log info $"Config file already exists: ($agent_config_path)"
        }
    }

    # Create workspace directory (legacy compatibility)
    if not ($workspace_dir | path exists) {
        log info $"Creating workspace directory: ($workspace_dir)"
        try { mkdir $workspace_dir }
    } else {
        log info $"Workspace directory already exists: ($workspace_dir)"
    }

    # Create offline documentation directory if docs section is configured
    if ("docs" in $env.agentonaut.cfg) {
        let docs_base = ($env.agentonaut.cfg.docs.base_dir | path expand)
        if not ($docs_base | path exists) {
            log info $"Creating offline documentation directory: ($docs_base)"
            try { mkdir $docs_base }
        } else {
            log info $"Offline documentation directory already exists: ($docs_base)"
        }
    }

    log info "Host setup complete"
    log info $"  Workspace: ($workspace_dir)"
}


# Agentonaut
#
# Manage and run AI agents (Claude Code, Gemini) in isolated Podman containers.
# Agents are configured via profiles and run with optional MCP server support.
#
@example "agentonaut launch ~/Projects/my-project" { agentonaut launch ~/Projects/my-project }
@example "agentonaut image build all" { agentonaut image build all }
@example "agentonaut host setup" { agentonaut host setup }
def --wrapped main [
    --version(-v)  # Show version
    ...rest: string
]: nothing -> nothing {

    if $version {
        $AGENTONAUT_VERSION | print
        return
    }

    if ($rest | is-empty) or ("--help" in $rest) or ("-h" in $rest) {
        let app_name = ("agentonaut" | util sanitize name)
        let cmd_parts = ($rest | where { |it| not ($it starts-with "-") })
        if ($cmd_parts | is-empty) {
            script help general $app_name
        } else {
            script help namespace ($cmd_parts | str join " ") $app_name
        }
        return
    }

    if ($rest | is-not-empty) {
        let app_name = ("agentonaut" | util sanitize name)
        let cmd_parts = ($rest | where { |it| not ($it starts-with "-") })
        let ns_candidate = ($cmd_parts | str join " ")
        if ($ns_candidate in (script get namespaces)) {
            script help namespace $ns_candidate $app_name
            return
        }
        error make { msg: $"Unknown subcommand: ($rest | str join ' ')" }
    }
}
