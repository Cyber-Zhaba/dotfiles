#!/usr/bin/env bash
# Roll out the fish + tmux + nvim environment onto a Linux box.
#
# Idempotent: existing correct symlinks are left alone, and anything real that
# sits in the way is moved to <path>.bak.<timestamp> rather than deleted.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
STAMP="$(date +%Y%m%d-%H%M%S)"
MARKER="# >>> dotfiles: CSI-u keys for tmux M-S-Enter >>>"
MARKER_END="# <<< dotfiles <<<"

# Minimums that the configs actually depend on.
NVIM_MIN=0.11.0   # LazyVim
TMUX_MIN=3.0      # if-shell guards below this get noisy

do_packages=1
do_plugins=1
do_chsh=1
do_terminal=1
assume_yes=0
notes=()

usage() {
  cat <<USAGE
usage: ./install.sh [options]

  --no-packages   skip installing distro packages
  --no-plugins    skip "nvim --headless +Lazy! restore"
  --no-chsh       never offer to change the login shell
  --no-terminal   skip patching terminal configs with CSI-u keybinds
  -y, --yes       answer yes to every prompt except chsh
  -h, --help      this text
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-packages) do_packages=0 ;;
    --no-plugins)  do_plugins=0 ;;
    --no-chsh)     do_chsh=0 ;;
    --no-terminal) do_terminal=0 ;;
    -y|--yes)      assume_yes=1 ;;
    -h|--help)     usage; exit 0 ;;
    *) printf 'unknown option: %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [[ -t 1 ]]; then
  C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_ERR=$'\033[31m'; C_DIM=$'\033[2m'; C_OFF=$'\033[0m'
else
  C_OK=; C_WARN=; C_ERR=; C_DIM=; C_OFF=
fi

trap 'printf "%s[fail]%s install.sh aborted at line %s (command: %s)\n" "$C_ERR" "$C_OFF" "$LINENO" "$BASH_COMMAND" >&2' ERR

log()  { printf '%s==>%s %s\n' "$C_OK" "$C_OFF" "$*"; }
info() { printf '    %s%s%s\n' "$C_DIM" "$*" "$C_OFF"; }
warn() { printf '%s[warn]%s %s\n' "$C_WARN" "$C_OFF" "$*" >&2; notes+=("$*"); }
die()  { printf '%s[fail]%s %s\n' "$C_ERR" "$C_OFF" "$*" >&2; exit 1; }

confirm() {
  (( assume_yes )) && return 0
  [[ -t 0 ]] || return 1        # non-interactive: decline rather than hang
  local reply
  read -rp "    $1 [y/N] " reply
  [[ $reply == [yY]* ]]
}

SUDO=""
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  elif (( do_packages )); then
    warn "not root and no sudo found -- skipping package installation"
    do_packages=0
  fi
fi

# ---------------------------------------------------------------- packages ---

# Prints "<list-name> <install-command>". os-release ID comes first because ALT
# Linux and Debian both drive apt-get but need different package names.
detect_pm() {
  local id="" id_like=""
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    id="$(. /etc/os-release && printf '%s' "${ID:-}")"
    id_like="$(. /etc/os-release && printf '%s' "${ID_LIKE:-}")"
  fi

  case "$id" in
    altlinux) printf 'apt-rpm|apt-get install -y'; return 0 ;;
  esac

  if command -v pacman  >/dev/null 2>&1; then printf 'pacman|pacman -S --needed --noconfirm'; return 0; fi
  if command -v apt-get >/dev/null 2>&1; then
    # rpm present alongside apt-get means an apt-rpm distro we did not name above
    if command -v rpm >/dev/null 2>&1 && [[ $id_like != *debian* ]]; then
      printf 'apt-rpm|apt-get install -y'; return 0
    fi
    printf 'apt|apt-get install -y --no-install-recommends'; return 0
  fi
  if command -v dnf    >/dev/null 2>&1; then printf 'dnf|dnf install -y'; return 0; fi
  if command -v zypper >/dev/null 2>&1; then printf 'zypper|zypper install -y'; return 0; fi
  if command -v apk    >/dev/null 2>&1; then printf 'apk|apk add'; return 0; fi
  return 1
}

refresh_index() {
  case "$1" in
    pacman)  $SUDO pacman -Sy --noconfirm >/dev/null ;;
    apt|apt-rpm) $SUDO apt-get update >/dev/null ;;
    apk)     $SUDO apk update >/dev/null ;;
    *)       : ;;  # dnf and zypper refresh on demand
  esac
}

