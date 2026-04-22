#!/usr/bin/env nu

# Agentonaut Installation Script (Linux)
#
# Features:
# - Pre-flight check for required dependencies and minimum versions
# - Idempotent generation of the Agentonaut wrapper script in ~/.local/bin/agentonaut
# - Automatic configuration initialization from skeleton if missing
# - PATH verification

def main [] {
    if ($nu.os-info.name != "linux") {
        print $"(ansi red)Error: This script only supports Linux.(ansi reset)"
        exit 1
    }

    # Pre-flight check with minimum versions
    let requirements = [
        { name: "podman",        cmd: "podman",        min_version: "4.4.0" }
        { name: "nushell",       cmd: "nu",            min_version: "0.111.0" }
        { name: "minijinja-cli", cmd: "minijinja-cli", min_version: "2.0.0" }
        { name: "git",           cmd: "git",           min_version: "2.25.0" }
    ]

    if not (preflight_check $requirements) {
        exit 1
    }

    if not (check_rootless) {
        exit 1
    }

    let project_root = ($env.FILE_PWD | path expand)
    let bin_dir = ($env.HOME | path join ".local" "bin")
    let target = ($bin_dir | path join "agentonaut")
    let source = ($project_root | path join "bin" "agentonaut.nu")
    let wrapper_template = ($project_root | path join "conf" "templates" "wrapper.nu.j2")
    
    let user_config_dir = ($env.HOME | path join ".config" "agentonaut")
    let user_config_file = ($user_config_dir | path join "config.toml")
    let user_data_dir = ($env.HOME | path join ".local" "share" "agentonaut")
    let chat_dir = ($env.HOME | path join "Documents" "agentonaut")
    let skel_config = ($project_root | path join "conf" "config.skel.toml")

    if not (confirm_install $project_root $target $user_config_dir $user_data_dir $chat_dir) {
        print "Aborted."
        exit 0
    }

    # Orchestration
    setup_bin_dir $bin_dir
    install_wrapper $target $source $wrapper_template $project_root
    init_config $project_root $user_config_dir $user_config_file $skel_config
    setup_chat_dir $chat_dir
    run_host_setup $target
    run_network_create $target
    run_git_download $target
    run_agent_setup $target
    verify_path $bin_dir $user_config_file $project_root
}

# Confirmation prompt before installation
def confirm_install [project_root: path, target: path, user_config_dir: path, user_data_dir: path, chat_dir: path]: nothing -> bool {
    [
        ""
        "Agentonaut installation"
        ""
        $"  Project directory : ($project_root)"
        $"  Wrapper script    : ($target)"
        $"  Config directory  : ($user_config_dir)"
        $"  Data directory    : ($user_data_dir)"
        $"  Chat directory    : ($chat_dir)"
    ] | print --raw
    print ""

    let answer = (input "Proceed with installation? [y/N] " | str trim | str downcase)
    $answer == "y"
}

# Chat Directory Creation
def setup_chat_dir [chat_dir: path] {
    if not ($chat_dir | path exists) {
        print $"(ansi yellow)» Creating chat directory: ($chat_dir)(ansi reset)"
        mkdir $chat_dir
    }
}

