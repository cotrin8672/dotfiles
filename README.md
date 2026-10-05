# dotfiles

Personal configuration managed with chezmoi.

## Neovim

Neovim configuration and its tests are maintained in
[nvim-config](https://github.com/cotrin8672/nvim-config).
`.chezmoiexternal.toml.tmpl` installs and updates that repository with a
`git-repo` external:

- Linux/macOS: `~/.config/nvim`
- Windows: `%LOCALAPPDATA%\nvim`

```sh
chezmoi update
```

The external uses a one-second refresh period and `git pull --ff-only`.
Edit and commit Neovim configuration in its own repository.

Inspect Neovim changes with `git status` in that repository. With chezmoi
2.72.1, `chezmoi verify` returns 1 for this `git-repo` external even when
the checkout is clean.

When migrating another existing installation, back up the old Neovim
configuration and remove it from the target path before the first apply.
Also move any ignored files left in `dot_config/nvim` out of the chezmoi
source directory. On Windows, the external's target must be a real
directory. Replace an old `%LOCALAPPDATA%\nvim` junction with the repository
directory; `~/.config/nvim` can point to that directory instead.

To install only the Neovim configuration on a server:

```sh
git clone https://github.com/cotrin8672/nvim-config.git ~/.config/nvim
```
