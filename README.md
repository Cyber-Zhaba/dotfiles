# dotfiles

fish + tmux + neovim, ready to drop onto a fresh Linux box.

```sh
git clone https://github.com/Cyber-Zhaba/dotfiles ~/dotfiles
~/dotfiles/install.sh
```

That is the whole thing. The script installs the packages, symlinks the
configs, pulls the neovim plugins at their locked versions, patches the
terminal, and offers to switch your login shell to fish.

Re-running it is safe. A symlink that already points at the repo is left alone,
and anything real in the way is moved to `<path>.bak.<timestamp>` — nothing is
ever deleted.

## What you end up with

- **fish** with `eza`-backed `ls`, `fzf`+`bat` preview on `ff`, `zoxide`, an
  `open` that detaches, `..`/`.../....`, and `cp`/`mv` with progress bars where
  `advcpmv` exists.
- **tmux** on `Ctrl-Space`, panes on `hjkl`, and `Ctrl-h/j/k/l` that crosses
  into neovim splits without a prefix.
- **neovim** — LazyVim, plugins pinned by `lazy-lock.json` so every machine
  gets identical revisions, aether colorscheme, OSC 52 clipboard that survives
  ssh and tmux.

## Options

| Flag | Effect |
| --- | --- |
| `--no-packages` | don't touch the package manager |
| `--no-plugins` | skip `nvim --headless +Lazy! restore` |
| `--no-chsh` | never offer to change the login shell |
| `--no-terminal` | don't patch terminal configs |
| `-y`, `--yes` | assume yes (except `chsh`, which always asks) |

Migrating a machine that already has these configs? `./install.sh
--no-packages --no-plugins --no-chsh --no-terminal -y` just does the symlinks.

## Per-distro reality

`install.sh` picks the list from `/etc/os-release` first (ALT and Debian both
drive `apt-get` but need different names), then falls back to whichever manager
it finds. If a batch install fails it retries package by package and tells you
exactly which names this distro does not have.

| Distro | tmux | neovim | Checks | Needs doing by hand |
| --- | --- | --- | --- | --- |
| Arch | 3.7c | 0.12.5 | 44/44 | — |
| Debian 13 | 3.5a | 0.12.5 (tarball) | 46/46 | Nerd Font |
| Fedora 42 | 3.5a | 0.11.5 | 44/44 | `lazygit` (COPR), Nerd Font |
| ALT Linux | 3.7b | 0.11.5 | 44/44 | JetBrains Mono Nerd (`getnf`) |
| openSUSE | — | — | untested | package names are guesses |
| Alpine | — | — | untested | package names are guesses |

**Old neovim.** LazyVim needs 0.11+, and Debian stable ships 0.10.4. The script
notices and offers to drop the official tarball into `~/.local/bin`. It also
refuses to *start* a neovim below 0.11 — on an old one LazyVim does not error,
it blocks on a prompt, which under `--headless` is indistinguishable from a
hang.

**Old tmux.** Everything newer than 3.1 is behind an `if-shell` version check,
so an old tmux loads the file silently instead of complaining. You lose
`extended-keys-format` below 3.5 and `allow-passthrough` below 3.3, nothing
else.

