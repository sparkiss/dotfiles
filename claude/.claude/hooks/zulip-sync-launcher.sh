#!/bin/bash

# Claude Zulip Sync Launcher
# Detects architecture and runs appropriate binary

set -e

# Get it directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Environment loading (for systemd compatibility)
if [ -f ~/.secrets.env ]; then
    echo "Loading environment from ~/.secrets.env"
    set -a
    source ~/.secrets.env
    set +a
fi

# Debug: Show loaded environment (remove sensitive data)
echo "Environment loaded:"
echo "  ZULIP_SITE=${ZULIP_SITE:+[SET]}"
echo "  ZULIP_BOT_EMAIL=${ZULIP_BOT_EMAIL:+[SET]}"
echo "  ZULIP_BOT_API_KEY=${ZULIP_BOT_API_KEY:+[SET]}"
echo "  ZULIP_STREAM_CLAUDE_CODE=${ZULIP_STREAM_CLAUDE_CODE:-claude-code}"

# Detect architecture and select appropriate binary
ARCH=$(uname -m)
OS=$(uname -s)

BINARY_PATH=""
if [[ "$OS" == "Linux" && "$ARCH" == "x86_64" ]]; then
    BINARY_PATH="$SCRIPT_DIR/bin/claude-zulip-sync-linux-x64"
elif [[ "$OS" == "Darwin" && "$ARCH" == "arm64" ]]; then
    BINARY_PATH="$SCRIPT_DIR/bin/claude-zulip-sync-macos-arm64"
else
    echo "Unsupported architecture: $OS $ARCH"
    echo "Falling back to Python script..."
    exec python3 "$SCRIPT_DIR/zulip-sync.py"
fi

# Check if binary exists
if [ ! -f "$BINARY_PATH" ]; then
    echo "Binary not found: $BINARY_PATH"
    echo "Please run ./build.sh to compile the Rust binary"
    echo "Falling back to Python script..."
    exec python3 "$SCRIPT_DIR/zulip-sync.py"
fi

echo "Using Rust binary: $BINARY_PATH"
exec "$BINARY_PATH"
