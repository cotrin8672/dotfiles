const ABBRS = {
# git
    g: "git"
    gs: "git status"
    ga: "git add"
    gaa: "git add -A"
    gc: "git commit"
    gcm: "git commit -m"
    gco: "git checkout"
# gh
    ghrc: "gh repo create"
    ghpr: "gh pr list"
    ghi: "gh issue list"

# ghq
    q: "ghq"
    qg: "ghq get"
    ql: "ghq list -p"

# chezmoi
    ch: "chezmoi"
    cha: "chezmoi apply"
    chu: "chezmoi update"
    chs: "chezmoi update; chezmoi apply"

# nvim
    n: "nvim"
    v: "nvim"
    vi: "nvim"
    nvim: "nvim"

# Misc
    wh: "which"
    sb: "sort-by"
    fr: "from csv"

# util
    fq: "ghq list -p | fzf --height 40% --reverse --prompt='repo> ' | z $in"
    fgs: "git branch --all --format='%(refname:short)' | fzf --height 40% --reverse --prompt='branch> ' --preview 'git log --oneline --decorate -graph --color=always -30 {}' | git switch $in | git fetch"
}
