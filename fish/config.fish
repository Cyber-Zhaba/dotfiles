# Portable core of the fish setup. Anything tied to one machine -- PATH entries,
# version managers, host-specific functions -- belongs in local.fish, which is
# sourced at the end and deliberately not tracked in this repo.

set -g fish_greeting

# __fish_config_dir landed in fish 3.0; keep a fallback for anything older.
if not set -q __fish_config_dir
    set -g __fish_config_dir $HOME/.config/fish
end

if command -q eza
    alias ls 'eza -lh --group-directories-first --icons=auto'
    alias lsa 'ls -a'
    alias lt 'eza --tree --level=2 --long --icons --git'
    alias lta 'lt -a'
end

if command -q fzf
    alias ff "fzf --preview 'bat --style=numbers --color=always {}'"
end

if command -q zoxide
    # zoxide's fish init calls __zoxide_cd_internal, which only exists once its
    # own cd wrapper is loaded; define a passthrough so init never fails.
    if not builtin functions --query __zoxide_cd_internal
        function __zoxide_cd_internal
            builtin cd $argv
        end
    end
    zoxide init fish | source
end

function open --wraps=xdg-open --description 'Open a file with the desktop handler, detached'
    xdg-open $argv >/dev/null 2>&1 &
end

alias .. 'cd ..'
alias ... 'cd ../..'
alias .... 'cd ../../..'

# advcpmv: cp/mv with progress bars. AUR `advcpmv`, absent on most distros.
if command -q acp
    alias cp 'acp -g'
end
if command -q amv
    alias mv 'amv -g'
end

if test -f $__fish_config_dir/local.fish
    source $__fish_config_dir/local.fish
end
