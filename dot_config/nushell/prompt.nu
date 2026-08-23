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
        os_bg: "#5ea1ff"
        os_fg: "#16181a"
        dir_bg: "#3c4048"
        dir_fg: "#5ef1ff"
        git_bg: "#3c4048"
        meta: "#ffffff"
        prompt: "#5ea1ff"
        clean: "#5eff6c"
        modified: "#f1ff5e"
        conflicted: "#ff6e5e"
        untracked: "#5ef1ff"
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

def git-repo-root [] {
    for dir in (parent-dirs (pwd | path expand)) {
        if ($dir | path join ".git" | path exists) {
            return $dir
        }
    }

    null
}

def git-dir [repo_root: path] {
    let dot_git = ($repo_root | path join ".git")
    if not ($dot_git | path exists) {
        return null
    }

    if ($dot_git | path type) == "dir" {
        return $dot_git
    }

    let content = (try { open -r $dot_git | lines | first | default "" } catch { "" })
    if ($content | str starts-with "gitdir: ") {
        ($content | str replace "gitdir: " "" | str trim | path expand)
    } else {
        null
    }
}

def git-metadata-paths [repo_root: path] {
    let git_dir = (git-dir $repo_root)
    if $git_dir == null {
        return []
    }

    mut paths = [
        ($git_dir | path join "HEAD")
        ($git_dir | path join "index")
        ($git_dir | path join "MERGE_HEAD")
        ($git_dir | path join "CHERRY_PICK_HEAD")
        ($git_dir | path join "REBASE_HEAD")
        ($git_dir | path join "ORIG_HEAD")
        ($git_dir | path join "FETCH_HEAD")
        ($git_dir | path join "packed-refs")
        ($git_dir | path join "logs/refs/stash")
        ($git_dir | path join "rebase-merge")
        ($git_dir | path join "rebase-apply")
    ]

    let origin = ($git_dir | path join "refs/remotes/origin")
    if ($origin | path exists) {
        let origin_refs = (try { glob ($origin | path join "*") --no-dir } catch { [] })
        $paths = ($paths | append $origin_refs)
    }

    $paths | uniq | sort
}

def git-fingerprint [repo_root: path] {
    (git-metadata-paths $repo_root | each { |path| path-stamp $path } | str join (char nl))
}

def git-parse-status-output [stdout: string] {
    mut data = {
        branch: ''
        commit: ''
        ahead: 0
        behind: 0
        stash: 0
        staged: 0
        unstaged: 0
        conflicted: 0
        untracked: 0
    }

    for line in ($stdout | lines) {
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
        } else if ($line | str starts-with '# stash ') {
            $data.stash = (($line | str replace '# stash ' '' | str trim) | into int)
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

def git-prompt-cache-path [] {
    ($nu.cache-dir | path join "git-prompt-cache.nuon")
}

def git-prompt-cache-read [] {
    let path = (git-prompt-cache-path)
    if not ($path | path exists) {
        return null
    }

    try {
        open $path
    } catch {
        null
    }
}

def git-prompt-cache-write [entry: record] {
    mkdir $nu.cache-dir
    $entry | to nuon | save -f (git-prompt-cache-path)
}

def git-prompt-cache-clear [] {
    let path = (git-prompt-cache-path)
    if ($path | path exists) {
        rm $path
    }
}

def git-fetch-status-data [] {
    let result = (^git status --porcelain=v2 --branch --show-stash | complete)
    if $result.exit_code != 0 {
        return null
    }

    git-parse-status-output $result.stdout
}

def git_status_data [] {
    let repo_root = (git-repo-root)
    if $repo_root == null {
        git-prompt-cache-clear
        return null
    }

    let repo_key = ($repo_root | into string)
    let fingerprint = (git-fingerprint $repo_root)
    let cached = (git-prompt-cache-read)
    if ($cached != null) and ($cached.repo_root == $repo_key) and ($cached.fingerprint == $fingerprint) {
        return $cached.data
    }

    let data = (git-fetch-status-data)
    if $data != null {
        git-prompt-cache-write {
            repo_root: $repo_key
            fingerprint: $fingerprint
            data: $data
        }
    }
    $data
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
    if $data.stash > 0 {
        $details = ($details | append ((ansi { fg: $clean bg: $git_bg }) + $"*($data.stash)"))
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
    let color = if (($env.LAST_EXIT_CODE? | default 0) == 0) { $theme.prompt } else { $theme.conflicted }
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
