# Run from the repository root: nu -n -c 'source tests/nushell_mise.nu'
use std/assert
source ../dot_config/nushell/mise.nu

let original_pwd = $env.PWD
let fixture = (mktemp -d | path expand)
assert equal ($fixture | path dirname) ($env.TEMP | path expand)
mkdir ($fixture | path join a) ($fixture | path join b)
let config = ($fixture | path join mise.toml)
let failure = (try {
    $env.__MISE_NEEDS_PWD = false
    cd ($fixture | path join a)
    let baseline = (mise-fingerprint)
    cd ($fixture | path join b)
    assert equal (mise-fingerprint) $baseline "Plain cd must not invalidate the environment"

    "[tools]\nnode = '22'\n" | save $config
    assert (not (mise-needs-pwd [$config])) "Static tools must allow reuse across directories"
    let project = (mise-fingerprint)
    assert ($project != $baseline) "A newly created project config must invalidate the environment"
    cd ($fixture | path join a)
    assert equal (mise-fingerprint) $project "Sibling directories inherit the same config"

    mkdir ($fixture | path join a .mise)
    let nested = ($fixture | path join a .mise config.toml)
    "[tools]\nnode = '20'\n" | save $nested
    assert ((mise-fingerprint) != $project) "Nested config locations must be detected"
    rm $nested
    assert equal (mise-fingerprint) $project "Removing a config must restore the inherited environment"

    "[tools]\nnode = '24'\npython = '3.13'\n" | save -f $config
    assert ((mise-fingerprint) != $project) "Config edits must invalidate the environment"
    rm $config
    assert equal (mise-fingerprint) $baseline "Removed project configs must be detected"

    for content in [
        "[env]\nTEST_PWD = '{{ cwd }}'\n"
        "[hooks]\ncd = 'echo changed'\n"
        "[tools]\nnode = '{{ env.PWD }}'\n"
        "[settings]\nidiomatic_version_file_enable_tools = ['node']\n"
    ] {
        $content | save -f $config
        assert (mise-needs-pwd [$config]) "Directory-sensitive configs must keep refreshing on cd"
    }
    $env.__MISE_NEEDS_PWD = true
    let sensitive = (mise-fingerprint)
    cd ($fixture | path join b)
    assert ((mise-fingerprint) != $sensitive) "PWD-sensitive environments must refresh between siblings"

    # Verify actual hook-env output is applied, without the user's global tools.
    $env.MISE_IGNORED_CONFIG_PATHS = ($nu.home-dir | path join .config mise)
    $env.MISE_TRUSTED_CONFIG_PATHS = $fixture
    "[env]\nMISE_FINGERPRINT_TEST = '{{ cwd }}'\n" | save -f $config
    mise-refresh --force
    assert equal ($env.MISE_FINGERPRINT_TEST | path expand) $env.PWD
    cd ($fixture | path join a)
    mise-refresh
    assert equal ($env.MISE_FINGERPRINT_TEST | path expand) $env.PWD "PWD-dependent env must update after cd"
    "[env]\nMISE_FINGERPRINT_TEST = 'updated'\n" | save -f $config
    mise-refresh
    assert equal $env.MISE_FINGERPRINT_TEST 'updated' "Edited env must be applied immediately"
    rm $config
    mise-refresh
    assert ("MISE_FINGERPRINT_TEST" not-in $env) "Deleted env must be removed"
    null
} catch { |err| $err })

cd $original_pwd
# This absolute directory was just created by mktemp and checked against TEMP.
rm -r $fixture
if $failure != null { error make $failure }
print 'NUSHELL_MISE_OK'
