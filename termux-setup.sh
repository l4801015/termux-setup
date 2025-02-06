#!/bin/bash
set -e

# Install core utilities with compiler and PRoot packages
echo "Installing core packages..."
pkg install -y git nodejs curl wget openssh zsh neovim ncurses-utils clang make proot proot-distro

# Install Ubuntu via proot-distro
echo "Installing Ubuntu via proot-distro..."
proot-distro install ubuntu
