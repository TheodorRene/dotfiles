
# Path to your oh-my-zsh installation.
 export ZSH="$HOME/.oh-my-zsh"
 path+=$HOME/bin

# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
ZSH_THEME="blinks"

#Plugins
plugins=(
    git
    wd
    catimg
    last-working-dir
    django
    pep8
    pip
)

source $ZSH/oh-my-zsh.sh

# ssh
# export SSH_KEY_PATH="~/.ssh/rsa_id"

alias takeover="tmux detach -a"
alias lr="ls -ltrh"
alias cass="mosh cassarossa.samfundet.no"
alias pol="mosh polpot.dhcp.samfundet.no"
alias shut="sudo shutdown now"
alias clip="xclip -selection c"
alias boy="ssh 139.59.147.33"
alias svenv="source venv/bin/activate"


[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

PATH="/home/theodorc/perl5/bin${PATH:+:${PATH}}"; export PATH;
PERL5LIB="/home/theodorc/perl5/lib/perl5${PERL5LIB:+:${PERL5LIB}}"; export PERL5LIB;
PERL_LOCAL_LIB_ROOT="/home/theodorc/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"; export PERL_LOCAL_LIB_ROOT;
PERL_MB_OPT="--install_base \"/home/theodorc/perl5\""; export PERL_MB_OPT;
PERL_MM_OPT="INSTALL_BASE=/home/theodorc/perl5"; export PERL_MM_OPT;

export EDITOR=/usr/bin/vim
export VISUAL=/usr/bin/vim
