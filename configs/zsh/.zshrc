# CodeWhisperer pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/codewhisperer/shell/zshrc.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/codewhisperer/shell/zshrc.pre.zsh"
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="~/.oh-my-zsh"

export UPDATE_ZSH_DAYS=13

ENABLE_CORRECTION="true"

export ZSH_THEME="powerlevel10k/powerlevel10k"
export POWERLEVEL9K_MODE="awesome-patched"

source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

plugins=(git zsh-completions zsh-autosuggestions)

source $ZSH/oh-my-zsh.sh

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

source ~/.my-commands.sh

export EDITOR="/opt/homebrew/bin/nvim"
export NVM_DIR="$HOME/.nvm"

if which pyenv-virtualenv-init > /dev/null; then eval "$(pyenv virtualenv-init -)"; fi

[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion}

eval "$(zoxide init zsh)"

test -f '~/Library/Preferences/netlify/helper/path.zsh.inc' && source '~/Library/Preferences/netlify/helper/path.zsh.inc'

## FZF
export FZF_DEFAULT_COMMAND='fd --type f -H --follow --exclude .git --color=always'

# color-theme morhetz/gruvbox
export FZF_DEFAULT_OPTS='--ansi --color=spinner:#fb4934,hl:#928374,fg:#ebdbb2,header:#928374,info:#8ec07c,pointer:#fb4934,marker:#fb4934,fg+:#ebdbb2,prompt:#fb4934,hl+:#fb4934'
export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --height 100% --layout reverse --info inline --border \
    --preview 'file {}' --preview-window up,1,border-horizontal"

###############

eval "$(/opt/homebrew/bin/brew shellenv)"
export ANDROID_HOME=$HOME/Library/Android/sdk
export JAVA_HOME=/Applications/Android\ Studio.app/Contents/jre/Contents/Home
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/tools/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin
export PATH=$PATH:$HOME/.pub-cache/bin
export PATH=$PATH:$HOME/flutter/bin

export PNPM_HOME="/Users/stevenjohn/Library/pnpm"
export PATH="$PNPM_HOME:$PATH"
export YAML_DIR='/opt/homebrew/Cellar/libyaml/0.2.5/'
source /opt/homebrew/opt/chruby/share/chruby/chruby.sh

autoload -U +X bashcompinit && bashcompinit
complete -o nospace -C /opt/homebrew/bin/terraform terraform

autoload -Uz compinit
zstyle ':completion:*' menu select
fpath+=~/.zfunc

# bun completions
[ -s "/Users/stevenjohn/.oh-my-zsh/completions/_bun" ] && source "/Users/stevenjohn/.oh-my-zsh/completions/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/stevenjohn/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/stevenjohn/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/stevenjohn/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/stevenjohn/google-cloud-sdk/completion.zsh.inc'; fi

source <(pkgx --shellcode)  #docs.pkgx.sh/shellcode
eval "$(starship init zsh)"
eval "$(direnv hook zsh)"
export DIRENV_SKIP_TIMEOUT=TRUE


[[ -f "$HOME/fig-export/dotfiles/dotfile.zsh" ]] && builtin source "$HOME/fig-export/dotfiles/dotfile.zsh"

# CodeWhisperer post block. Keep at the bottom of this file.
[[ -f "${HOME}/Library/Application Support/codewhisperer/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/codewhisperer/shell/zshrc.post.zsh"
