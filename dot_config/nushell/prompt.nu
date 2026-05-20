def host_os_name [] {
    (sys host | get name | default '')
}

def os_icon [] {
    let nu_os = ($nu.os-info.name | default '' | str downcase)
    let host_os = (host_os_name)

    if $nu_os == 'windows' {
        '󰖳'
    } else if $host_os == 'NixOS' {
        ''
    } else if ('WSL_DISTRO_NAME' in $env) and (($env.WSL_DISTRO_NAME | str downcase) | str contains 'ubuntu') {
        ''
    } else if $nu_os == 'macos' {
        '󰀵'
    } else if $nu_os == 'linux' {
        ''
    } else {
        ''
    }
}

def prompt_dir_name [] {
    let cwd = (pwd)
    let home = (
        $env.HOME?
        | default $env.USERPROFILE?
        | default ''
        | path expand
    )

    if ($home != '') and ($cwd == $home) {
        '~'
    } else {
        let base = ($cwd | path basename)
        if $base == '' { '/' } else { $base }
    }
}

def prompt_theme [] {
    {
        os_bg: 'green'
        os_fg: 'black'
        dir_bg: 'black'
        dir_fg: 'cyan'
        git_bg: 'black'
        meta: 'white'
        clean: 'green'
        modified: 'yellow'
        conflicted: 'red'
        untracked: 'cyan'
    }
}

def git_status_data [] {
    let result = (^git status --porcelain=v2 --branch | complete)
    if $result.exit_code != 0 {
        return null
    }

    mut data = {
        branch: ''
        commit: ''
        ahead: 0
        behind: 0
        staged: 0
        unstaged: 0
        conflicted: 0
        untracked: 0
    }

    for line in ($result.stdout | lines) {
        if ($line | str starts-with '# branch.head ') {
            let branch = ($line | str replace '# branch.head ' '' | str trim)
            if $branch != '(detached)' {
                $data.branch = $branch
            }
        } else if ($line | str starts-with '# branch.oid ') {
            let oid = ($line | str replace '# branch.oid ' '' | str trim)
            if $oid != '(initial)' {
                $data.commit = ($oid | str substring 0..<8)
            }
        } else if ($line | str starts-with '# branch.ab ') {
            let ab = ($line | str replace '# branch.ab ' '' | str trim)
            let parts = ($ab | split row ' ')
            for item in $parts {
                if ($item | str starts-with '+') {
                    $data.ahead = (($item | str replace '+' '') | into int)
                } else if ($item | str starts-with '-') {
                    $data.behind = (($item | str replace '-' '') | into int)
                }
            }
        } else if ($line | str starts-with '? ') {
            $data.untracked = ($data.untracked + 1)
        } else if ($line | str starts-with 'u ') {
            $data.conflicted = ($data.conflicted + 1)
        } else if ($line | str starts-with '1 ') or ($line | str starts-with '2 ') {
            let xy = ($line | split row ' ' | get 1)
            let x = ($xy | str substring 0..0)
            let y = ($xy | str substring 1..1)

            if $x != '.' {
                $data.staged = ($data.staged + 1)
            }
            if $y != '.' {
                $data.unstaged = ($data.unstaged + 1)
            }
        }
    }

    $data
}

def git_stash_count [] {
    let result = (^git stash list | complete)
    if $result.exit_code != 0 {
        0
    } else {
        ($result.stdout | lines | length)
    }
}

