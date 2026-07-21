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

# `mise activate nu` appends its hook last. Run it once for the initial PWD,
# then remove only that pre-prompt hook; PWD changes continue to refresh mise.
let mise_pwd_hooks = ($env.config.hooks.env_change.PWD? | default [])
if (($mise_pwd_hooks | length) > 0) {
    let mise_hook = ($mise_pwd_hooks | last)
    if (do $mise_hook.condition) {
        do $mise_hook.code
    }
}
let pre_prompt_hooks = ($env.config.hooks.pre_prompt? | default [])
if (($pre_prompt_hooks | length) > 0) {
    let mise_hook_index = (($pre_prompt_hooks | length) - 1)
    $env.config = ($env.config | upsert hooks.pre_prompt ($pre_prompt_hooks | drop nth $mise_hook_index))
}

source ($nu.default-config-dir | path join prompt.nu)
source ($nu.default-config-dir | path join zoxide.nu)
source ($nu.config-path | path dirname | path join completion bat-completions.nu)
source ($nu.config-path | path dirname | path join completion cargo-completions.nu)
source ($nu.config-path | path dirname | path join completion curl-completions.nu)
source ($nu.config-path | path dirname | path join completion eza-completions.nu)
source ($nu.config-path | path dirname | path join completion gh-completions.nu)
source ($nu.config-path | path dirname | path join completion git-completions.nu)
source ($nu.config-path | path dirname | path join completion gradlew-completions.nu)
source ($nu.config-path | path dirname | path join completion pnpm-completions.nu)
source ($nu.config-path | path dirname | path join completion rg-completions.nu)
source ($nu.config-path | path dirname | path join completion rustup-completions.nu)
source ($nu.config-path | path dirname | path join completion scoop-completions.nu)
source ($nu.config-path | path dirname | path join completion ssh-completions.nu)
source ($nu.config-path | path dirname | path join completion uv-completions.nu)
source ($nu.config-path | path dirname | path join completion zoxide-completions.nu)

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

add-mason-bin-to-path

$env.config.show_banner = false
