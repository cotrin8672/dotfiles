source ($nu.config-path | path dirname | path join abbr-defs.nu)

const ABBR_SINGLE_QUOTE = "\u{27}"
const ABBR_BARE_TAIL_RE = (
    "^(?<prefix>.*[ \\t\\r\\n|\"" + $ABBR_SINGLE_QUOTE + "`{}\\[\\]\\(\\)])?"
    + "(?<text>[^ \\t\\r\\n|\"" + $ABBR_SINGLE_QUOTE + "`{}\\[\\]\\(\\)]+)$"
)

def abbr-is-space [char: string] {
    $char in [" " (char tab) (char newline) (char carriage_return)]
}

def abbr-is-quote [char: string] {
    $char in ["\"" "'" "`"]
}

def abbr-is-open-bracket [char: string] {
    $char in ["{" "[" "("]
}

def abbr-is-close-bracket [char: string] {
    $char in ["}" "]" ")"]
}

def abbr-is-bare-delimiter [char: string] {
    [
        (abbr-is-space $char)
        ($char == "|")
        (abbr-is-quote $char)
        (abbr-is-open-bracket $char)
        (abbr-is-close-bracket $char)
    ] | any { |it| $it }
}

def abbr-last-bare-candidate [buffer: string] {
    if $buffer == "" {
        return null
    }

    let matched = ($buffer | parse --regex $ABBR_BARE_TAIL_RE)
    if ($matched | is-empty) {
        return null
    }

    let row = ($matched | first)
    { text: $row.text prefix: ($row.prefix | default "") }
}

def abbr-prefix-expects-command-exact [prefix: string] {
    let chars = ($prefix | split chars)
    let len = ($chars | length)
    mut i = 0
    mut depth = 0
    mut last_top_level = ""

    while $i < $len {
        let ch = ($chars | get $i)

        if (abbr-is-space $ch) {
            $i = ($i + 1)
        } else if $ch == "|" {
            if $depth == 0 {
                $last_top_level = "pipe"
            }
            $i = ($i + 1)
        } else if (abbr-is-quote $ch) {
            let quote = $ch
            if $depth == 0 {
                $last_top_level = "other"
            }
            $i = ($i + 1)

            while $i < $len {
                let c = ($chars | get $i)
                if $quote == "\"" and $c == "\\" and ($i + 1) < $len {
                    $i = ($i + 2)
                } else if $c == $quote {
                    $i = ($i + 1)
                    break
                } else {
                    $i = ($i + 1)
                }
            }
        } else if (abbr-is-open-bracket $ch) {
            if $depth == 0 {
                $last_top_level = "other"
            }
            $depth = ($depth + 1)
            $i = ($i + 1)
        } else if (abbr-is-close-bracket $ch) {
            if $depth > 0 {
                $depth = ($depth - 1)
            }
            if $depth == 0 {
                $last_top_level = "other"
            }
            $i = ($i + 1)
        } else {
            if $depth == 0 {
                $last_top_level = "other"
            }
            while $i < $len {
                let c = ($chars | get $i)
                if (abbr-is-bare-delimiter $c) {
                    break
                }
                $i = ($i + 1)
            }
        }
    }

    $last_top_level in ["" "pipe"]
}

def abbr-prefix-expects-command [prefix: string] {
    let trimmed = ($prefix | str trim --right)
    if $trimmed == "" {
        return true
    }

    if not ($trimmed | str ends-with "|") {
        return false
    }

    let needs_exact = [
        ($trimmed | str contains "\"")
        ($trimmed | str contains "'")
        ($trimmed | str contains "`")
        ($trimmed | str contains "{")
        ($trimmed | str contains "[")
        ($trimmed | str contains "(")
        ($trimmed | str contains "}")
        ($trimmed | str contains "]")
        ($trimmed | str contains ")")
    ] | any { |it| $it }

    if not $needs_exact {
        return true
    }

    abbr-prefix-expects-command-exact $prefix
}