install_packages() {
  local spec list cmd file pkgs=() missing=()
  if ! spec="$(detect_pm)"; then
    warn "no supported package manager found -- install the tools by hand (see README)"
    return
  fi
  list="${spec%%|*}"; cmd="${spec#*|}"
  file="$DOTFILES/packages/$list.txt"
  [[ -f $file ]] || { warn "no package list for $list"; return; }

  log "Installing packages ($list)"
  refresh_index "$list" || warn "could not refresh the $list package index"

  while IFS= read -r line; do
    line="${line%%#*}"; line="${line// /}"
    [[ -n $line ]] && pkgs+=("$line")
  done <"$file"

  # Fast path: one transaction. Most managers abort the whole batch over a
  # single unknown name, so fall back to one-by-one and report what is missing.
  if $SUDO $cmd "${pkgs[@]}" >/dev/null 2>&1; then
    info "${#pkgs[@]} packages present"
    return
  fi

  info "batch install failed, retrying package by package"
  for pkg in "${pkgs[@]}"; do
    if $SUDO $cmd "$pkg" >/dev/null 2>&1; then
      info "ok       $pkg"
    else
      missing+=("$pkg")
      printf '    %s--       %s%s\n' "$C_WARN" "$pkg" "$C_OFF"
    fi
  done
  (( ${#missing[@]} )) && warn "not available on this distro: ${missing[*]}"
  return 0
}

# ---------------------------------------------------------------- symlinks ---

link() {
  local src="$DOTFILES/$1" dest="$2" backup
  [[ -e $src ]] || { warn "missing from the repo: $1"; return; }
  mkdir -p "$(dirname "$dest")"

  if [[ -L $dest ]] && [[ "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
    info "ok       $dest"
    return
  fi

  if [[ -e $dest || -L $dest ]]; then
    backup="$dest.bak.$STAMP"
    mv "$dest" "$backup"
    warn "moved aside: $dest -> $backup"
  fi

  ln -s "$src" "$dest"
  info "linked   $dest"
}

link_all() {
  log "Linking configs"
  # nvim as a whole directory: :Lazy update then writes lazy-lock.json straight
  # into the repo, so plugin bumps show up as a normal diff.
  link nvim                   "$CONFIG/nvim"
  link tmux/tmux.conf         "$CONFIG/tmux/tmux.conf"
  # fish file by file: fish writes fish_variables and funcsave output into this
  # directory, and local.fish must stay untracked.
  link fish/config.fish       "$CONFIG/fish/config.fish"
  link fish/conf.d/theme.fish "$CONFIG/fish/conf.d/theme.fish"
  link fish/conf.d/compat.fish "$CONFIG/fish/conf.d/compat.fish"

  if [[ ! -f $CONFIG/fish/local.fish ]]; then
    cp "$DOTFILES/fish/local.fish.example" "$CONFIG/fish/local.fish"
    info "created  $CONFIG/fish/local.fish (from template)"
  else
    info "ok       $CONFIG/fish/local.fish (left alone)"
  fi
}

# ---------------------------------------------------------------- versions ---

# Try --version then -V (tmux only accepts the latter) and always succeed: a
# failing command substitution under set -e + pipefail would abort the install.
version_of() {
  local out=""
  out="$("$1" --version 2>/dev/null | head -1 || true)"
  [[ -n $out ]] || out="$("$1" -V 2>/dev/null | head -1 || true)"
  printf '%s' "$out" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || true
}

# Pad to major.minor.patch so "3.7" and "3.7.0" compare equal under sort -V.
version_norm() { awk -F. '{printf "%d.%d.%d", $1, ($2==""?0:$2), ($3==""?0:$3)}' <<<"$1"; }
version_lt() {
  local a b
  a="$(version_norm "$1")"; b="$(version_norm "$2")"
  [[ $a != "$b" && "$(printf '%s\n%s\n' "$a" "$b" | sort -V | head -1)" == "$a" ]]
}

install_nvim_tarball() {
  local asset dir
  case "$(uname -m)" in
    x86_64)  asset="nvim-linux-x86_64.tar.gz" ;;
    aarch64) asset="nvim-linux-arm64.tar.gz" ;;
    *) warn "no prebuilt neovim for $(uname -m); build from source"; return 1 ;;
  esac
  command -v curl >/dev/null 2>&1 || { warn "curl missing, cannot fetch neovim"; return 1; }

  dir="$HOME/.local/share/nvim-release"
  rm -rf "$dir"; mkdir -p "$dir" "$HOME/.local/bin"
  if ! curl -fsSL "https://github.com/neovim/neovim/releases/download/stable/$asset" \
       | tar -xz --strip-components=1 -C "$dir"; then
    warn "downloading neovim failed"
    return 1
  fi
  ln -sf "$dir/bin/nvim" "$HOME/.local/bin/nvim"
  log "Installed neovim $("$dir/bin/nvim" --version | head -1 | awk '{print $2}') to ~/.local/bin/nvim"
  info "make sure ~/.local/bin comes before /usr/bin in PATH"
  PATH="$HOME/.local/bin:$PATH"
}

check_versions() {
  log "Checking versions"
  local v

  if command -v nvim >/dev/null 2>&1; then
    v="$(version_of nvim || true)"
    if [[ -n $v ]] && version_lt "$v" "$NVIM_MIN"; then
      warn "neovim $v is older than $NVIM_MIN; LazyVim needs a newer one"
      if confirm "Install the official neovim tarball into ~/.local?"; then
        install_nvim_tarball || true
      fi
    else
      info "neovim   ${v:-unknown}"
    fi
  else
    warn "neovim not installed"
  fi

  if command -v tmux >/dev/null 2>&1; then
    v="$(version_of tmux || true)"
    if [[ -n $v ]] && version_lt "$v" "$TMUX_MIN"; then
      warn "tmux $v is very old; tmux.conf assumes $TMUX_MIN or newer"
    else
      info "tmux     ${v:-unknown}"
    fi
  else
    warn "tmux not installed"
  fi

  if command -v fish >/dev/null 2>&1; then
    info "fish     $(version_of fish || true)"
  else
    warn "fish not installed"
  fi

  local soft=()
  for t in eza bat fzf zoxide rg fd lazygit git; do
    command -v "$t" >/dev/null 2>&1 && continue
    # Debian renames two of them; compat.fish aliases the names back.
    case "$t" in
      bat) command -v batcat >/dev/null 2>&1 && continue ;;
      fd)  command -v fdfind >/dev/null 2>&1 && continue ;;
    esac
    soft+=("$t")
  done
  if (( ${#soft[@]} > 0 )); then
    warn "optional tools missing (aliases using them stay off): ${soft[*]}"
  fi
  return 0
}

# ----------------------------------------------------------------- plugins ---

install_plugins() {
  command -v nvim >/dev/null 2>&1 || { warn "skipping plugin install, no nvim"; return; }
  command -v git  >/dev/null 2>&1 || { warn "skipping plugin install, no git"; return; }
  log "Restoring nvim plugins at their locked versions"
  # restore, not sync: honour lazy-lock.json so every machine gets one set of
  # plugin revisions. Treesitter parsers need a C compiler and may fail alone.
  local out status=0
  out="$(nvim --headless "+Lazy! restore" +qa 2>&1)" || status=$?
  [[ -n $out ]] && printf '%s\n' "$out" | tail -5 | sed 's/^/    /'
  if (( status == 0 )); then
    info "done"
  else
    warn "nvim plugin restore exited $status -- open nvim and run :Lazy"
  fi
  return 0
}

# ---------------------------------------------------------------- terminal ---

patch_terminal() {
  log "Terminal CSI-u keybinds (needed for Alt+Shift+Enter splits)"
  local patched=0
  _patch() {
    local snippet="$DOTFILES/terminal/$1" target="$2"
    [[ -f $target ]] || return 0
    if grep -qF "$MARKER" "$target" 2>/dev/null; then
      info "ok       $target already patched"; patched=1; return 0
    fi
    confirm "Append CSI-u keybinds to $target?" || { info "skipped  $target"; return 0; }
    { printf '\n%s\n' "$MARKER"; cat "$snippet"; printf '%s\n' "$MARKER_END"; } >>"$target"
    info "patched  $target"
    patched=1
  }
  _patch ghostty.conf "$CONFIG/ghostty/config"
  _patch kitty.conf   "$CONFIG/kitty/kitty.conf"

  if [[ -f $CONFIG/alacritty/alacritty.toml ]]; then
    warn "alacritty: merge terminal/alacritty.toml into its [keyboard] bindings by hand (appending would break the TOML)"
    patched=1
  fi
  (( patched )) || info "no ghostty/kitty/alacritty config found -- nothing to patch"
  return 0
}

# -------------------------------------------------------------------- shell ---

maybe_chsh() {
  local fish_path
  fish_path="$(command -v fish 2>/dev/null)" || return 0
  [[ "${SHELL:-}" == "$fish_path" ]] && { info "fish is already the login shell"; return 0; }

  log "Login shell"
  if ! grep -qxF "$fish_path" /etc/shells 2>/dev/null; then
    info "$fish_path is not listed in /etc/shells"
    if confirm "Add it (needs root)?"; then
      printf '%s\n' "$fish_path" | $SUDO tee -a /etc/shells >/dev/null
    else
      warn "fish not in /etc/shells -- chsh will refuse it"
      return 0
    fi
  fi
  # Always ask, even under --yes: chsh wants a password and changes how every
  # future login behaves.
  local reply
  if [[ -t 0 ]]; then
    read -rp "    Make fish the login shell for $USER? [y/N] " reply
    [[ $reply == [yY]* ]] && { chsh -s "$fish_path" && info "login shell set to fish"; }
  else
    info "non-interactive, leaving the login shell alone (chsh -s $fish_path)"
  fi
  return 0
}

# --------------------------------------------------------------------- main ---

log "dotfiles: $DOTFILES"
if (( do_packages )); then install_packages; fi
link_all
check_versions
if (( do_plugins ));  then install_plugins;  fi
if (( do_terminal )); then patch_terminal;   fi
if (( do_chsh ));     then maybe_chsh;       fi

printf '\n'
if (( ${#notes[@]} )); then
  log "Done, with ${#notes[@]} thing(s) to look at:"
  for n in "${notes[@]}"; do printf '    - %s\n' "$n"; done
else
  log "Done. No warnings."
fi
printf '\n'
info "Machine-specific shell bits go in $CONFIG/fish/local.fish (untracked)."
info "tmux keybindings: start tmux and press Ctrl-Space ? for the full list."
