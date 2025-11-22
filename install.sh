#!/usr/bin/env bash

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES_DIR"

echo "Installing dotfiles from $DOTFILES_DIR"

# Check if stow is installed
if ! command -v stow &> /dev/null; then
    echo "Error: GNU Stow is not installed."
    echo "Install it with:"
    echo "  Ubuntu/Debian: sudo apt install stow"
    echo "  macOS: brew install stow"
    echo "  Arch: sudo pacman -S stow"
    exit 1
fi

# Function to stow a package
stow_package() {
    local package=$1
    echo "Stowing $package..."
    stow -v -t "$HOME" "$package"
}

# Stow all packages or specified ones
if [ $# -eq 0 ]; then
    # No arguments, stow all packages
    for package in nvim tmux zsh; do
        if [ -d "$package" ]; then
            stow_package "$package"
        fi
    done
else
    # Stow specified packages
    for package in "$@"; do
        if [ -d "$package" ]; then
            stow_package "$package"
        else
            echo "Warning: Package '$package' not found, skipping..."
        fi
    done
fi

echo ""
echo "Dotfiles installed successfully!"
echo ""
echo "Post-installation steps:"
echo "1. Install Tmux Plugin Manager (TPM):"
echo "   git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm"
echo "   Then in tmux: prefix + I to install plugins"
echo ""
echo "2. Install Oh-My-Zsh:"
echo "   sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
echo ""
echo "3. Install Powerlevel10k:"
echo "   git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
echo ""
echo "4. Install Zsh plugins:"
echo "   git clone https://github.com/zsh-users/zsh-autosuggestions \${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
echo "   git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
echo ""
echo "5. Open Neovim - LazyVim will auto-install plugins on first launch"
