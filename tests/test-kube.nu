const NU_LIB_DIRS = [(path self "../mod")]

use std assert
use std/testing *

use podman/kube

# Minimal kube config fixture with two containers and two volumes
@before-each
def setup [] {
    {
        config: {
            spec: {
                containers: [
                    {
                        name: "app"
                        image: "localhost/app:latest"
                        volumeMounts: [
                            {name: "workspace" mountPath: "/workspace"}
                            {name: "data" mountPath: "/data"}
                        ]
                        env: [
                            {name: "CLAUDE_WORKSPACE" value: "/workspace"}
                            {name: "OTHER_VAR" value: "unchanged"}
                        ]
                    }
                    {
                        name: "sidecar"
                        image: "localhost/sidecar:latest"
                        volumeMounts: [
                            {name: "workspace" mountPath: "/workspace"}
                        ]
                        env: []
                    }
                ]
                volumes: [
                    {name: "workspace" hostPath: {path: "/old/workspace"}}
                    {name: "data" hostPath: {path: "/old/data"}}
                ]
            }
        }
    }
}

#
# update container
#

@test
def "update container merges updates into matching container" []: record -> nothing {
    let result = ($in.config | kube update container "app" {image: "localhost/app:v2"})
    let app = ($result.spec.containers | where name == "app" | first)
    assert equal $app.image "localhost/app:v2"
}

@test
def "update container leaves other containers unchanged" []: record -> nothing {
    let result = ($in.config | kube update container "app" {image: "new"})
    let sidecar = ($result.spec.containers | where name == "sidecar" | first)
    assert equal $sidecar.image "localhost/sidecar:latest"
}

@test
def "update container errors when container name not found" []: record -> nothing {
    let ctx = $in
    assert error { $ctx.config | kube update container "nonexistent" {image: "x"} }
}

#
# update volumes
#

@test
def "update volumes sets hostPath by index" []: record -> nothing {
    let result = ($in.config | kube update volumes {"0": "/new/workspace"})
    assert equal ($result.spec.volumes | get 0 | get hostPath.path) "/new/workspace"
}

@test
def "update volumes leaves unspecified volumes unchanged" []: record -> nothing {
    let result = ($in.config | kube update volumes {"0": "/new/workspace"})
    assert equal ($result.spec.volumes | get 1 | get hostPath.path) "/old/data"
}

#
# update volumes by name
#

@test
def "update volumes by name sets hostPath by volume name" []: record -> nothing {
    let result = ($in.config | kube update volumes by name {workspace: "/new/workspace"})
    let ws = ($result.spec.volumes | where name == "workspace" | first)
    assert equal $ws.hostPath.path "/new/workspace"
}

@test
def "update volumes by name leaves unmatched volumes unchanged" []: record -> nothing {
    let result = ($in.config | kube update volumes by name {workspace: "/new"})
    let data = ($result.spec.volumes | where name == "data" | first)
    assert equal $data.hostPath.path "/old/data"
}

#
# update workspace
#

@test
def "update workspace updates volumeMount mountPath for workspace volume" []: record -> nothing {
    let result = ($in.config | kube update workspace "/workspace/my-project")
    let app = ($result.spec.containers | where name == "app" | first)
    let ws_mount = ($app.volumeMounts | where name == "workspace" | first)
    assert equal $ws_mount.mountPath "/workspace/my-project"
}

@test
def "update workspace updates CLAUDE_WORKSPACE env var" []: record -> nothing {
    let result = ($in.config | kube update workspace "/workspace/my-project")
    let app = ($result.spec.containers | where name == "app" | first)
    let env_var = ($app.env | where name == "CLAUDE_WORKSPACE" | first)
    assert equal $env_var.value "/workspace/my-project"
}

@test
def "update workspace leaves other env vars unchanged" []: record -> nothing {
    let result = ($in.config | kube update workspace "/workspace/my-project")
    let app = ($result.spec.containers | where name == "app" | first)
    let other = ($app.env | where name == "OTHER_VAR" | first)
    assert equal $other.value "unchanged"
}

@test
def "update workspace updates all containers" []: record -> nothing {
    let result = ($in.config | kube update workspace "/workspace/my-project")
    let sidecar = ($result.spec.containers | where name == "sidecar" | first)
    let ws_mount = ($sidecar.volumeMounts | where name == "workspace" | first)
    assert equal $ws_mount.mountPath "/workspace/my-project"
}
