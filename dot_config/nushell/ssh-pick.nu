# Pick a tailnet host with fzf and SSH into it.
# Users and keys for each host come from ~/.config/ssh/config.
def ssh-pick [] {
    # Concrete host names from `Host` lines; wildcard patterns and github.com are not login targets.
    let hosts = (
        open --raw ~/.config/ssh/config
        | lines
        | str trim
        | where $it starts-with 'Host '
        | each { split row -r '\s+' | skip 1 }
        | flatten
        | uniq
        | where {|h| $h !~ '[*?]' and $h != 'github.com' }
    )
    # Capture only stdout: fzf draws its UI on stderr when --height is set.
    let host = try {
        $hosts | str join "\n" | ^fzf --prompt 'SSH> ' --height 40% --layout reverse | str trim
    } catch { '' }
    if ($host | is-empty) { return }

    # SSH key logins don't carry NAS credentials, so authenticate to the share on arrival.
    # Kept as one command without `;` so it works whether the remote's first shell is cmd or PowerShell.
    let password = (open --raw ($nu.default-config-dir | path join nas-password) | str trim)
    ^ssh -t $host $'powershell -NoExit -Command net use \\nixos\share ($password) /user:share /persistent:no'
}
