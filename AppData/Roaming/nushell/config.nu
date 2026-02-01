# config.nu
#
# Installed by:
# version = "0.103.0"
#
# This file is used to override default Nushell settings, define
# (or import) custom commands, or run any other startup tasks.
# See https://www.nushell.sh/book/configuration.html
#
# This file is loaded after env.nu and before login.nu
#
# You can open this file in your default editor using:
# config nu
#
# See `help config nu` for more options
#
# You can remove these comments if you want or leave
# them for future reference.
source ~/.cache/starship/init.nu

# use ($nu.default-config-dir | path join mise.nu)

if ('Path' in $env) {
    # Windows式の ; 区切り文字列をリストに変換
    $env.PATH = (
        $env.Path
        | str replace --all '"' ''
        | split row ';'
        | where {|p| $p != ''}
    )
    # OS 向けの文字列も同期
    $env.Path = ($env.PATH | str join ';')
}

$env.config = ($env.config | upsert hooks.env_change.PWD [
    { ||
        try { ^mise env --json | from json | reject Path | load-env }
    }
])
