#!/usr/bin/env bash
set -e
pacman -Syu;  
pacman -S\
    polybar\
    i3-gaps\
    rofi\
    neovim\
    fzf\
    firefox\
    alacritty
    mosh\
    feh;
