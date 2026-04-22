const NU_LIB_DIRS = [(path self "../mod")]

use std assert
use std/testing *

use profile

@before-each
def setup [] {
    {
        profiles: {
            container: {
                gemini: {description: "Gemini container"}
                claude: {description: "Claude container"}
            }
            mcp: {
                nushell: {description: "Nushell MCP"}
            }
        }
    }
}

@test
def "convert-to-list returns all profiles as flat list" []: record -> nothing {
    let result = ($in.profiles | profile convert-to-list)
    assert equal ($result | length) 3
}

@test
def "convert-to-list adds id and type fields" []: record -> nothing {
    let result = ($in.profiles | profile convert-to-list)
    let gemini = ($result | where id == "gemini" | first)
    assert equal $gemini.id "gemini"
    assert equal $gemini.type "container"
}

@test
def "list-names returns sorted names for type" []: record -> nothing {
    assert equal ($in.profiles | profile list-names "container") ["claude" "gemini"]
}

@test
def "list-names returns empty list for unknown type" []: record -> nothing {
    assert equal ($in.profiles | profile list-names "nonexistent") []
}

@test
def "list-types returns sorted types" []: record -> nothing {
    assert equal ($in.profiles | profile list-types) ["container" "mcp"]
}

@test
def "list-by-type returns profiles of given type" []: record -> nothing {
    let result = ($in.profiles | profile list-by-type "mcp")
    assert equal ($result | length) 1
    assert equal ($result | first | get id) "nushell"
    assert equal ($result | first | get type) "mcp"
}

@test
def "list-by-type returns empty list for unknown type" []: record -> nothing {
    assert equal ($in.profiles | profile list-by-type "nonexistent") []
}

@test
def "get-nested finds profile by type and name" []: record -> nothing {
    let result = ($in.profiles | profile get-nested "container" "gemini")
    assert equal $result.id "gemini"
    assert equal $result.type "container"
}

@test
def "get-nested errors on missing profile name" []: record -> nothing {
    let ctx = $in
    assert error { $ctx.profiles | profile get-nested "container" "nonexistent" }
}

@test
def "get-nested errors on missing profile type" []: record -> nothing {
    let ctx = $in
    assert error { $ctx.profiles | profile get-nested "nonexistent" "gemini" }
}

@test
def "fetch finds profile by id and type" []: record -> nothing {
    let all = ($in.profiles | profile convert-to-list)
    let result = (profile fetch "gemini" $all "container")
    assert equal $result.id "gemini"
    assert equal $result.type "container"
}

@test
def "fetch errors when profile id not found" []: record -> nothing {
    let all = ($in.profiles | profile convert-to-list)
    assert error { profile fetch "nonexistent" $all }
}

@test
def "filter-by-type returns only matching profiles" []: record -> nothing {
    let all = ($in.profiles | profile convert-to-list)
    let result = ($all | profile filter-by-type "mcp")
    assert equal ($result | length) 1
    assert equal ($result | first | get type) "mcp"
}

@test
def "filter-by-type returns empty list when no match" []: record -> nothing {
    let all = ($in.profiles | profile convert-to-list)
    assert equal ($all | profile filter-by-type "nonexistent") []
}

#
# query
#

@test
def "query returns profiles matching field value" []: record -> nothing {
    let all = ($in.profiles | profile convert-to-list)
    let result = (profile query "type" "container" $all)
    assert equal ($result | length) 2
}

@test
def "query returns empty list when no match" []: record -> nothing {
    let all = ($in.profiles | profile convert-to-list)
    assert equal (profile query "type" "nonexistent" $all) []
}

#
# query with-repo
#

@test
def "query with-repo returns profiles that have a repo field" []: record -> nothing {
    let profiles = [
        {id: "with-repo" type: "container" repo: "my-repo"}
        {id: "no-repo" type: "container"}
    ]
    let result = (profile query with-repo $profiles)
    assert equal ($result | length) 1
    assert equal ($result | first | get id) "with-repo"
}

@test
def "query with-repo returns empty list when no profile has repo" []: record -> nothing {
    let profiles = [{id: "a" type: "container"} {id: "b" type: "agent"}]
    assert equal (profile query with-repo $profiles) []
}

#
# extract
#

@test
def "extract returns only specified fields" []: record -> nothing {
    let profile = {id: "gemini" type: "container" yaml_file: "gemini.yaml"}
    let result = (profile extract $profile "id" "type")
    assert equal $result {id: "gemini" type: "container"}
}

@test
def "extract returns null for missing fields" []: record -> nothing {
    let profile = {id: "gemini" type: "container"}
    let result = (profile extract $profile "id" "nonexistent")
    assert equal $result.nonexistent null
}

#
# fetch multiple
#

@test
def "fetch multiple returns record keyed by profile id" []: record -> nothing {
    let all = ($in.profiles | profile convert-to-list)
    let result = (profile fetch multiple ["gemini" "claude"] $all)
    assert equal ($result | columns | sort) ["claude" "gemini"]
    assert equal $result.gemini.type "container"
}

@test
def "fetch multiple errors when a profile id is not found" []: record -> nothing {
    let all = ($in.profiles | profile convert-to-list)
    assert error { profile fetch multiple ["nonexistent"] $all }
}
