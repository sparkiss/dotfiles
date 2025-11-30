#!/usr/bin/env bash

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES_DIR"

echo "Installing dotfiles from $DOTFILES_DIR"

# Detect OS
OS="$(uname -s)"
case "$OS" in
    Linux*)  PLATFORM="linux";;
    Darwin*) PLATFORM="macos";;
    *)       PLATFORM="unknown";;
esac
echo "Detected platform: $PLATFORM"

# Check if stow is installed
if ! command -v stow &> /dev/null; then
    echo "Error: GNU Stow is not installed."
    echo "Install it with:"
    echo "  Ubuntu/Debian: sudo apt install stow"
    echo "  macOS: brew install stow"
    echo "  Arch: sudo pacman -S stow"
    exit 1
fi

# Function to stow a package with platform-specific ignores
stow_package() {
    local package=$1
    local ignore_args=""

    # Ignore platform-specific directories that don't apply
    if [ "$package" = "claude" ]; then
        if [ "$PLATFORM" = "linux" ]; then
            ignore_args="--ignore=Library"
        elif [ "$PLATFORM" = "macos" ]; then
            ignore_args="--ignore=systemd"
        fi
    fi

    echo "Stowing $package..."
    stow -v -t "$HOME" $ignore_args "$package"
}

# Function to setup Claude Zulip service
setup_claude_zulip_service() {
    echo ""
    echo "Setting up Claude Zulip sync service..."

    if [ "$PLATFORM" = "linux" ]; then
        echo "Enabling systemd user service..."
        systemctl --user daemon-reload
        systemctl --user enable claude-zulip
        echo "Service enabled. Start with: systemctl --user start claude-zulip"

    elif [ "$PLATFORM" = "macos" ]; then
        # Ensure LaunchAgents directory exists
        mkdir -p "$HOME/Library/LaunchAgents"

        # Copy plist (stow may not have created Library dir)
        if [ ! -f "$HOME/Library/LaunchAgents/com.claude.zulip-sync.plist" ]; then
            cp "$DOTFILES_DIR/claude/Library/LaunchAgents/com.claude.zulip-sync.plist" \
               "$HOME/Library/LaunchAgents/"
        fi

        echo "Loading launchd service..."
        launchctl unload "$HOME/Library/LaunchAgents/com.claude.zulip-sync.plist" 2>/dev/null || true
        launchctl load "$HOME/Library/LaunchAgents/com.claude.zulip-sync.plist"
        echo "Service loaded. Check status with: launchctl list | grep claude"
    fi
}

# Handle special flags
SETUP_CLAUDE_ZULIP=false
PACKAGES=()

for arg in "$@"; do
    case "$arg" in
        --setup-claude-zulip)
            SETUP_CLAUDE_ZULIP=true
            ;;
        *)
            PACKAGES+=("$arg")
            ;;
    esac
done

# Stow all packages or specified ones
if [ ${#PACKAGES[@]} -eq 0 ] && [ "$SETUP_CLAUDE_ZULIP" = false ]; then
    # No arguments, stow all packages
    for package in nvim tmux zsh claude; do
        if [ -d "$package" ]; then
            stow_package "$package"
        fi
    done
elif [ ${#PACKAGES[@]} -gt 0 ]; then
    # Stow specified packages
    for package in "${PACKAGES[@]}"; do
        if [ -d "$package" ]; then
            stow_package "$package"
        else
            echo "Warning: Package '$package' not found, skipping..."
        fi
    done
fi

# Setup Claude Zulip service if requested
if [ "$SETUP_CLAUDE_ZULIP" = true ]; then
    setup_claude_zulip_service
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
echo ""
echo "6. Claude Code Zulip integration:"
echo "   - Create a bot in Zulip: Settings → Personal settings → Bots"
echo "   - Create ~/.secrets.env with:"
echo "       ZULIP_SITE=https://your-zulip-server.com"
echo "       ZULIP_BOT_EMAIL=bot-name@your-zulip-server.com"
echo "       ZULIP_BOT_API_KEY=<your-bot-api-key>"
echo "       ZULIP_STREAM=claude-code"
echo "   - pip install watchdog requests"
echo "   - Run: ./install.sh --setup-claude-zulip"
echo ""
if [ "$PLATFORM" = "linux" ]; then
echo "   Or manually:"
echo "   - systemctl --user daemon-reload"
echo "   - systemctl --user enable --now claude-zulip"
elif [ "$PLATFORM" = "macos" ]; then
echo "   Or manually:"
echo "   - launchctl load ~/Library/LaunchAgents/com.claude.zulip-sync.plist"
echo "   - Check status: launchctl list | grep claude"
echo "   - View logs: tail -f /tmp/claude-zulip.log"
fi
