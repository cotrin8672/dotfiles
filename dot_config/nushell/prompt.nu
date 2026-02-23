def git_branch_name [] {
    let result = (^git rev-parse --abbrev-ref HEAD | complete)
    let exit_code = $result.exit_code
    if $exit_code != 0 {
        return ''
    }

    let branch = $result.stdout | str trim
    if $branch == '' or $branch == 'HEAD' {
        ''
    } else {
        $branch
    }
}

def git_status_summary [] {
    let result = (^git status --porcelain | complete)
    let exit_code = $result.exit_code
    if $exit_code != 0 {
        return ''
    }

    let entries = $result.stdout | lines
    let entry_count = ($entries | length)
    let glyph_git_clean = '✓'
    if $entry_count == 0 {
        '[' + $glyph_git_clean + '] '
    } else {
        let modified_count = ($entries | where { |x| not ($x | str starts-with '??') } | length)
        let untracked_count = ($entries | where { |x| $x | str starts-with '??' } | length)
        let modified = (if $modified_count > 0 { $"!($modified_count)" } else { '' })
        let untracked = (if $untracked_count > 0 { '?' } else { '' })
        $"[($modified)($untracked)] "
    }
}

$env.PROMPT_COMMAND = {||
    let left_cap = ''
    let os_sep = ''
    let right_cap = ''
    let os_icon = ''
    let folder_icon = ''
    let branch_icon = ''
    let branch_sep = '⟩'

    let left_cap_seg = (ansi { fg: '#8fadce' }) + $left_cap + (ansi reset)
    let os_block = (ansi { fg: '#001217' bg: '#8fadce' }) + $"($os_icon) " + (ansi reset)
    let os_sep_seg = (ansi { fg: '#8fadce' bg: '#003545' }) + $os_sep + (ansi reset)
    let dir_name = (pwd | path basename)
    let dir_block = (ansi { fg: '#8fadce' bg: '#003545' }) + $" ($folder_icon) ($dir_name) " + (ansi reset)

    let branch = (git_branch_name)
    let git_block = if $branch == '' {
        ''
    } else {
        let branch_part = (ansi { fg: '#8fadce' bg: '#003545' }) + $"($branch_sep) ($branch_icon) ($branch) " + (ansi reset)
        let status = (git_status_summary)
        let status_part = if $status == '' {
            ''
        } else {
            (ansi { fg: '#e6d5a8' bg: '#003545' }) + $status + (ansi reset)
        }
        $branch_part + $status_part
    }

    let right_cap_seg = (ansi { fg: '#003545' }) + $right_cap + (ansi reset)
    "\n" + $left_cap_seg + $os_block + $os_sep_seg + $dir_block + $git_block + $right_cap_seg + "\n"
}

$env.PROMPT_INDICATOR = {|| (ansi { fg: '#8fadce' attr: 'b' }) + ' ❯ ' + (ansi reset) }
$env.PROMPT_COMMAND_RIGHT = {|| '' }
