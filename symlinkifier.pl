#! /usr/bin/perl
use strict;
use warnings;
use File::Basename qw(dirname);
use File::Path qw(make_path);

my $home = $ENV{HOME};
my $dotfiles = "$home/dotfiles";
my $stamp = do {
    my ($sec, $min, $hour, $mday, $mon, $year) = localtime;
    sprintf('%04d%02d%02d%02d%02d%02d', $year + 1900, $mon + 1, $mday, $hour, $min, $sec);
};

sub symlink_path {
    my ($source, $target) = @_;

    if (!-e $source) {
        print "$source does not exist\n";
        return;
    }

    make_path(dirname($target));

    if (-l $target) {
        unlink $target or die "failed to remove $target: $!";
    } elsif (-e $target) {
        my $backup = "$target.bak.$stamp";
        rename $target, $backup or die "failed to backup $target to $backup: $!";
        print "backed up $target to $backup\n";
    }

    symlink $source, $target or die "failed to link $target -> $source: $!";
}

# Config that resides in the home folder.
for my $file (qw(.tmux.conf .vimrc .zshrc .gitconfig)) {
    symlink_path("$dotfiles/$file", "$home/$file");
}

# Config directories under ~/.config.
for my $name (qw(i3 sway kanshi waybar wofi xdg-desktop-portal swaylock alacritty kitty mako opencode direnv)) {
    symlink_path("$dotfiles/$name", "$home/.config/$name");
}

# Claude Code global config: link individual files only, not ~/.claude.
symlink_path("$dotfiles/claude/settings.json", "$home/.claude/settings.json");
symlink_path("$dotfiles/claude/statusline-command.sh", "$home/.claude/statusline-command.sh");

# Neovim v2 config.
symlink_path("$dotfiles/nvim_v2", "$home/.config/nvim");

# Custom for visual code
## this crashes if visual code isnt installed
#symlink_path("$dotfiles/settings.json", "$home/.config/Code/User/settings.json");
