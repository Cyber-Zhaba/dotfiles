#!/usr/bin/env bash
# Assertions run inside a freshly provisioned container. Exits non-zero if any
# check fails. Safe to run on a real machine too -- it only reads.
set -uo pipefail

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
DOTFILES="${DOTFILES:-$HOME/dotfiles}"

# conf.d/path.fish prepends this for fish; mirror it so these checks exercise
# the binaries a real session gets rather than whatever /usr/bin holds.
[ -d "$HOME/.local/bin" ] && PATH="$HOME/.local/bin:$PATH"

# Any nvim invocation here could meet a blocking prompt (LazyVim on a too-old
# neovim does exactly that), which in --headless is indistinguishable from a
# hang. Cap every one of them -- resolving the binary up front, because timeout
# execs a program and so cannot run the `command` builtin.
NVIM_BIN="$(command -v nvim 2>/dev/null || true)"
if [ -n "$NVIM_BIN" ]; then
  nvim() { timeout 300 "$NVIM_BIN" "$@" </dev/null; }
fi
pass=0
fail=0

ok()   { printf '  PASS  %s\n' "$1"; pass=$((pass + 1)); }
no()   { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }
check() { if eval "$2" >/dev/null 2>&1; then ok "$1"; else no "$1"; fi; }

printf '\n--- symlinks ---\n'
check "nvim  -> repo"            '[ "$(readlink -f "$CONFIG/nvim")" = "$(readlink -f "$DOTFILES/nvim")" ]'
check "tmux.conf -> repo"        '[ "$(readlink -f "$CONFIG/tmux/tmux.conf")" = "$(readlink -f "$DOTFILES/tmux/tmux.conf")" ]'
check "config.fish -> repo"      '[ "$(readlink -f "$CONFIG/fish/config.fish")" = "$(readlink -f "$DOTFILES/fish/config.fish")" ]'
check "theme.fish -> repo"       '[ "$(readlink -f "$CONFIG/fish/conf.d/theme.fish")" = "$(readlink -f "$DOTFILES/fish/conf.d/theme.fish")" ]'
check "local.fish is a real file, not a link" '[ -f "$CONFIG/fish/local.fish" ] && [ ! -L "$CONFIG/fish/local.fish" ]'

printf '\n--- tmux ---\n'
if command -v tmux >/dev/null 2>&1; then
  printf '  info  %s\n' "$(tmux -V)"
  rm -f /tmp/tmux-err
  TMUX_TMPDIR=/tmp tmux -f "$CONFIG/tmux/tmux.conf" new-session -d -s probe 2>/tmp/tmux-err
  started=$?
  check "server starts"                   "[ $started -eq 0 ]"
  if [ -s /tmp/tmux-err ]; then
    no "config loads without errors"
    sed 's/^/        /' /tmp/tmux-err
  else
    ok "config loads without errors"
  fi

  if [ $started -eq 0 ]; then
    TMUX_TMPDIR=/tmp tmux list-keys    >/tmp/keys-all  2>/dev/null
    TMUX_TMPDIR=/tmp tmux list-keys -N >/tmp/keys-desc 2>/dev/null

    check "C-h is bound in the root table (nvim-aware pane focus)" 'grep -qE "^bind-key +-T root +C-h " /tmp/keys-all'
    check "C-l is bound in the root table"                         'grep -qE "^bind-key +-T root +C-l " /tmp/keys-all'
    check "C-h forwards to vim via is_vim"                         'grep -E "^bind-key +-T root +C-h " /tmp/keys-all | grep -q "send-keys C-h"'
    check "M-Enter splits vertically"                              'grep -E "^bind-key +-T root +M-Enter " /tmp/keys-all | grep -q "split-window -v"'
    check "M-S-Enter splits horizontally"                          'grep -E "^bind-key +-T root +M-S-Enter " /tmp/keys-all | grep -q "split-window -h"'
    check "M-Escape kills the pane"                                'grep -E "^bind-key +-T root +M-Escape " /tmp/keys-all | grep -q kill-pane'
    check "prefix h selects the left pane"                         'grep -E "^bind-key +-T prefix +h " /tmp/keys-all | grep -q "select-pane -L"'
    check "prefix L resizes right"                                 'grep -E "^bind-key +-r +-T prefix +L " /tmp/keys-all | grep -q "resize-pane -R"'
    check "prefix ? shows the keybinding list"                     'grep -qE "^bind-key +-T prefix +\? " /tmp/keys-all'
    check "M-1 selects window 1"                                   'grep -qE "^bind-key +-T root +M-1 " /tmp/keys-all'
    check "bindings carry -N descriptions"                         'grep -q "Focus pane left (nvim aware)" /tmp/keys-desc'
    check "copy-mode-vi y copies"                                  'grep -E "copy-mode-vi +y " /tmp/keys-all | grep -q copy-selection'

    check "prefix is C-Space"   '[ "$(TMUX_TMPDIR=/tmp tmux show -gv prefix)" = C-Space ]'
    check "base-index is 1"     '[ "$(TMUX_TMPDIR=/tmp tmux show -gv base-index)" = 1 ]'
    check "mouse is on"         '[ "$(TMUX_TMPDIR=/tmp tmux show -gv mouse)" = on ]'
    check "status is on top"    '[ "$(TMUX_TMPDIR=/tmp tmux show -gv status-position)" = top ]'
    # Version-guarded options: assert only where the running tmux supports them.
    tv="$(tmux -V | tr -dc '0-9.' | cut -d. -f1-2 | tr -d .)"
    if [ "${tv:-0}" -ge 32 ]; then
      check "extended-keys on (tmux >= 3.2)" '[ "$(TMUX_TMPDIR=/tmp tmux show -gv extended-keys)" = on ]'
      check "clipboard terminal-feature set" 'TMUX_TMPDIR=/tmp tmux show -gv terminal-features | grep -q clipboard'
    fi
    if [ "${tv:-0}" -ge 35 ]; then
      check "extended-keys-format csi-u (tmux >= 3.5)" '[ "$(TMUX_TMPDIR=/tmp tmux show -gv extended-keys-format)" = csi-u ]'
    fi
    TMUX_TMPDIR=/tmp tmux kill-server 2>/dev/null
  fi
