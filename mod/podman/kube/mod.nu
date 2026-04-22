use std/log

# Podman Kube Configuration Handler
#
# Loads and executes Podman Kubernetes-format YAML configuration files.
# Provides functions for running, stopping, and removing pods defined in YAML.

# Execute a kube YAML configuration record piped on stdin via podman kube play
export def play [
    --replace(-r)    # Delete and recreate the pod if it already exists
    --wait(-w)       # Wait for the pod to exit before returning
    --no-cleanup(-n) # Keep containers after the pod exits (useful for debugging)
]: any -> any {
    log info "Executing Podman kube configuration"

    # Convert record back to YAML and pipe to podman
    let yaml_output = ($in | to yaml)

    mut args = ["kube" "play"]

    if $replace {
        $args ++= ["--replace"]
        log debug "Running with --replace flag (will delete existing pods)"
    }

    if $wait {
        $args ++= ["--wait"]
        log debug "Running with --wait flag (will wait for pods to exit)"
    }

    if $no_cleanup {
        $args ++= ["--no-cleanup"]
        log debug "Running with --no-cleanup flag"
    }

    # Use "-" to read from stdin
    $args ++= ["-"]

    log info "Starting Podman kube configuration..."
    log debug $"Args: ($args | to json)"
    log debug $"YAML length: ($yaml_output | str length)"

    $yaml_output | ^podman ...$args

    if $env.LAST_EXIT_CODE == 0 {
        log info "Podman kube configuration executed successfully"
        return 0
    } else {
        log error $"Podman kube configuration execution failed with exit code: ($env.LAST_EXIT_CODE)"
        return 1
    }
}

# Stop a pod created from a kube configuration
export def stop [
    pod_name: string  # Pod name
] {
    log info $"Stopping pod: ($pod_name)"

    if (^podman pod stop $pod_name | complete).exit_code == 0 {
        log info $"Pod stopped: ($pod_name)"
        return 0
    } else {
        log error "Failed to stop pod"
        return 1
    }
}

# Stop and remove a pod and all its containers
export def rm [
    pod_name: string  # Pod name
] {
    log info $"Removing pod: ($pod_name)"

    # Stop the pod first (stops all containers in it)
    log debug $"Stopping pod before removal: ($pod_name)"
    try {
        ^podman pod stop $pod_name
    } catch {
        log debug $"Pod not running or already stopped: ($pod_name)"
    }

    if (^podman pod rm $pod_name | complete).exit_code == 0 {
        log info $"Pod removed: ($pod_name)"
        return 0
    } else {
        log error "Failed to remove pod"
        return 1
    }
}

# List all Podman pods
export def list [] {
    log info "Listing Podman pods from kube configurations..."
    ^podman pod ls
}

# Show detailed information about a pod and its containers
export def inspect [
    pod_name: string  # Pod name
] {
    log info $"Inspecting pod: ($pod_name)"
    ^podman pod inspect $pod_name
}

# Return the status record for a pod
export def status [
    pod_name: string  # Pod name
] {
    log info $"Getting status of pod: ($pod_name)"

    let pod_info = (
        podman pod ls --format json
        | from json
        | where Name == $pod_name
    )

    if ($pod_info | is-empty) {
        log warning $"Pod not found: ($pod_name)"
        return
    }

    $pod_info | first
}

# Render a Jinja2 YAML template to a file using minijinja-cli
export def "render template" [
    template_path: path  # Path to the Jinja2 template file
    data: record         # Data record passed to the template
    output_path: path    # Output file path for the rendered YAML
] {
    log debug $"Rendering template: ($template_path)"
    log debug $"Output path: ($output_path)"

    # Get template directory for includes
    let template_dir = ($template_path | path dirname)

    # Ensure output directory exists
    let output_dir = ($output_path | path dirname)
    if not ($output_dir | path exists) {
        mkdir $output_dir
    }

    # Save data to temp TOML file (cleaner string representation)
    let temp_data_path = ($output_dir | path join "template-data.toml")
    $data | to toml | save --force $temp_data_path

    # Render template with minijinja-cli
    ^minijinja-cli --safe-path $template_dir --format toml --autoescape=none --output $output_path $template_path $temp_data_path

    # Clean up temp data file
    # ^rm $temp_data_path  # Temporarily disabled for debugging

    log debug $"Template rendered to: ($output_path)"
    $output_path
}

