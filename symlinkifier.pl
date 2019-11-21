#! /usr/bin/perl
use strict;
use warnings;

##TODO Make single function that retrives path and name from dictionary

# List with config that recides in home folder
my @home_conf = qw(.i3blocks.conf .tmux.conf .vimrc .zshrc);
foreach my $file (@home_conf){
    if( `test -f ~/dotfiles/$file`){
        my $out = `ln -sf ~/dotfiles/$file ~/`;
    } else{
        say $file . " does not exist"
    }
};

# List with config that recides in .config folder
my @conf_conf = qw(i3 rofi terminator polybar);
foreach my $name (@conf_conf){
    my $out = `ln -sf ~/dotfiles/$name/config ~/.config/$name`;
};

# Custom for nvim
my $out = `ln -sf ~/dotfiles/$name/init.vim ~/.config/$name`;


# zsh theme
my $out3 = `ln -sf ~/dotfiles/theodorc.zsh-theme ~/.oh-my-zsh/custom/themes/theodorc.zsh-theme`

#Custom for visual code
##this crashes if visual code isnt installed
my $out2 = `ln -sf ~/dotfiles/settings.json ~/.config/Code/User/settings.json/`


