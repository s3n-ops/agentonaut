const NU_LIB_DIRS = [(path self "../mod")]

use std assert
use std/testing *

use script

# Stub commands for get namespaces tests.
# "tns" has two subcommands and no direct definition, so it qualifies as a namespace.
# "tns-leaf" is a direct leaf command and must not appear.
# "tns-single" has only one subcommand and must not appear.
def "main tns sub-a" [] {}
def "main tns sub-b" [] {}
def "main tns-leaf" [] {}
def "main tns-single sub-a" [] {}

@test
def "shorten text returns short string unchanged" [] {
    assert equal (script shorten text "hello" 20) "hello"
}

@test
def "shorten text truncates to max length" [] {
    let long = (1..100 | each { "a" } | str join)
    let result = (script shorten text $long 20)
    assert equal ($result | str length) 20
}

@test
def "shorten text appends ellipsis when truncated" [] {
    let long = (1..100 | each { "a" } | str join)
    assert (script shorten text $long 20 | str ends-with "...")
}

@test
def "shorten text replaces newlines" [] {
    assert equal (script shorten text "line1\nline2" 20) "line1 line2"
}

@test
def "clean description returns first line only" [] {
    assert equal ("First line\nSecond line" | script clean description) "First line"
}

@test
def "clean description filters @example annotations" [] {
    assert equal ("Description\n@example foo { bar }" | script clean description) "Description"
}

@test
def "clean description filters Example: annotations" [] {
    assert equal ("Description\nExample: foo bar" | script clean description) "Description"
}

@test
def "clean description trims whitespace" [] {
    assert equal ("  trimmed  " | script clean description) "trimmed"
}

@test
def "clean description returns empty string for empty input" [] {
    assert equal ("" | script clean description) ""
}

@test
def "set-nested-path sets top-level key" [] {
    let result = (script set-nested-path {} ["key"] "value")
    assert equal $result.key "value"
}

@test
def "set-nested-path sets deeply nested key" [] {
    let result = (script set-nested-path {} ["a" "b" "c"] "deep")
    assert equal $result.a.b.c "deep"
}

@test
def "set-nested-path overwrites existing value" [] {
    let result = (script set-nested-path {a: {b: "old"}} ["a" "b"] "new")
    assert equal $result.a.b "new"
}

@test
def "set-nested-path preserves sibling keys" [] {
    let result = (script set-nested-path {a: {b: "keep" c: "also"}} ["a" "b"] "changed")
    assert equal $result.a.c "also"
}

@test
def "env override sets config value when env var is present" [] {
    let result = (
        with-env {TESTAPP_SECTION_KEY: "injected"} {
            script env override "testapp" "section.key"
            $env.testapp.section.key
        }
    )
    assert equal $result "injected"
}

@test
def "env override does nothing when env var is absent" [] {
    with-env {} {
        script env override "absent_app_xzqw" "section.key"
        assert (not ("absent_app_xzqw" in $env))
    }
}

@test
def "get namespaces returns namespace with two or more subcommands" [] {
    assert ("tns" in (script get namespaces))
}

@test
def "get namespaces excludes leaf commands" [] {
    assert (not ("tns-leaf" in (script get namespaces)))
}

@test
def "get namespaces excludes namespaces with fewer than two subcommands" [] {
    assert (not ("tns-single" in (script get namespaces)))
}
