# dotfiles

Personal configuration managed with chezmoi.

## Neovim

Neovim configuration and its tests are maintained in
[nvim-config](https://github.com/cotrin8672/nvim-config).
`.chezmoiexternal.toml.tmpl` installs and updates that repository at
`~/ghq/github.com/cotrin8672/nvim-config` with a `git-repo` external.
This is the standard ghq directory. chezmoi creates links to it:

- Linux/macOS: `~/.config/nvim`
- Windows: `%LOCALAPPDATA%\nvim` and `~/.config/nvim`

On Windows, clone the repository before the first apply so the directory
link targets already exist:

```sh
ghq get cotrin8672/nvim-config
chezmoi apply
```

After that, update both repositories with:

```sh
chezmoi update
```

The external uses a one-second refresh period and `git pull --ff-only`.
Edit and commit Neovim configuration in the ghq checkout.

Inspect Neovim changes with `git status` in that repository. With chezmoi
2.72.1, `chezmoi verify` returns 1 for this `git-repo` external even when
the checkout is clean.

When migrating another existing installation, back up the old Neovim
configuration and move it out of the target path before the first apply.
The external's ghq target must be a real directory; the Neovim configuration
paths are links to that directory.

To install only the Neovim configuration on a server:

```sh
git clone https://github.com/cotrin8672/nvim-config.git ~/.config/nvim
```
