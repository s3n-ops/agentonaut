use std log
const GIT_MODULE_VERSION = "0.2.4"

# Download a GitHub directory using git sparse checkout
export def "download dir" [
    repo_url: string    # Repository URL (e.g., "https://github.com/anthropics/claude-code")
    repo_dir: string    # Relative path to the target directory in the repository (e.g., ".devcontainer")
    repo_branch: string # Branch to checkout (e.g., "main")
    target_dir: string  # Local directory to save files (e.g., "./container/contrib")
]: any -> nothing {
    log info $"Downloading ($repo_dir) from ($repo_url) - branch: ($repo_branch)..."

    let target_path = ($target_dir | path expand)
    mkdir $target_path

    # Check if Git repository already exists
    let git_dir = ($target_path | path join ".git")

    if ($git_dir | path exists) {
        log info "Repository already exists, updating..."
        let result = (git -C $target_path fetch --depth=1 origin $repo_branch | complete)

        if $result.exit_code == 0 {
            git -C $target_path reset --hard FETCH_HEAD | complete
            log info $"Download complete: ($target_dir)"
        } else {
            log error $"Failed to update: ($result.stderr)"
        }
    } else {
        log info "Initializing sparse checkout..."
        git -C $target_path init | complete
        git -C $target_path remote add origin $repo_url | complete
        git -C $target_path config core.sparseCheckout true | complete

        # Configure sparse checkout to only get the specified directory
        let checkout_path = if ($repo_dir == ".") {
            "*"
        } else {
            $"($repo_dir)/*"
        }
        $checkout_path | save --force ($target_path | path join ".git/info/sparse-checkout")

        # Pull only the specified directory with minimal history
        log info "Fetching files from repository..."
        let result = (git -C $target_path pull --depth=1 origin $repo_branch | complete)

        if $result.exit_code == 0 {
            log info $"Download complete: ($target_dir)"
        } else {
            log error $"Failed to download: ($result.stderr)"
        }
    }
}

# Download claude-code .devcontainer directory
export def "download devcontainer" [
    repo_url: string      # Upstream repository URL
    repo_dir: string      # Directory to download from repository
    repo_branch: string   # Branch to checkout
    target_dir: string    # Local target directory
]: any -> nothing {
    log info "Downloading claude-code .devcontainer directory..."
    download dir $repo_url $repo_dir $repo_branch $target_dir
}

# Download complete repository (full clone, not sparse)
export def "clone repo" [
    repo_url: string    # Repository URL
    target_dir: string  # Local directory to save repository
    --branch: string = "main"  # Branch to checkout
    --depth: int        # Optional depth for shallow clone
]: any -> nothing {
    log info $"Cloning repository from ($repo_url) - branch: ($branch)..."

    let target_path = ($target_dir | path expand)
    let git_dir = ($target_path | path join ".git")

    if ($git_dir | path exists) {
        log info "Repository already exists, updating..."

        let result = (
            git -C $target_path fetch origin $branch
            | complete
        )

        if $result.exit_code == 0 {
            git -C $target_path reset --hard $"origin/($branch)" | complete
            log info $"Update complete: ($target_dir)"
        } else {
            log error $"Failed to update: ($result.stderr)"
        }
    } else {
        log info "Cloning repository..."
        mkdir $target_path

        let clone_args = if ($depth != null) {
            [
                "clone"
                "--branch"
                $branch
                "--depth"
                ($depth | into string)
                $repo_url
                $target_path
            ]
        } else {
            ["clone" "--branch" $branch $repo_url $target_path]
        }

        let result = (git ...$clone_args | complete)

        if $result.exit_code == 0 {
            log info $"Clone complete: ($target_dir)"
        } else {
            log error $"Failed to clone: ($result.stderr)"
        }
    }
}

# Download all upstream profiles from provided config array
export def "download all" [...profiles: list<any>]: any -> any {
    log info "Downloading all upstream container profiles..."

    let upstream_profiles = ($profiles | where origin == "upstream")

    if ($upstream_profiles | is-empty) {
        log warning "No upstream profiles found in config"
        return
    }

    let count = ($upstream_profiles | length)
    log info $"Found ($count) upstream profiles to download"

    $upstream_profiles | each {|profile|
        log info $"Downloading profile: ($profile.id)"

        let repo_url = $profile.repo
        let local_dir = $profile.local_dir
        let containerfile = $profile.containerfile

        # Extract directory from containerfile path (e.g., ".devcontainer/Dockerfile" → ".devcontainer")
        let repo_dir = if $containerfile =~ "/" {
            $containerfile | path dirname
        } else {
            "."
        }

        let repo_branch = $profile.repo_branch? | default "main"

        download dir $repo_url $repo_dir $repo_branch $local_dir
    }

    log info "All upstream profiles downloaded"
}

