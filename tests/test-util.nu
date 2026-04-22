const NU_LIB_DIRS = [(path self "../mod")]

use std assert
use std/testing *

use util

@test
def "sanitize path strips leading slash" [] {
    assert equal ("/workspace/my-path" | util sanitize path) "workspace-my-path"
}

@test
def "sanitize path replaces spaces and slashes with dash" [] {
    assert equal ("my path/here" | util sanitize path) "my-path-here"
}

@test
def "sanitize path collapses consecutive dashes" [] {
    assert equal ("a//b" | util sanitize path) "a-b"
}

@test
def "sanitize path trims leading and trailing dashes" [] {
    assert equal ("/trailing/" | util sanitize path) "trailing"
}

@test
def "sanitize path preserves dots and underscores" [] {
    assert equal ("my_dir/file.name" | util sanitize path) "my_dir-file.name"
}

@test
def "sanitize name lowercases input" [] {
    assert equal ("MyApp" | util sanitize name) "myapp"
}

@test
def "sanitize name replaces hyphens and specials with underscore" [] {
    assert equal ("my-app!" | util sanitize name) "my_app_"
}

@test
def "sanitize name keeps alphanumeric and underscores unchanged" [] {
    assert equal ("valid_name123" | util sanitize name) "valid_name123"
}
