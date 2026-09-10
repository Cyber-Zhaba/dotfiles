# ~/.local/bin holds tools installed outside the package manager -- install.sh
# puts a current neovim there when the distro ships one too old for LazyVim.
# Prepend it so those win over /usr/bin; without this the old binary keeps
# getting launched and nothing says why.
if test -d $HOME/.local/bin
    fish_add_path --prepend --global $HOME/.local/bin
end
