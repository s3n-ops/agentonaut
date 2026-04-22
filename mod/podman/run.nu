use std/log

# Start an interactive session in a container via exec (allocates a fresh PTY)
export def attach [
    container_name: string  # Container name or ID
]: any -> nothing {
    log info $"Starting session in container: ($container_name)"
    ^podman exec --tty --interactive $container_name /usr/local/bin/start.nu
}