**Nerd Fonts** are only a package on Arch. Debian and Fedora ship plain
JetBrains Mono with no icon glyphs; ALT packages FiraCode Nerd. Without one,
`eza --icons` and LazyVim's glyphs render as boxes — grab a font from
[nerdfonts.com](https://www.nerdfonts.com/) or run `getnf` on ALT.

**`Alt+Shift+Enter` not splitting?** Your terminal is sending it identically to
`Alt+Enter` under legacy key encoding. See `terminal/`.

## No package manager we know, or you'd rather do it yourself

Install these, then run `./install.sh --no-packages`:

```
fish tmux neovim git curl gcc make
eza bat fzf zoxide ripgrep fd lazygit wl-clipboard
```

`gcc`/`make` are for treesitter. Everything after `git` is optional — each
alias in `config.fish` is guarded by `command -q`, so missing tools just mean
missing aliases, not errors.

Or skip the script entirely:

```sh
ln -s ~/dotfiles/nvim                ~/.config/nvim
ln -s ~/dotfiles/tmux/tmux.conf      ~/.config/tmux/tmux.conf
ln -s ~/dotfiles/fish/config.fish    ~/.config/fish/config.fish
ln -s ~/dotfiles/fish/conf.d/*.fish  ~/.config/fish/conf.d/
cp    ~/dotfiles/fish/local.fish.example ~/.config/fish/local.fish
nvim --headless "+Lazy! restore" +qa
```

## What gets linked, and why the granularity differs

| Repo path | Lands at |
| --- | --- |
| `nvim/` | `~/.config/nvim` (whole directory) |
| `tmux/tmux.conf` | `~/.config/tmux/tmux.conf` |
| `fish/config.fish` | `~/.config/fish/config.fish` |
| `fish/conf.d/theme.fish` | `~/.config/fish/conf.d/theme.fish` |
| `fish/conf.d/compat.fish` | `~/.config/fish/conf.d/compat.fish` |
| `fish/conf.d/path.fish` | `~/.config/fish/conf.d/path.fish` |

neovim is linked as a directory on purpose: `:Lazy update` writes
`lazy-lock.json` straight into the repo, so a plugin bump is a normal git diff
you can commit and pull on the other machines.

fish is linked file by file, not as a directory, because fish writes
`fish_variables` and `funcsave` output into `~/.config/fish/` itself — linking
the directory would drag all of that into git.

`conf.d/compat.fish` aliases Debian's `batcat`/`fdfind` back to `bat`/`fd`.
`conf.d/path.fish` puts `~/.local/bin` ahead of `/usr/bin`, without which the
neovim tarball fallback installs a new binary that nothing ever launches.

## Machine-specific settings

Anything that applies to one host only — PATH entries, version managers, local
functions — goes in `~/.config/fish/local.fish`, which `config.fish` sources
last and this repo never tracks. `install.sh` seeds it from
`fish/local.fish.example` on a fresh box and never overwrites an existing one.

## Keybindings

tmux prefix is `Ctrl-Space` (`Ctrl-b` also works). **`prefix ?` prints the full
annotated list** — every binding carries a `-N` description and the popup reads
them back with `tmux list-keys -N`.

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
| `prefix c` / `prefix k` | New / kill window |
| `prefix C` / `prefix K` | New / kill session |
| `prefix q` | Reload this config |

`Ctrl-h/j/k/l` crosses the nvim boundary through `vim-tmux-navigator` on the
nvim side and an `is_vim` process check on the tmux side. neovim's own
bindings are otherwise stock LazyVim.

## Omarchy

The repo runs unchanged on Omarchy and on plain Linux; three nvim files decide
at runtime which they are on:

- `nvim/lua/plugins/theme.lua` loads Omarchy's generated theme spec when
  `~/.local/state/omarchy/current/theme/neovim.lua` exists, so
  `omarchy-theme-set` keeps working. Elsewhere it falls back to a pinned aether
  palette.
- `all-themes.lua` and `omarchy-theme-hotreload.lua` return an empty spec off
  Omarchy instead of cloning ~20 colorscheme repos.

One caveat: a future Omarchy migration could replace `theme.lua` with its own
symlink again. That only restores stock behaviour on that machine, and git will
show it.

## Tests

`tests/docker-matrix.sh` runs `install.sh` twice in a throwaway container per
distro — the second pass must move nothing aside — then asserts the bindings,
symlinks, versions and plugin state with `tests/assert-env.sh`.

```sh
tests/docker-matrix.sh              # every image
tests/docker-matrix.sh debian alt   # only matching labels
```

`tests/assert-env.sh` is safe to run on a real machine; it only reads.
