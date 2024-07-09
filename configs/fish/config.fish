set -gx EDITOR "/opt/homebrew/bin/nvim"
set -gx NVM_DIR "$HOME/.nvm"
set -gx GIT_EDITOR $EDITOR

## end

zoxide init fish | source
starship init fish | source
direnv hook fish | source
