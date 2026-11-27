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
source ($nu.default-config-dir | path join zoxide.nu)
alias cd = z
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
source ($nu.config-path | path dirname | path join abbr-defs.nu)
source ($nu.config-path | path dirname | path join ssh-pick.nu)

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

def lab [project?: string] {
    let root = '\\nixos\share\julia\LLEs'
    let project = if $project != null { $project } else {
        # fzf draws on stderr when --height is set, so capture only stdout (no `complete`).
        # path join avoids `\{r}`, which fzf treats as an escaped literal brace.
        try {
            ls $root
            | where type == dir
            | get name
            | path basename
            | where $it != 'common'
            | str join "\n"
            | ^fzf --prompt 'Project> ' --height 40% --layout reverse --with-shell 'nu -n -c' --preview $"ls --short-names \('($root)' | path join '{r}'\) | select name type size modified"
            | str trim
        } catch { '' }
    }
    if ($project | is-empty) { return }

    # Kept outside chezmoi so the NAS password never reaches the dotfiles repo.
    let password = (open --raw ($nu.default-config-dir | path join nas-password) | str trim)
    let dir = $root + '\' + $project
    # Single-quoted pieces keep (tailscale ip -4) unevaluated here; each remote PC runs it.
    let ps = (
        'powershell -NoExit -Command net use \\nixos\share ' + $password + ' /user:share /persistent:no; Set-Location '
        + "'" + $dir + "'"
        + '; julia --startup-file=no --project=. --threads=auto --bind-to (tailscale ip -4)'
    )
    # i9's SSH starts in PowerShell, which would split at ; before the inner PowerShell runs.
    let ps_i9 = ($ps | str replace --all ';' '`;')

    let pane = {|name, host, cmd|
        $'            pane name="($name)" command="ssh" {
                args "-t" "($host)" r#"($cmd)"#
            }'
    }

    let top = [
        (do $pane 'Core i7-9700K (8C)' 'lab-i7-9700k-8procs' $ps)
        (do $pane 'Core i9-11900K (8C)' 'lab-i9-8procs' $ps_i9)
        (do $pane 'Ryzen 5 3600 (6C)' 'lab-ryzen5-3600-6procs' $ps)
        (do $pane 'Ryzen 5 4600G (6C)' 'lab-ryzen5-4600g-6procs' $ps)
    ] | str join "\n"
    let bottom = [
        (do $pane 'Threadripper 3970X (32C)' 'lab-threadripper-32procs' $ps)
        (do $pane 'Core i7-1165G7 (4C)' 'my-laptop' $ps)
        (do $pane 'Core i7-9700K #2 (8C)' 'lab-i7-9700k-2-8procs' $ps)
        (do $pane 'Ryzen 7 5700X (8C)' 'desktop-home' $ps)
    ] | str join "\n"

    let layout = $'layout {
    tab name="($project)" {
        pane size=1 borderless=true {
            plugin location="tab-bar"
        }
        pane split_direction="vertical" {
($top)
        }
        pane split_direction="vertical" {
($bottom)
        }
        pane size=2 borderless=true {
            plugin location="status-bar"
        }
        floating_panes {
            pane name="main" x="5%" y="5%" width="90%" height="90%" command="nu" cwd=r#"($dir)"#
        }
    }
}'
    let file = ($env.TEMP | path join $'lab-($project).kdl')
    $layout | save --force $file
    zellij attach --create $'lab-($project)' options --default-layout $file
}
