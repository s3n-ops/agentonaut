const NU_LIB_DIRS = [(path self "../mod")]

use std assert
use std/testing *

use cfg

# Shared fixture: a nested config record as produced by cfg init
@before-each
def setup [] {
    {
        config: {
            "chat.base_path": "/tmp/chat"
            "chat.history_limit": 100
            "agent.claude.id": "claude"
            "agent.claude.type": "container"
            "agent.claude.yaml_file": "claude.yaml"
            "agent.gemini.id": "gemini"
            "agent.gemini.type": "container"
            "agent.gemini.yaml_file": "gemini.yaml"
            "mcp.nushell.id": "nushell"
            "mcp.nushell.type": "mcp"
            "mcp.nushell.container": "mcp-nushell"
        }
    }
}

#
# unfold
#

@test
def "unfold flattens nested record to dot-notation" [] {
    let result = (cfg unfold {chat: {base_path: "/tmp", limit: 10}})
    assert equal $result."chat.base_path" "/tmp"
    assert equal $result."chat.limit" 10
}

@test
def "unfold sorts keys alphabetically" [] {
    let result = (cfg unfold {b: 2 a: 1})
    assert equal ($result | columns | first) "a"
}

@test
def "unfold handles list values with index keys" [] {
    let result = (cfg unfold {items: ["x" "y"]})
    assert equal $result."items.0" "x"
    assert equal $result."items.1" "y"
}

@test
def "unfold returns empty record for empty input" [] {
    assert equal (cfg unfold {}) {}
}

#
# extract
#

@test
def "extract returns exact key match" []: record -> nothing {
    let result = ($in.config | cfg extract "chat.base_path")
    assert equal $result."chat.base_path" "/tmp/chat"
}

@test
def "extract returns empty record when key not found" []: record -> nothing {
    assert equal ($in.config | cfg extract "nonexistent") {}
}

@test
def "extract with starts-with returns matching keys" []: record -> nothing {
    let result = ($in.config | cfg extract --starts-with "chat")
    assert equal ($result | columns | length) 2
}

@test
def "extract with ends-with returns matching keys" []: record -> nothing {
    let result = ($in.config | cfg extract --ends-with "yaml_file")
    assert equal ($result | columns | length) 2
}

@test
def "extract with contains returns matching keys" []: record -> nothing {
    let result = ($in.config | cfg extract --contains "claude")
    assert equal ($result | columns | length) 3
}

@test
def "extract with regex returns matching keys" []: record -> nothing {
    let result = ($in.config | cfg extract --regex '^agent\.')
    assert equal ($result | columns | length) 6
}

@test
def "extract with output-separator replaces dots in output keys" []: record -> nothing {
    let result = ($in.config | cfg extract --output-separator "_" "chat.base_path")
    assert ($result has "chat_base_path")
}

#
# extract query
#

@test
def "extract query returns all records matching field value" []: record -> nothing {
    let result = ($in.config | cfg extract query "type" "container")
    assert equal ($result | length) 2
}

@test
def "extract query returns empty list when no match" []: record -> nothing {
    assert equal ($in.config | cfg extract query "type" "nonexistent") []
}

@test
def "extract query with scope limits search to section" []: record -> nothing {
    let result = ($in.config | cfg extract query --scope "agent" "type" "container")
    assert equal ($result | length) 2
}

@test
def "extract query with starts-with matches prefix" []: record -> nothing {
    let result = ($in.config | cfg extract query --starts-with "id" "cl")
    assert equal ($result | length) 1
    assert equal ($result | first | get id) "claude"
}

@test
def "extract query result records contain sibling fields" []: record -> nothing {
    let result = ($in.config | cfg extract query "id" "gemini")
    let entry = ($result | first)
    assert equal $entry.id "gemini"
    assert equal $entry.type "container"
    assert equal $entry.yaml_file "gemini.yaml"
}

#
# extract by
#

@test
def "extract by returns first matching record" []: record -> nothing {
    let result = ($in.config | cfg extract by "id" "claude")
    assert equal $result.id "claude"
    assert equal $result.type "container"
}

@test
def "extract by errors when no match found" []: record -> nothing {
    let ctx = $in
    assert error { $ctx.config | cfg extract by "id" "nonexistent" }
}

#
# extract nested
#

@test
def "extract nested returns fields stripped of section prefix" []: record -> nothing {
    let result = ($in.config | cfg extract nested "agent" "claude")
    assert equal ($result | columns | length) 3
    assert equal $result.id "claude"
    assert equal $result.type "container"
    assert equal $result.yaml_file "claude.yaml"
}
