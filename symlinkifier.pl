#! /usr/bin/perl
use strict;
use warnings;

##TODO Make single function that retrives path and name from dictionary

# List with config that recides in home folder
my @home_conf = qw(.tmux.conf .vimrc .zshrc .gitconfig);
foreach my $file (@home_conf){
    if( `test -f ~/dotfiles/$file`){
        my $out = `ln -sf ~/dotfiles/$file ~/`;
    } else{
        printf $file . " does not exist\n"
    }
};

# List with config that recides in .config folder
my @conf_conf = qw(i3 rofi terminator polybar);
foreach my $name (@conf_conf){
    my $out = `ln -sf ~/dotfiles/$name/config ~/.config/$name`;
};

# Sway (symlink whole directory)
my $out=`ln -sf ~/dotfiles/sway ~/.config/sway`;

# kanshi (symlink whole directory for output profiles)
my $out=`ln -sf ~/dotfiles/kanshi ~/.config/kanshi`;

# Waybar (symlink whole directory for config + style.css)
my $out=`ln -sf ~/dotfiles/waybar ~/.config/waybar`;

# xdg-desktop-portal (symlink whole directory for backend preferences)
my $out=`ln -sf ~/dotfiles/xdg-desktop-portal ~/.config/xdg-desktop-portal`;

# swaylock (symlink whole directory for the lock screen theme)
my $out=`ln -sf ~/dotfiles/swaylock ~/.config/swaylock`;

# alacritty (symlink whole directory for config + theme)
my $out=`ln -sf ~/dotfiles/alacritty ~/.config/alacritty`;

# mako (symlink whole directory for the notification theme)
my $out=`ln -sf ~/dotfiles/mako ~/.config/mako`;

# Claude Code global config — symlink individual files only, NOT the whole
# ~/.claude dir (it holds session data, transcripts, plans, credentials).
my $out=`mkdir -p ~/.claude && ln -sf ~/dotfiles/claude/settings.json ~/.claude/settings.json`;
my $out=`ln -sf ~/dotfiles/claude/statusline-command.sh ~/.claude/statusline-command.sh`;

# Custom for nvim
my $out=`ln -sf ~/dotfiles/nvim/init.vim ~/.config/nvim/init.vim`;
my $out=`mkdir -p ~/.config/nvim/config && ln -sf ~/dotfiles/nvim/coc.vimrc ~/.config/nvim/config/coc.vimrc`


# zsh theme
#my $out3 = `ln -sf ~/dotfiles/theodorc.zsh-theme ~/.oh-my-zsh/custom/themes/theodorc.zsh-theme`

#Custom for visual code
##this crashes if visual code isnt installed
#my $out2 = `ln -sf ~/dotfiles/settings.json ~/.config/Code/User/settings.json/`
