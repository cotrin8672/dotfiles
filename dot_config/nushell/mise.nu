const MISE_CONFIG_NAMES = [
    ".mise.toml"
    "mise.toml"
    ".tool-versions"
    ".mise.local.toml"
    "mise.local.toml"
    ".miserc.toml"
]
const MISE_CONFIG_DIRS = ["mise" ".mise" ".config/mise"]
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
            if ($var.name | str uppercase) == "PATH" {
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

def mise-glob [pattern: string] {
    # Nu's glob patterns need forward slashes, including on Windows.
    try { glob ($pattern | str replace --all '\' '/') --no-dir } catch { [] }
}

def mise-config-paths [] {
    mut paths = []
    let selected_env = ($env.MISE_ENV? | default "")

    for dir in (parent-dirs $env.PWD) {
        for name in $MISE_CONFIG_NAMES {
            $paths = ($paths | append ($dir | path join $name))
        }
        for selected in ($selected_env | split row "," | where { $in != "" }) {
            for prefix in ["mise" ".mise" ".config/mise"] {
                $paths = ($paths | append ($dir | path join $"($prefix).($selected).toml"))
                $paths = ($paths | append ($dir | path join $"($prefix).($selected).local.toml"))
            }
        }
        for config_dir in $MISE_CONFIG_DIRS {
            let root = ($dir | path join $config_dir)
            if ($root | path exists) {
                $paths = ($paths | append (mise-glob ($root | path join "*.toml")))
                $paths = ($paths | append (mise-glob ($root | path join "conf.d" "**" "*.toml")))
            }
        }
        let xdg_mise = ($dir | path join ".config" "mise.toml")
        $paths = ($paths | append $xdg_mise | append ($dir | path join ".config" "mise.local.toml"))
    }

    let config_home = (
        $env.XDG_CONFIG_HOME?
        | default ($nu.home-dir | path join ".config")
        | path join "mise"
    )
    $paths = ($paths | append (mise-glob ($config_home | path join "*.toml")))
    $paths = ($paths | append ($nu.home-dir | path join ".tool-versions"))
    $paths = ($paths | append (mise-glob ($config_home | path join "conf.d" "**" "*.toml")))

    for key in ["MISE_CONFIG_FILE" "MISE_GLOBAL_CONFIG_FILE" "MISE_SYSTEM_CONFIG_FILE"] {
        if $key in $env {
            $paths = ($paths | append ($env | get $key | path expand))
        }
    }

    $paths | flatten | uniq | where { |path| $path | path exists } | sort
}

def mise-needs-pwd [paths: list<string>] {
    # Keep directory-sensitive configs on the original refresh path. Inspect
    # only after a refresh, so ordinary prompts do not reparse TOML files.
    $paths | any { |path|
        let name = ($path | path basename)
        if $name == ".tool-versions" {
            false
        } else if $name in [".miserc.toml" "miserc.toml"] {
            true
        } else {
            try {
                let config = (open --raw $path | from toml)
                let settings = ($config.settings? | default {} | columns)
                (
                    (["env" "hooks" "watch_files" "daemons"] | any { |key| $key in $config })
                    or (["auto_env" "idiomatic_version_file_enable_tools" "override_config_filenames" "override_tool_versions_filenames"] | any { |key| $key in $settings })
                    or (($config | reject --optional tasks | to nuon) =~ '(?i)\b(PWD|cwd)\b')
                )
            } catch {
                true
            }
        }
    }
}

def mise-fingerprint [] {
    let custom_discovery = (["MISE_OVERRIDE_CONFIG_FILENAMES" "MISE_OVERRIDE_TOOL_VERSIONS_FILENAMES" "MISE_IDIOMATIC_VERSION_FILE_ENABLE_TOOLS" "MISE_AUTO_ENV"] | any { |key| $key in $env })
    let context = [
        (if $custom_discovery or ($env.__MISE_NEEDS_PWD? | default true | into bool) { $"PWD=($env.PWD)" } else { "" })
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
    $env.__MISE_NEEDS_PWD = (mise-needs-pwd (mise-config-paths))
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
        $env.__MISE_NEEDS_PWD = (mise-needs-pwd (mise-config-paths))
        $env.__MISE_FINGERPRINT = (mise-fingerprint)
    } else {
        ^mise $command ...$rest
        let exit_code = ($env.LAST_EXIT_CODE? | default 0)
        if $exit_code == 0 and ($command in $MISE_MUTATING_COMMANDS) {
            mise-refresh --force
        }
    }
}