def abbr-expand-buffer [buffer: string] {
    let chars = ($buffer | split chars)
    let len = ($chars | length)
    mut i = 0
    mut depth = 0
    mut expect_command = true
    mut out = ""

    while $i < $len {
        let ch = ($chars | get $i)

        if (abbr-is-space $ch) {
            while $i < $len {
                let c = ($chars | get $i)
                if not (abbr-is-space $c) {
                    break
                }
                $out = ($out + $c)
                $i = ($i + 1)
            }
        } else if $ch == "|" {
            $out = ($out + $ch)
            if $depth == 0 {
                $expect_command = true
            }
            $i = ($i + 1)
        } else if (abbr-is-quote $ch) {
            let quote = $ch
            let start_depth = $depth
            mut text = $quote
            mut closed = false
            $i = ($i + 1)

            while $i < $len {
                let c = ($chars | get $i)
                $text = ($text + $c)

                if $quote == "\"" and $c == "\\" and ($i + 1) < $len {
                    $i = ($i + 1)
                    let escaped = ($chars | get $i)
                    $text = ($text + $escaped)
                } else if $c == $quote {
                    $closed = true
                    $i = ($i + 1)
                    break
                }

                $i = ($i + 1)
            }

            if not $closed {
                return $buffer
            }

            $out = ($out + $text)
            if $expect_command and $start_depth == 0 {
                $expect_command = false
            }
        } else if (abbr-is-open-bracket $ch) {
            let start_depth = $depth
            $out = ($out + $ch)
            $depth = ($depth + 1)
            if $expect_command and $start_depth == 0 {
                $expect_command = false
            }
            $i = ($i + 1)
        } else if (abbr-is-close-bracket $ch) {
            if $depth > 0 {
                $depth = ($depth - 1)
            }
            $out = ($out + $ch)
            if $expect_command and $depth == 0 {
                $expect_command = false
            }
            $i = ($i + 1)
        } else {
            let start_depth = $depth
            mut text = ""
            while $i < $len {
                let c = ($chars | get $i)
                if (abbr-is-bare-delimiter $c) {
                    break
                }
                $text = ($text + $c)
                $i = ($i + 1)
            }

            if $start_depth == 0 and $expect_command {
                let expanded = ($ABBRS | get --optional $text)
                if $expanded == null {
                    $out = ($out + $text)
                } else {
                    $out = ($out + $expanded)
                }
                $expect_command = false
            } else {
                $out = ($out + $text)
                if $expect_command and $start_depth == 0 {
                    $expect_command = false
                }
            }
        }
    }

    $out
}

def abbr-buffer-can-expand [buffer: string] {
    let candidate = (abbr-last-bare-candidate $buffer)
    if $candidate == null or ($ABBRS | get --optional $candidate.text) == null {
        return false
    }

    abbr-prefix-expects-command $candidate.prefix
}

def abbr-has-continuation-tail [buffer: string] {
    let trimmed = ($buffer | str trim)
    if $trimmed == "" {
        return false
    }

    [
        ($trimmed | str ends-with "|")
        ($trimmed | str ends-with "{")
        ($trimmed | str ends-with "[")
        ($trimmed | str ends-with "(")
    ] | any { |it| $it }
}

def abbr-should-insert-newline [buffer: string] {
    abbr-has-continuation-tail $buffer
}

def abbr-expand-line [] {
    let buffer = (commandline)
    if (commandline get-cursor) != ($buffer | str length) {
        return
    }

    commandline edit --replace (abbr-expand-buffer $buffer)
}

def abbr-expand-line-and-accept [] {
    let buffer = (commandline)
    if (abbr-should-insert-newline $buffer) {
        commandline edit --insert (char newline)
        return
    }

    if not (abbr-buffer-can-expand $buffer) {
        commandline edit --replace --accept $buffer
        return
    }

    commandline edit --replace --accept (abbr-expand-buffer $buffer)
}

def abbr-expand-line-or-insert-space [] {
    let buffer = (commandline)
    if (commandline get-cursor) != ($buffer | str length) {
        commandline edit --insert " "
        return
    }

    let candidate = (abbr-last-bare-candidate $buffer)
    let expanded = if $candidate == null {
        null
    } else {
        $ABBRS | get --optional $candidate.text
    }

    if $expanded == null or not (abbr-prefix-expects-command $candidate.prefix) {
        commandline edit --insert " "
        return
    }

    commandline edit --replace ($candidate.prefix + $expanded + " ")
}

$env.config.keybindings = (
    $env.config.keybindings
    | where name not-in [
        abbr_expand_ctrl_space
        abbr_expand_space
        abbr_expand_enter
        abbr_insert_newline_shift_alt_enter
    ]
)

$env.config.keybindings ++= [
    {
        name: abbr_expand_enter
        modifier: none
        keycode: enter
        mode: [emacs vi_insert]
        event: { send: executehostcommand cmd: "abbr-expand-line-and-accept" }
    }
    {
        name: abbr_expand_space
        modifier: none
        keycode: space
        mode: [emacs vi_insert]
        event: { send: executehostcommand cmd: "abbr-expand-line-or-insert-space" }
    }
    {
        name: abbr_insert_newline_shift_alt_enter
        modifier: shift_alt
        keycode: enter
        mode: [emacs vi_insert]
        event: { edit: insertnewline }
    }
]