# Check rootless Podman configuration
def check_rootless []: nothing -> bool {
    print $"(ansi yellow)» Checking rootless Podman configuration...(ansi reset)"

    # User namespace mapping via podman unshare
    let unshare_ok = (
        try { (^podman unshare echo "ok" | str trim) == "ok" } catch { false }
    )

    # Rootless network tool (one required)
    let has_slirp4netns = (which "slirp4netns" | is-not-empty)
    let has_pasta = (which "pasta" | is-not-empty)
    let network_ok = ($has_slirp4netns or $has_pasta)

    # subuid/subgid entries for current user
    let subuid_ok = (
        try { (open "/etc/subuid" | str contains $env.USER) } catch { false }
    )
    let subgid_ok = (
        try { (open "/etc/subgid" | str contains $env.USER) } catch { false }
    )

    let results = [
        { name: "user namespaces (podman unshare)", status: (if $unshare_ok { $"(ansi green)OK(ansi reset)" } else { $"(ansi red)Failed(ansi reset)" }) }
        { name: $"/etc/subuid entry for ($env.USER)",   status: (if $subuid_ok  { $"(ansi green)OK(ansi reset)" } else { $"(ansi red)Missing(ansi reset)" }) }
        { name: $"/etc/subgid entry for ($env.USER)",   status: (if $subgid_ok  { $"(ansi green)OK(ansi reset)" } else { $"(ansi red)Missing(ansi reset)" }) }
        { name: $"network tool \(slirp4netns/pasta\)",  status: (if $network_ok { $"(ansi green)OK(ansi reset)" } else { $"(ansi red)Not found(ansi reset)" }) }
    ]

    $results | select name status | print

    if not $unshare_ok or not $subuid_ok or not $subgid_ok {
        [
            $"(ansi red)Error: User namespace mapping is not configured for ($env.USER).(ansi reset)"
            "Run:"
            $"  sudo usermod --add-subuids 10000-75535 ($env.USER)"
            $"  sudo usermod --add-subgids 10000-75535 ($env.USER)"
            "Then run: podman system migrate"
            "See: https://docs.podman.io/en/latest/markdown/podman.1.html#rootless-mode"
        ] | print --raw
    }

    if not $network_ok {
        [
            $"(ansi red)Error: No rootless network tool found. Install slirp4netns or pasta.(ansi reset)"
            "Examples:"
            "  sudo apt install slirp4netns   # Debian/Ubuntu"
            "  sudo dnf install slirp4netns   # Fedora/RHEL"
            "  sudo pacman -S passt           # Arch (provides pasta)"
            "See: https://docs.podman.io/en/latest/markdown/podman.1.html#rootless-mode"
        ] | print --raw
    }

    print $"  For troubleshooting Podman rootless, refer to the official documentation: https://docs.podman.io/en/latest/markdown/podman.1.html#rootless-mode"

    $unshare_ok and $network_ok
}

# Pre-flight check for dependencies and versions
def preflight_check [requirements: list<any>] {
    print $"(ansi yellow)» Running pre-flight checks...(ansi reset)"
    
    let results = (
        $requirements 
        | each { |req|
            let bin_path = (which $req.cmd)
            if ($bin_path | is-empty) {
                return {
                    name: $req.name
                    status: $"(ansi red)Not found(ansi reset)"
                    version: "N/A"
                    ok: false
                }
            }

            let current_version = (get_version $req.cmd)
            let is_ok = (compare_versions $current_version $req.min_version)

            {
                name: $req.name
                status: (if $is_ok { $"(ansi green)OK(ansi reset)" } else { $"(ansi red)Too old(ansi reset)" })
                version: $"($current_version) \(min: ($req.min_version)\)"
                ok: $is_ok
            }
        }
    )

    $results | select name version status | print

    if ($results | any { |it| not $it.ok }) {
        print $"\n(ansi red)Error: System requirements not met.(ansi reset)"
        return false
    }

    return true
}

# Extracts version string from various command outputs
def get_version [cmd: string] {
    let output = (
        if $cmd == "podman" {
            ^podman --version
        } else if $cmd == "nu" {
            ^nu --version
        } else if $cmd == "minijinja-cli" {
            ^minijinja-cli --version
        } else if $cmd == "git" {
            ^git --version
        } else {
            ""
        }
    )

    # Common pattern: extract the first version-like string (e.g. 1.2.3)
    let version = ($output | parse --regex '(?P<v>\d+\.\d+\.\d+)' | get v.0? | default "0.0.0")
    return $version
}

# Simple semantic version comparison (returns true if current >= min)
def compare_versions [current: string, min: string] {
    let c = ($current | split row "." | each { |it| $it | into int })
    let m = ($min | split row "." | each { |it| $it | into int })

    for i in 0..2 {
        let cv = ($c | get $i | default 0)
        let mv = ($m | get $i | default 0)
        if $cv > $mv { return true }
        if $cv < $mv { return false }
    }
    return true # Exactly equal
}

# Idempotent Directory Creation
def setup_bin_dir [bin_dir: path] {
    if not ($bin_dir | path exists) {
        print $"(ansi yellow)» Creating bin directory: ($bin_dir)(ansi reset)"
        mkdir $bin_dir
    }
}

# Wrapper Script Generation
def install_wrapper [
    target: path
    source: path
    template: path
    project_root: path
] {
    print $"(ansi yellow)» Installing agentonaut wrapper to ($target)...(ansi reset)"
    (
        ^minijinja-cli 
            --autoescape none 
            --define $"project_root=($project_root)" 
            $template
        | save --force $target
    )
    chmod +x $target
    chmod +x $source
}

