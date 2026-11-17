export module ./build.nu
export module ./run.nu
export module ./network.nu
export module ./pod.nu
export module ./kube

# Nushell 0.114.0 stopped importing submodules implicitly. Without these,
# `use podman` exposes only this file's own commands, and calls like
# `podman build containerfile` fall through to the external podman binary.
export use ./build.nu
export use ./run.nu
export use ./network.nu
export use ./pod.nu
export use ./kube

const PODMAN_MODULE_VERSION = "0.7.8"

# List all containers (running and stopped)
export def ps []: any -> string {
    let result = (^podman ps -a | complete)
    $result.stdout
}

# Stop a container by name
export def stop [
    name: string  # Container name or ID
]: any -> int {
    log info $"Stopping container: ($name)"
    let result = (^podman stop $name | complete)
    if $result.exit_code == 0 {
        log info $"Container stopped: ($name)"
        return 0
    } else {
        log error $"Failed to stop container: ($result.stderr | str trim)"
        return 1
    }
}

# Inspect a container and return raw JSON output
export def inspect [
    name: string  # Container name or ID
]: any -> string {
    let result = (^podman inspect $name | complete)
    $result.stdout
}
