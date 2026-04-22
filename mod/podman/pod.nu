use std/log

# Check if a pod exists by name
export def exists [
    pod_name: string  # Pod name
]: any -> bool {
    let result = (^podman pod ls --format json | complete)
    if $result.exit_code != 0 {
        return false
    }
    (
        $result.stdout
        | from json
        | where Name == $pod_name
        | length
    ) > 0
}

# Create a pod with the given name and network
export def create [
    pod_name: string        # Pod name
    network_name: string    # Podman network to attach
    --ports(-p): list<string> = []  # Port mappings (e.g. ["8080:8080", "443:443"])
]: any -> int {
    log info $"Creating pod: ($pod_name)"

    if (exists $pod_name) {
        log warning $"Pod already exists: ($pod_name)"
        return 0
    }

    mut args = [
        "pod" "create"
        "--name" $pod_name
        "--network" $network_name
        "--userns" "keep-id"
        "--share" "net,ipc,uts"
    ]

    # Add port mappings if provided
    if ($ports | is-not-empty) {
        let port_args = ($ports | each {|p| ["--publish" $p] } | flatten)
        $args ++= [$port_args]
    }

    let result = (^podman ...$args | complete)

    if $result.exit_code == 0 {
        log info $"Pod created: ($pod_name)"
        return 0
    } else {
        log error $"Failed to create pod: ($result.stderr)"
        return 1
    }
}

# Stop a running pod
export def stop [
    pod_name: string  # Pod name
]: any -> int {
    log info $"Stopping pod: ($pod_name)"

    let result = (^podman pod stop $pod_name | complete)

    if $result.exit_code == 0 {
        log info $"Pod stopped: ($pod_name)"
        return 0
    } else {
        log error $"Failed to stop pod: ($result.stderr)"
        return 1
    }
}

# Remove a pod and all its containers
export def rm [
    pod_name: string  # Pod name
]: any -> int {
    log info $"Removing pod: ($pod_name)"

    let result = (^podman pod rm $pod_name | complete)

    if $result.exit_code == 0 {
        log info $"Pod removed: ($pod_name)"
        return 0
    } else {
        log error $"Failed to remove pod: ($result.stderr)"
        return 1
    }
}

# List pods matching the agentonaut workspace filter
export def ps []: any -> string {
    let result = (^podman pod ls --filter "name=claude-workspace-" | complete)
    $result.stdout
}

# Inspect a pod and return raw JSON output
export def inspect [
    pod_name: string  # Pod name
]: any -> string {
    let result = (^podman pod inspect $pod_name | complete)
    $result.stdout
}

