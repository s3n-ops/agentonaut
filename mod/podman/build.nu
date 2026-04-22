use std/log

# Build a container image from a Containerfile
export def containerfile [
    image_tag: string           # Image tag to assign (e.g. localhost/claude:latest)
    containerfile: string       # Path to the Containerfile
    context: string             # Build context directory
    --base-image-override: string = ""  # Replace the FROM image in the Containerfile
    --build-args: record = {}           # Build arguments passed as --build-arg key=value
    --no-cache                          # Disable build cache
]: any -> int {
    log info $"Building: ($image_tag)"

    let containerfile_abs = ($containerfile | path expand)
    let context_abs = ($context | path expand)

    if not ($containerfile_abs | path exists) {
        error make {
            msg: $"Containerfile not found: ($containerfile_abs)"
        }
    }

    if not ($context_abs | path exists) {
        error make {
            msg: $"Context not found: ($context_abs)"
        }
    }

    let temp_dir = ($env.agentonaut.cfg.root_path | path join ".build")
    mkdir $temp_dir

    # Inject custom base image into a temporary Containerfile if override is requested
    let build_containerfile = if ($base_image_override | is-not-empty) {
        let content = (open $containerfile_abs)
        let modified = ($content | str replace --regex '^FROM\s+\S+' $"FROM ($base_image_override)")
        let sanitized_tag = ($image_tag | str replace --all --regex "/|:" "_")
        let temp_file = ($temp_dir | path join $"Containerfile.($sanitized_tag)")
        $modified | save --force $temp_file
        log info $"Using base image override: ($base_image_override)"
        $temp_file
    } else {
        $containerfile_abs
    }

    let empty_auth = ($temp_dir | path join "podman-empty-auth.json")
    '{"auths":{}}' | save --force $empty_auth

    let build_arg_list = (
        $build_args
        | items {|key, value| ["--build-arg" $"($key)=($value)"] }
        | flatten
    )

    let no_cache_flag = if $no_cache { ["--no-cache"] } else { [] }

    let result = (
        ^podman build
            --authfile $empty_auth
            --security-opt seccomp=unconfined
            -t $image_tag
            -f $build_containerfile
            ...$build_arg_list
            ...$no_cache_flag
            $context_abs
        | complete
    )

    if $result.exit_code == 0 {
        log info $"Built: ($image_tag)"
        return 0
    } else {
        log error $"Build failed: ($result.stderr)"
        return 1
    }
}

