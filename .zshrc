# Path to your oh-my-zsh installation.
  export ZSH="/home/theodorc/.oh-my-zsh"

	
#Name of theme
#https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
 ZSH_THEME="blinks"

eval `dircolors ~/.dir_colors/dircolors`




# Which plugins would you like to load?
# Standard plugins can be found in ~/.oh-my-zsh/plugins/*
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
    git
    vi-mode
    wd
)

source $ZSH/oh-my-zsh.sh

#ALIAS
alias as="sudo apt search"
alias lr="ls -ltr"
alias cass="mosh cassarossa.samfundet.no"
export EDITOR='vim'
