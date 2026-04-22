use std/log

# Check if a Podman network exists
export def exists [
    network_name: string  # Network name
]: any -> bool {
    let result = (^podman network ls --format json | complete)
    if $result.exit_code != 0 {
        log error $"Failed to list networks: ($result.stderr)"
        return false
    }

    let count = (
        $result.stdout
        | from json
        | where Name == $network_name
        | length
    )
    ($count > 0)
}

# Create a bridge network
export def create [
    network_name: string  # Network name
]: any -> int {
    log info $"Creating Podman bridge network: ($network_name)"

    let result = (
        ^podman network create --driver bridge $network_name
        | complete
    )

    if $result.exit_code == 0 {
        log info $"Network created: ($network_name)"
        return 0
    } else {
        error make {
            msg: $"Failed to create network: ($network_name)"
            debug: $result.stderr
        }
    }
}

# Remove a network
export def remove [
    network_name: string  # Network name
]: any -> nothing {
    log info $"Removing Podman network: ($network_name)"

    let result = (^podman network rm $network_name | complete)

    if $result.exit_code == 0 {
        log info $"Network removed: ($network_name)"
    } else if ($result.stderr | str contains "not found") {
        log info $"Network does not exist: ($network_name)"
    } else {
        error make {
            msg: $"Failed to remove network: ($network_name)"
            debug: $result.stderr
        }
    }
}

# Ensure a network exists, create it if it does not
export def ensure [
    network_name: string  # Network name
]: any -> nothing {
    if not (exists $network_name) {
        log info $"Creating network: ($network_name)"
        create $network_name
    } else {
        log info $"Network already exists: ($network_name)"
    }
}