# Configuration Initialization
def init_config [
    project_root: path
    user_config_dir: path
    user_config_file: path
    skel_config: path
] {
    let config_locations = [
        ($project_root | path join "config.toml")
        $user_config_file
        "/etc/agentonaut/config.toml"
    ]

    let config_found = ($config_locations | any { |p| $p | path exists })

    if not $config_found {
        print $"(ansi yellow)» No configuration found. Initializing from skeleton...(ansi reset)"
        if not ($user_config_dir | path exists) {
            mkdir $user_config_dir
        }
        cp $skel_config $user_config_file
        [
            $"(ansi green)Created: ($user_config_file)(ansi reset)"
            "Please review the configuration and adjust paths if necessary."
        ] | print --raw
    } else {
        let found_config = ($config_locations | where { |p| $p | path exists } | first)
        print $"(ansi green)» Configuration already exists: ($found_config)(ansi reset)"
    }
}

# Download nutest test framework into lib/nutest
def "main nutest" [] {
    let project_root = ($env.FILE_PWD | path expand)
    let lib_dir = ($project_root | path join "lib")
    let nutest_target = ($lib_dir | path join "nutest")

    if ($nutest_target | path exists) {
        print $"(ansi yellow)» Updating nutest at ($nutest_target)...(ansi reset)"
        rm --recursive --force $nutest_target
    } else {
        print $"(ansi yellow)» Downloading nutest...(ansi reset)"
    }

    let tmp_dir = (mktemp --directory | str trim)

    try {
        ^git clone --quiet --depth 1 "https://github.com/vyadh/nutest.git" $tmp_dir

        if not ($lib_dir | path exists) { mkdir $lib_dir }

        cp --recursive ($tmp_dir | path join "nutest") $nutest_target

        [
            $"(ansi green)nutest installed to ($nutest_target)(ansi reset)"
            "Run tests with:"
            "  bin/run-tests.nu"
        ] | print --raw
    } catch {|err|
        print $"(ansi red)Error: ($err.msg)(ansi reset)"
    }

    rm --recursive --force $tmp_dir
}

# Host Environment Setup
def run_host_setup [wrapper: path] {
    print $"(ansi yellow)» Setting up host environment...(ansi reset)"
    ^$wrapper host setup
}

# Container Network Creation
def run_network_create [wrapper: path] {
    print $"(ansi yellow)» Creating container network...(ansi reset)"
    ^$wrapper network create
}

# Upstream Containerfile Download
def run_git_download [wrapper: path] {
    print $"(ansi yellow)» Downloading upstream Containerfiles...(ansi reset)"
    try {
        ^$wrapper git download "all"
    } catch {
        print $"(ansi yellow)Warning: git download failed. Run 'agentonaut git download all' manually if needed.(ansi reset)"
    }
}

# Agent Add-On Installation
def run_agent_setup [wrapper: path] {
    print $"(ansi yellow)» Installing agent add-ons...(ansi reset)"
    for agent in ["claude" "gemini"] {
        ^$wrapper agent setup $agent
    }
}

# Return next steps message after installation
def next_steps [project_root: path] {
    [
        $"(ansi yellow_bold)Next steps:(ansi reset)"
        "  1. Build container images:           agentonaut image build by origin local"
        "  2. Launch:                           agentonaut launch ~/your-project"
        "  3. Authenticate:"
        "     Each agent runs an interactive onboarding on first launch."
        ""
        $"(ansi yellow_bold)Optional steps:(ansi reset)"
        "  1. Download documentation:           agentonaut docs download nushell"
        "  2. Index documentation:"
        "                                       agentonaut docs index all"
        "     Launch with --profile full first to start docs-mcp-server. See README.md."
        ""
        $"(ansi cyan_bold)Documentation:(ansi reset) ($project_root)/README.md"
    ]
}

# PATH Verification
def verify_path [bin_dir: path, user_config_file: path, project_root: path] {
    let path_list = ($env.PATH | split row (char esep))
    if $bin_dir not-in $path_list {
        [
            $"\n(ansi red)» Warning: ($bin_dir) is not in your PATH.(ansi reset)"
            "Add this to your shell profile:"
            $"(ansi yellow)For Bash/Zsh \(~/.bashrc or ~/.zshrc\):(ansi reset)"
            $"(ansi cyan)  export PATH=\"($bin_dir):\$PATH\"(ansi reset)"
            $"(ansi yellow)For Nushell \(~/.config/nushell/env.nu\):(ansi reset)"
            $"(ansi cyan)  $env.PATH = ($env.PATH | prepend '($bin_dir)')(ansi reset)"
            ""
        ] | print --raw
        next_steps $project_root | print --raw
    } else {
        [
            $"(ansi green)» Installation complete.(ansi reset)"
            ""
        ] | print --raw
        next_steps $project_root | print --raw
    }
}
