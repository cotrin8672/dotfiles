def git_branch_name [] {
    let branch = (do -i { ^git rev-parse --abbrev-ref HEAD } | str trim)
    if ($branch | is-empty) or $branch == 'HEAD' {
        ''
    } else {
        $branch
    }
}

def git_status_summary [] {
    let entries = (do -i { ^git status --porcelain } | lines)
    if ($entries | is-empty) {
        '[✓] '
    } else {
        let modified_count = ($entries | where { |x| not ($x | str starts-with '??') } | length)
        let untracked_count = ($entries | where { |x| $x | str starts-with '??' } | length)
        let modified = (if $modified_count > 0 { $"!($modified_count)" } else { '' })
        let untracked = (if $untracked_count > 0 { '?' } else { '' })
        $'[($modified)($untracked)] '
    }
}

$env.PROMPT_COMMAND = {||
    let left_cap = (ansi { fg: '#8fadce' }) + '' + (ansi reset)
    let os_block = (ansi { fg: '#001217' bg: '#8fadce' }) + '󰖳 ' + (ansi reset)
    let os_sep = (ansi { fg: '#8fadce' bg: '#003545' }) + '' + (ansi reset)
    let dir_name = (pwd | path basename)
    let dir_block = (ansi { fg: '#8fadce' bg: '#003545' }) + $"  ($dir_name) " + (ansi reset)

    let branch = (git_branch_name)
    let git_block = if ($branch | is-empty) {
        ''
    } else {
        let branch_part = (ansi { fg: '#8fadce' bg: '#003545' }) + $"  ($branch) " + (ansi reset)
        let status_part = (ansi { fg: '#e6d5a8' bg: '#003545' }) + (git_status_summary) + (ansi reset)
        $branch_part + $status_part
    }

    let right_cap = (ansi { fg: '#003545' }) + '' + (ansi reset)
    "\n" + $left_cap + $os_block + $os_sep + $dir_block + $git_block + $right_cap + "\n"
}

$env.PROMPT_INDICATOR = {|| (ansi { fg: '#8fadce' attr: 'b' }) + ' ❯ ' + (ansi reset) }
$env.PROMPT_COMMAND_RIGHT = {|| '' }
