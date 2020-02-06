
# Path to your oh-my-zsh installation.
 export ZSH="$HOME/.oh-my-zsh"
 path+=$HOME/bin

# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
ZSH_THEME2="~/dotfiles/theodorc.zsh-theme"
ZSH_THEME="theodorc"

#Plugins
plugins=(
    git
    wd
    catimg
    last-working-dir
    fzf
    extract
    sudo
)

source $ZSH/oh-my-zsh.sh

# ssh
# export SSH_KEY_PATH="~/.ssh/rsa_id"

alias takeover="tmux detach -a"
alias lr="ls -ltrh"
alias cass="mosh cassarossa.samfundet.no"
alias shut="sudo shutdown now"
alias clip="xclip -selection c"
alias svenv="source venv/bin/activate"
alias dsize="du -h --max-depth=1 | sort -h"
alias bc="bc -lq"
alias sugit="sudo -E git"
alias suvim="sudo -E vim"
alias vim="nvim"
alias vimnote="nvim $(date +"%m_%d_%Y").md"
alias py="python"
alias lock="xscreensaver-command -lock"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

PATH="/home/theodorc/perl5/bin${PATH:+:${PATH}}"; export PATH;
PERL5LIB="/home/theodorc/perl5/lib/perl5${PERL5LIB:+:${PERL5LIB}}"; export PERL5LIB;
PERL_LOCAL_LIB_ROOT="/home/theodorc/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"; export PERL_LOCAL_LIB_ROOT;
PERL_MB_OPT="--install_base \"/home/theodorc/perl5\""; export PERL_MB_OPT;
PERL_MM_OPT="INSTALL_BASE=/home/theodorc/perl5"; export PERL_MM_OPT;

export EDITOR=/usr/bin/nvim
export VISUAL=/usr/bin/nvim

#export NVM_DIR="$HOME/.nvm"
#[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm

export PATH="$HOME/.yarn/bin:$HOME/.local/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"
source /home/theodorc/.ghcup/env