def git_block [] {
    let data = (git_status_data)
    if $data == null {
        return ''
    }

    let theme = (prompt_theme)
    let meta = $theme.meta
    let clean = $theme.clean
    let modified = $theme.modified
    let conflicted = $theme.conflicted
    let untracked = $theme.untracked
    let git_bg = $theme.git_bg

    let branch_part = if $data.branch != '' {
        (ansi { fg: $clean bg: $git_bg }) + $" ($data.branch)"
    } else if $data.commit != '' {
        (ansi { fg: $meta bg: $git_bg }) + ' ' + (ansi { fg: $clean bg: $git_bg }) + $data.commit
    } else {
        ''
    }

    mut details = []
    if $data.behind > 0 {
        $details = ($details | append ((ansi { fg: $clean bg: $git_bg }) + $"⇣($data.behind)"))
    }
    if $data.ahead > 0 {
        $details = ($details | append ((ansi { fg: $clean bg: $git_bg }) + $"⇡($data.ahead)"))
    }

    let stash_count = (git_stash_count)
    if $stash_count > 0 {
        $details = ($details | append ((ansi { fg: $clean bg: $git_bg }) + $"*($stash_count)"))
    }
    if $data.conflicted > 0 {
        $details = ($details | append ((ansi { fg: $conflicted bg: $git_bg }) + $"~($data.conflicted)"))
    }
    if $data.staged > 0 {
        $details = ($details | append ((ansi { fg: $modified bg: $git_bg }) + $"+($data.staged)"))
    }
    if $data.unstaged > 0 {
        $details = ($details | append ((ansi { fg: $modified bg: $git_bg }) + $"!($data.unstaged)"))
    }
    if $data.untracked > 0 {
        $details = ($details | append ((ansi { fg: $untracked bg: $git_bg }) + $"?($data.untracked)"))
    }

    let body = if (($details | length) == 0) {
        $branch_part
    } else {
        $branch_part + ' ' + ($details | str join ' ')
    }

    (ansi { fg: $clean bg: $git_bg }) + '  ' + $body
}

def format_duration [ms: int] {
    let total_seconds = ($ms // 1000)
    if $total_seconds < 3 {
        return ''
    }

    let days = ($total_seconds // 86400)
    let hours = (($total_seconds mod 86400) // 3600)
    let minutes = (($total_seconds mod 3600) // 60)
    let seconds = ($total_seconds mod 60)

    mut parts = []
    if $days > 0 {
        $parts = ($parts | append $"($days)d")
    }
    if $hours > 0 {
        $parts = ($parts | append $"($hours)h")
    }
    if $minutes > 0 {
        $parts = ($parts | append $"($minutes)m")
    }
    if $seconds > 0 or (($parts | length) == 0) {
        $parts = ($parts | append $"($seconds)s")
    }

    ($parts | str join ' ')
}

def prompt_indicator [symbol: string] {
    let theme = (prompt_theme)
    let color = if (($env.LAST_EXIT_CODE? | default 0) == 0) { $theme.clean } else { $theme.conflicted }
    (ansi { fg: $color attr: 'b' }) + $symbol + (ansi reset)
}

$env.PROMPT_COMMAND = {||
    let theme = (prompt_theme)
    let os_bg = $theme.os_bg
    let os_fg = $theme.os_fg
    let dir_bg = $theme.dir_bg
    let dir_fg = $theme.dir_fg
    let git_bg = $theme.git_bg

    let os_start = (ansi { fg: $os_bg }) + ''
    let os_body = (ansi { fg: $os_fg bg: $os_bg }) + $"(os_icon) "
    let os_sep = (ansi { fg: $os_bg bg: $dir_bg }) + ''
    let os = $os_start + $os_body + $os_sep

    let dir = (ansi { fg: $dir_fg bg: $dir_bg }) + ' 󰉋 ' + $"(prompt_dir_name) "

    let git = (git_block)

    let tail = if $git == '' {
        (ansi { fg: $dir_bg bg: 'default' }) + '' + (ansi reset)
    } else {
        let dir_sep = (ansi { fg: $dir_bg bg: $git_bg }) + ''
        let git_end = (ansi { fg: $git_bg bg: 'default' }) + ''
        $dir_sep + $git + $git_end + (ansi reset)
    }

    "\n" + $os + $dir + $tail + "\n"
}

$env.PROMPT_COMMAND_RIGHT = {||
    let duration_ms = (
        $env.CMD_DURATION_MS?
        | default '0'
        | into int
    )
    let duration = (format_duration $duration_ms)
    if $duration == '' {
        ''
    } else {
        let theme = (prompt_theme)
        (ansi { fg: $theme.clean }) + ' ' + $duration + (ansi reset)
    }
}

$env.PROMPT_INDICATOR = {|| (prompt_indicator '❯ ') }
$env.PROMPT_INDICATOR_VI_INSERT = {|| (prompt_indicator '❯ ') }
$env.PROMPT_INDICATOR_VI_NORMAL = {|| (prompt_indicator '❮ ') }
