source ($nu.config-path | path dirname | path join abbr-defs.nu)

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

def abbr-tokenize [buffer: string] {
    let chars = ($buffer | split chars)
    let len = ($chars | length)
    mut i = 0
    mut depth = 0
    mut tokens = []

    while $i < $len {
        let ch = ($chars | get $i)

        if (abbr-is-space $ch) {
            let start_depth = $depth
            mut text = ""
            while $i < $len {
                let c = ($chars | get $i)
                if not (abbr-is-space $c) {
                    break
                }
                $text = ($text + $c)
                $i = ($i + 1)
            }
            $tokens = ($tokens | append { kind: "space" text: $text depth: $start_depth })
        } else if $ch == "|" {
            $tokens = ($tokens | append { kind: "pipe" text: $ch depth: $depth })
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
                return { ok: false tokens: [] }
            }

            $tokens = ($tokens | append { kind: "quote" text: $text depth: $start_depth })
        } else if (abbr-is-open-bracket $ch) {
            $tokens = ($tokens | append { kind: "bracket" text: $ch depth: $depth })
            $depth = ($depth + 1)
            $i = ($i + 1)
        } else if (abbr-is-close-bracket $ch) {
            if $depth > 0 {
                $depth = ($depth - 1)
            }
            $tokens = ($tokens | append { kind: "bracket" text: $ch depth: $depth })
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
            $tokens = ($tokens | append { kind: "bare" text: $text depth: $start_depth })
        }
    }

    { ok: true tokens: $tokens }
}

def abbr-expand-tokens [tokens: list] {
    mut out = []
    mut expect_command = true

    for token in $tokens {
        if $token.kind == "pipe" and $token.depth == 0 {
            $out = ($out | append $token)
            $expect_command = true
        } else if $token.kind == "space" {
            $out = ($out | append $token)
        } else if $token.kind == "bare" and $token.depth == 0 and $expect_command {
            let expanded = ($ABBRS | get --optional $token.text)
            if $expanded == null {
                $out = ($out | append $token)
            } else {
                $out = ($out | append ($token | update text $expanded))
            }
            $expect_command = false
        } else {
            $out = ($out | append $token)
            if $expect_command and $token.depth == 0 {
                $expect_command = false
            }
        }
    }

    $out
}

def abbr-expand-buffer [buffer: string] {
    let parsed = (abbr-tokenize $buffer)
    if not $parsed.ok {
        return $buffer
    }

    abbr-expand-tokens $parsed.tokens | get text | str join ""
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

    commandline edit --replace --accept (abbr-expand-buffer $buffer)
}

def abbr-expand-line-or-insert-space [] {
    let buffer = (commandline)
    if (commandline get-cursor) != ($buffer | str length) {
        commandline edit --insert " "
        return
    }

    let expanded = (abbr-expand-buffer $buffer)
    if $expanded == $buffer {
        commandline edit --insert " "
    } else {
        commandline edit --replace ($expanded + " ")
    }
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