# Concatenate multiple YAML files into a single multi-document YAML for podman kube play
export def "prepare yaml" [
    yaml_files: list<string>  # Paths to YAML files to concatenate
    output_path: path         # Output file path
] {
    log debug $"Preparing multi-document YAML from ($yaml_files | length) files"
    log debug $"Output path: ($output_path)"

    # Ensure output directory exists
    let output_dir = ($output_path | path dirname)
    mkdir $output_dir

    # Remove existing output file if present
    if ($output_path | path exists) {
        log debug $"Removing existing output file: ($output_path)"
        ^rm $output_path
    }

    # Concatenate all YAML files (raw content) into single multi-document YAML
    $yaml_files
    | each {|yaml_file|
        log debug $"Reading YAML: ($yaml_file)"
        open --raw $yaml_file | save --append $output_path
    }

    log info $"Multi-document YAML prepared at: ($output_path)"
    $output_path
}

# Find a container by name in a kube config and apply a record of updates to it
export def "update container" [
    container_name: string  # Container name as defined in the kube YAML
    updates: record         # Fields to merge into the container definition
] {
    log debug $"Updating container: ($container_name)"

    let config = $in

    let matches = (
        $config.spec.containers
        | enumerate
        | where { |item| $item.item.name == $container_name }
    )

    if ($matches | is-empty) {
        error make {
            msg: $"Container not found: ($container_name)"
            help: $"Available containers: (($config.spec.containers | get name) | str join ', ')"
        }
    }

    let index = ($matches | first | get index)
    log debug $"Found container at index: ($index)"

    let updated_containers = (
        $config.spec.containers
        | enumerate
        | each {|item|
            if $item.index == $index {
                $item.item | merge $updates
            } else {
                $item.item
            }
        }
    )

    $config | update spec.containers $updated_containers
}

# Update hostPath volumes in a kube config by index
export def "update volumes" [
    volume_paths: record  # Map of volume index (as string) to absolute host path
] {
    log debug "Updating volume paths by index"

    let config = $in
    let indices = ($volume_paths | columns | each {|c| $c | into int})

    let updated_volumes = (
        $config.spec.volumes
        | enumerate
        | each {|item|
            if ($item.index in $indices) {
                $item.item | upsert hostPath.path ($volume_paths | get ($item.index | into string))
            } else {
                $item.item
            }
        }
    )

    $config | update spec.volumes $updated_volumes
}

# Update hostPath volumes in a kube config by volume name
export def "update volumes by name" [
    volume_paths: record  # Map of volume name to absolute host path
] {
    log debug "Updating volume paths by name"

    let config = $in
    let volume_names = ($volume_paths | columns)

    let updated_volumes = (
        $config.spec.volumes
        | each {|vol|
            if ($vol.name in $volume_names) {
                $vol | upsert hostPath.path ($volume_paths | get $vol.name)
            } else {
                $vol
            }
        }
    )

    $config | update spec.volumes $updated_volumes
}

# Update the workspace mountPath and CLAUDE_WORKSPACE env var in all containers
export def "update workspace" [
    container_workspace: path  # Absolute container path for the workspace mount
] {
    log debug $"Updating workspace path to: ($container_workspace)"

    let config = $in

    let updated_containers = (
        $config.spec.containers
        | each {|container|
            let updated_mounts = (
                $container.volumeMounts
                | each {|mount|
                    if $mount.name == "workspace" {
                        $mount | update mountPath $container_workspace
                    } else {
                        $mount
                    }
                }
            )

            let updated_env = (
                $container.env?
                | default []
                | each {|e|
                    if $e.name == "CLAUDE_WORKSPACE" {
                        $e | update value $container_workspace
                    } else {
                        $e
                    }
                }
            )

            $container
            | update volumeMounts $updated_mounts
            | update env $updated_env
        }
    )

    $config | update spec.containers $updated_containers
}
