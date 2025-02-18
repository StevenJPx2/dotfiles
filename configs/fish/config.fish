set -gx EDITOR "/opt/homebrew/bin/nvim"
set -gx NVM_DIR "$HOME/.nvm"
set -gx GIT_EDITOR $EDITOR
source "$HOME/.cargo/env.fish"
set -q XDG_CONFIG_HOME || set XDG_CONFIG_HOME "$HOME/.config"

fish_add_path /opt/homebrew/bin

for file in $XDG_CONFIG_HOME/fish/aliases/*.fish
  source $file
end

## end

zoxide init fish | source
starship init fish | source
direnv hook fish | source
fzf --fish | source
