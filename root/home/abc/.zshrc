# RanSynSrv - Zsh Configuration
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
plugins=(git docker docker-compose node npm fzf rsync sudo zsh-autosuggestions zsh-syntax-highlighting zsh-completions)
source $ZSH/oh-my-zsh.sh

# Environment
export LANG=en_US.UTF-8
export EDITOR='nano'
export VISUAL='nano'
export PATH="${PATH}:/usr/local/share/npm-global/bin"
export GIT_PAGER='delta'

# NVM
export NVM_DIR="/usr/local/share/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias nginx-test='sudo nginx -t'
alias nginx-reload='sudo nginx -s reload'
alias logs='tail -f /data/log/nginx/access.log'
alias errors='tail -f /data/log/nginx/error.log'
alias phplogs='tail -f /data/log/php/error.log'
alias cc='claude'

# History
HISTFILE=/data/commandhistory/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt appendhistory sharehistory hist_ignore_dups hist_ignore_space

# FZF
[ -f /usr/share/fzf/key-bindings.zsh ] && source /usr/share/fzf/key-bindings.zsh
[ -f /usr/share/fzf/completion.zsh ] && source /usr/share/fzf/completion.zsh

# Start in /data directory
cd /data 2>/dev/null || true
