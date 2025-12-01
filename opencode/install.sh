#!/bin/bash
# Install script for opencode Zulip sync

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"

# Install Python dependencies
echo "Installing Python dependencies..."
pip3 install watchdog requests

# Stow the opencode package
echo "Stowing opencode dotfiles..."
cd "$DOTFILES_DIR"
stow opencode

# Enable service based on OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Enabling systemd service..."
    systemctl --user daemon-reload
    systemctl --user enable opencode-zulip
    systemctl --user start opencode-zulip
    echo "Service status:"
    systemctl --user status opencode-zulip
elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Loading launchd agent..."
    launchctl load ~/Library/LaunchAgents/com.opencode.zulip-sync.plist
    echo "Agent loaded. Check with: launchctl list | grep opencode"
else
    echo "Unsupported OS. Please manually enable the service."
fi

echo ""
echo "Setup complete! Make sure ~/.secrets.env contains:"
echo "  ZULIP_SITE=https://your-zulip-server.com"
echo "  ZULIP_BOT_EMAIL=opencode-bot@your-zulip-server.com"
echo "  ZULIP_BOT_API_KEY=your-api-key"
echo "  ZULIP_STREAM=opencode"