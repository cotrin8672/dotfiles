# env.nu
#
# Installed by:
# version = "0.106.1"
#
# Previously, environment variables were typically configured in `env.nu`.
# In general, most configuration can and should be performed in `config.nu`
# or one of the autoload directories.
#
# This file is generated for backwards compatibility for now.
# It is loaded before config.nu and login.nu
#
# See https://www.nushell.sh/book/configuration.html
#
# Also see `help config env` for more options.
#
# You can remove these comments if you want or leave
# them for future reference.
let mise_path = $nu.default-config-dir | path join mise.nu
if not ($mise_path | path exists) {
    ^mise activate nu | save $mise_path
}
$env.PYTHONUTF8 = "1"

if $nu.os-info.name == "windows" and ("SSH_AUTH_SOCK" in $env) {
    hide-env SSH_AUTH_SOCK
}

$env.XDG_CONFIG_HOME = ($nu.home-dir | path join ".config")

def --env add-mason-bin-to-path [] {
    let mason_bin = if $nu.os-info.name == "windows" {
        let local_app_data = if ("LOCALAPPDATA" in $env) {
            $env.LOCALAPPDATA
        } else {
            $nu.home-dir | path join "AppData" "Local"
        }
        $local_app_data | path join "nvim-data" "mason" "bin"
    } else {
        let xdg_data_home = if ("XDG_DATA_HOME" in $env) {
            $env.XDG_DATA_HOME
        } else {
            $nu.home-dir | path join ".local" "share"
        }
        $xdg_data_home | path join "nvim" "mason" "bin"
    }

    if ($mason_bin | path exists) {
        let current_path = if ("PATH" in $env) {
            if (($env.PATH | describe) | str starts-with "list") {
                $env.PATH
            } else {
                $env.PATH | split row (char esep)
            }
        } else if ("Path" in $env) {
            $env.Path | split row (char esep)
        } else {
            []
        }

        let updated_path = (
            $current_path
            | where { |p| $p != "" and $p != $mason_bin }
            | prepend $mason_bin
        )
        if $nu.os-info.name == "windows" {
            $env.Path = ($updated_path | str join (char esep))
        }
        $env.PATH = $updated_path
    }
}
add-mason-bin-to-path

def nvim [...args] {
    with-env { LANG: "C" } {
        ^nvim ...$args
    }
}
