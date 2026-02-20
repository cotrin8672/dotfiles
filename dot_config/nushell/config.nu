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

use ($nu.default-config-dir | path join mise.nu)
source ($nu.default-config-dir | path join prompt.nu)

if ('Path' in $env) {
    # Convert Windows ';' PATH string to Nushell PATH list.
    $env.PATH = (
        $env.Path
        | str replace --all '"' ''
        | split row ';'
        | where { |p| $p != '' }
    )
    # Keep OS-style Path in sync.
    $env.Path = ($env.PATH | str join ';')
}

$env.config.show_banner = false

