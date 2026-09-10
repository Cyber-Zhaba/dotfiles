# dotfiles

fish + tmux + neovim, ready to drop onto a fresh Linux box.

```sh
git clone https://github.com/<you>/dotfiles ~/dotfiles
~/dotfiles/install.sh
```

`install.sh` installs the distro packages, symlinks the configs, restores the
neovim plugins at their locked versions, patches the terminal for CSI-u keys,
and offers to make fish the login shell. Re-running it is safe: correct symlinks
are left alone and anything real in the way is moved to `<path>.bak.<timestamp>`.

Options: `--no-packages`, `--no-plugins`, `--no-chsh`, `--no-terminal`, `-y`.

## What gets linked

| Repo path | Lands at |
| --- | --- |
| `nvim/` | `~/.config/nvim` (whole directory) |
| `tmux/tmux.conf` | `~/.config/tmux/tmux.conf` |
| `fish/config.fish` | `~/.config/fish/config.fish` |
| `fish/conf.d/theme.fish` | `~/.config/fish/conf.d/theme.fish` |
| `fish/conf.d/compat.fish` | `~/.config/fish/conf.d/compat.fish` |

neovim is linked as a directory on purpose: `:Lazy update` writes
`lazy-lock.json` straight into the repo, so a plugin bump is a normal git diff.

fish is linked file by file, not as a directory, because fish writes
`fish_variables` and `funcsave` output into `~/.config/fish/` itself — linking
the directory would drag all of that into git.

## Machine-specific settings

Anything that only applies to one host — PATH entries, version managers, local
functions — goes in `~/.config/fish/local.fish`, which `config.fish` sources
last and which this repo never tracks. `install.sh` seeds it from
`fish/local.fish.example` on a fresh box.

## Keybindings

tmux prefix is `Ctrl-Space` (`Ctrl-b` also works). Press `prefix ?` for the
full annotated list — every binding carries a `-N` description, and the popup
reads them back with `tmux list-keys -N`.

The load-bearing ones:

| Key | Does |
| --- | --- |
| `Ctrl-h/j/k/l` | Move between panes **and** neovim splits, no prefix |
| `prefix h/j/k/l` | Move between panes |
| `prefix H/J/K/L` | Resize the pane by 5, repeatable |
| `Alt-Enter` / `Alt-Shift-Enter` | Split vertically / horizontally |
| `Alt-Escape` | Kill the pane |
| `Alt-1`…`Alt-9` | Jump to window N |
| `Alt-Left/Right` | Previous / next window |
| `Alt-Shift-Left/Right` | Move the window |
| `Alt-Up/Down` | Previous / next session |

`Ctrl-h/j/k/l` works across the nvim boundary through `vim-tmux-navigator` on
the nvim side and an `is_vim` process check on the tmux side; neovim's own
bindings are otherwise stock LazyVim.

`Alt-Shift-Enter` needs the terminal to send CSI-u — see `terminal/`.

## Omarchy

The repo runs unchanged on Omarchy and on plain Linux; three nvim files detect
which they are on:

- `nvim/lua/plugins/theme.lua` loads Omarchy's current generated theme spec when
  `~/.local/state/omarchy/current/theme/neovim.lua` exists, so
  `omarchy-theme-set` keeps working. Elsewhere it falls back to a pinned aether
  palette.
- `nvim/lua/plugins/all-themes.lua` and `omarchy-theme-hotreload.lua` return an
  empty spec off Omarchy instead of cloning ~20 colorscheme repos.

One caveat: a future Omarchy migration could replace `theme.lua` with its own
symlink again. That only restores the stock behaviour on that machine, and git
will show it.

## Requirements and gaps

Required: `fish`, `tmux`, `neovim` ≥ 0.11 (LazyVim), `git`, a C compiler for
treesitter. `install.sh` offers to fetch the official neovim tarball into
`~/.local` when the distro ships something older — Debian stable does.

Optional, each guarded by `command -q` in `config.fish`: `eza`, `bat`, `fzf`,
`zoxide`, `ripgrep`, `fd`, `lazygit`, `wl-clipboard`, a Nerd Font.

`acp`/`amv` (cp and mv with progress bars) come from the AUR package `advcpmv`.
`install.sh` does not touch the AUR, and the aliases stay off without them.

Package lists live in `packages/<manager>.txt`. pacman, apt, apt-rpm (ALT) and
dnf are tested in containers (`tests/docker-matrix.sh`); zypper and apk are
best-guess name lists.