else
  no "tmux installed"
fi

printf '\n--- neovim ---\n'
if [ -n "$NVIM_BIN" ]; then
  printf '  info  %s\n' "$(nvim --version | head -1)"
  nv="$(nvim --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  check "neovim on PATH is at least 0.11 (LazyVim requires it)" \
    '[ "$(printf "0.11.0\n%s\n" "$nv" | sort -V | head -1)" = "0.11.0" ]'
  nvim --headless -c 'qa' >/tmp/nvim-out 2>&1; nvim_status=$?
  check "starts and exits cleanly"  '[ "$nvim_status" -eq 0 ]'
  if sed 's/\x1b\[[0-9;]*m//g' /tmp/nvim-out | grep -qE '(^|[[:space:]])E[0-9]{1,4}:|Error executing|stack traceback'; then
    no "startup produces no errors"
    sed 's/^/        /' /tmp/nvim-out | head -20
  else
    ok "startup produces no errors"
  fi

  # theme.lua resolution, evaluated directly so it does not need plugins on disk
  nvim --headless \
    -c 'lua local s = dofile(vim.fn.stdpath("config") .. "/lua/plugins/theme.lua"); io.write("SPECS=" .. #s .. "\n"); for _, p in ipairs(s) do if p.opts and p.opts.colorscheme then io.write("SCHEME=" .. p.opts.colorscheme .. "\n") end end' \
    -c 'qa' >/tmp/theme-out 2>&1
  check "theme.lua returns a spec"            'grep -q "SPECS=2" /tmp/theme-out'
  check "theme.lua picks a colorscheme"       'grep -q "SCHEME=" /tmp/theme-out'

  if [ -d "$HOME/.local/state/omarchy" ] || [ -d "$HOME/.local/share/omarchy" ]; then
    printf '  info  %s\n' "Omarchy detected -- all-themes.lua is expected to be populated"
  else
    nvim --headless \
      -c 'lua local s = dofile(vim.fn.stdpath("config") .. "/lua/plugins/all-themes.lua"); io.write("N=" .. #s .. "\n")' \
      -c 'qa' >/tmp/allthemes-out 2>&1
    check "all-themes.lua is empty off Omarchy"     'grep -q "N=0" /tmp/allthemes-out'
    nvim --headless \
      -c 'lua local s = dofile(vim.fn.stdpath("config") .. "/lua/plugins/omarchy-theme-hotreload.lua"); io.write("N=" .. #s .. "\n")' \
      -c 'qa' >/tmp/hotreload-out 2>&1
    check "theme-hotreload is empty off Omarchy"    'grep -q "N=0" /tmp/hotreload-out'
  fi

  check "remote_clipboard module loads" 'nvim --headless -c "lua require(\"config.remote_clipboard\")" -c qa'

  if [ -d "$HOME/.local/share/nvim/lazy/LazyVim" ]; then
    ok "LazyVim is installed"
    scheme="$(nvim --headless -c 'lua io.write("CS=" .. tostring(vim.g.colors_name) .. "\n")' -c 'qa' 2>&1 | grep -o 'CS=[A-Za-z0-9_-]*')"
    printf '  info  colorscheme %s\n' "${scheme:-unreported}"
    check "vim-tmux-navigator installed" '[ -d "$HOME/.local/share/nvim/lazy/vim-tmux-navigator" ]'
    check "aether (or an Omarchy theme) is on disk" 'ls -d "$HOME/.local/share/nvim/lazy/"*ether* >/dev/null 2>&1 || ls -d "$HOME/.local/share/nvim/lazy/"* | grep -qi theme'
  else
    printf '  info  %s\n' "plugins not installed (--no-plugins?), skipping runtime checks"
  fi
else
  no "neovim installed"
fi

printf '\n--- fish ---\n'
if command -v fish >/dev/null 2>&1; then
  printf '  info  %s\n' "$(fish --version)"
  fish -c 'true' >/tmp/fish-out 2>&1; fish_status=$?
  check "starts cleanly" '[ "$fish_status" -eq 0 ] && [ ! -s /tmp/fish-out ]'
  check "dot aliases exist"        'fish -c "functions .." '
  check "open function exists"     'fish -c "functions open" '
  check "theme colors applied"     '[ -n "$(fish -c "echo \$fish_color_command")" ]'
  check "greeting silenced"        '[ -z "$(fish -c "echo \$fish_greeting")" ]'
  check "local.fish is sourced"    'printf "%s\\n" "set -g DOTFILES_LOCAL_PROBE 1" >>"$CONFIG/fish/local.fish"; [ "$(fish -c "echo \$DOTFILES_LOCAL_PROBE")" = 1 ]'
  sed -i '/DOTFILES_LOCAL_PROBE/d' "$CONFIG/fish/local.fish"
  if command -v eza >/dev/null 2>&1; then
    check "ls aliased to eza" 'fish -c "functions ls" | grep -q eza'
  fi
  if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
    check "compat.fish aliases batcat to bat" 'fish -c "functions bat" | grep -q batcat'
  fi
  if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
    check "compat.fish aliases fdfind to fd" 'fish -c "functions fd" | grep -q fdfind'
  fi
else
  no "fish installed"
fi

printf '\n--- summary ---\n'
printf '  %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
