const MISE_CONFIG_NAMES = [
    ".mise.toml"
    "mise.toml"
    ".tool-versions"
    ".mise.local.toml"
    "mise.local.toml"
]
const MISE_MUTATING_COMMANDS = [
    "use"
    "unuse"
    "settings"
    "trust"
    "untrust"
    "install"
    "uninstall"
    "upgrade"
    "prune"
    "reshim"
    "plugins"
    "registry"
]

def "parse vars" [] {
    $in | from csv --noheaders --no-infer | rename op name value
}

def --env "update env" [] {
    for var in $in {
        if $var.op == "set" {
            if ($var.name | str upcase) == "PATH" {
                $env.PATH = ($var.value | split row (char esep))
            } else {
                load-env {($var.name): $var.value}
            }
        } else if $var.op == "hide" {
            hide-env $var.name
        }
    }
}

def parent-dirs [start: path] {
    mut current = ($start | path expand)
    let home = ($nu.home-dir | path expand)
    mut dirs = []

    loop {
        $dirs = ($dirs | append $current)
        if $current == $home {
            break
        }
        let parent = ($current | path dirname)
        if $parent == $current {
            break
        }
        $current = $parent
    }

    $dirs
}

def path-stamp [path: path] {
    if not ($path | path exists) {
        return $"($path)|missing"
    }

    let entry = (try { ls -a $path | first } catch { null })
    if $entry == null {
        $"($path)|unreadable"
    } else {
        $"($path)|($entry.modified? | default '')|($entry.size? | default 0)"
    }
}

def mise-config-paths [] {
    mut paths = []
    let selected_env = ($env.MISE_ENV? | default "")

    for dir in (parent-dirs $env.PWD) {
        for name in $MISE_CONFIG_NAMES {
            $paths = ($paths | append ($dir | path join $name))
        }
        if $selected_env != "" {
            $paths = ($paths | append ($dir | path join $"mise.($selected_env).toml"))
            $paths = ($paths | append ($dir | path join $".mise.($selected_env).toml"))
        }
    }

    let config_home = (
        $env.XDG_CONFIG_HOME?
        | default ($nu.home-dir | path join ".config")
        | path join "mise"
    )
    $paths = ($paths | append ($config_home | path join "config.toml"))
    $paths = ($paths | append ($nu.home-dir | path join ".tool-versions"))
    $paths = ($paths | append (try {
        glob ($config_home | path join "conf.d" "*.toml") --no-dir
    } catch {
        []
    }))

    if "MISE_CONFIG_FILE" in $env {
        $paths = ($paths | append ($env.MISE_CONFIG_FILE | path expand))
    }

    $paths | flatten | uniq | sort
}

def mise-fingerprint [] {
    let context = [
        $"PWD=($env.PWD)"
        $"MISE_ENV=($env.MISE_ENV? | default '')"
        $"MISE_CONFIG_FILE=($env.MISE_CONFIG_FILE? | default '')"
    ]
    let files = (mise-config-paths | each { |path| path-stamp $path } | to nuon)
    $context | append $files | str join (char nl)
}

def --env mise-refresh [--force] {
    let fingerprint = (mise-fingerprint)
    let unchanged = (
        not $force
        and ($env.__MISE_FINGERPRINT? | default "") == $fingerprint
    )
    if $unchanged {
        return
    }

    ^mise hook-env -s nu --quiet
        | parse vars
        | update env
    $env.__MISE_FINGERPRINT = (mise-fingerprint)
}

def --env mise-pwd-hook [] {
    mise-refresh
}

def --env mise-prompt-hook [] {
    mise-refresh
}

def --env add-hook [field: cell-path new_hook: any] {
    let field = $field | split cell-path | update optional true | into cell-path
    let old_config = $env.config? | default {}
    let old_hooks = ($old_config | get $field | default [])
    $env.config = ($old_config | upsert $field ($old_hooks ++ [$new_hook]))
}

export-env {
    $env.MISE_SHELL = "nu"
    mise-refresh --force
    if $nu.is-interactive {
        add-hook hooks.env_change.PWD {
            condition: { "MISE_SHELL" in $env }
            code: { mise-pwd-hook }
        }
        add-hook hooks.pre_prompt {
            condition: { "MISE_SHELL" in $env }
            code: { mise-prompt-hook }
        }
    }
}

export def --env --wrapped main [command?: string, --help, ...rest: string] {
    let env_commands = ["deactivate" "shell" "sh"]

    if $command == null {
        ^mise
    } else if $command == "activate" {
        $env.MISE_SHELL = "nu"
        mise-refresh --force
    } else if $command in $env_commands {
        ^mise $command ...$rest
            | parse vars
            | update env
        $env.__MISE_FINGERPRINT = (mise-fingerprint)
    } else {
        ^mise $command ...$rest
        let exit_code = ($env.LAST_EXIT_CODE? | default 0)
        if $exit_code == 0 and ($command in $MISE_MUTATING_COMMANDS) {
            mise-refresh --force
        }
    }
}
