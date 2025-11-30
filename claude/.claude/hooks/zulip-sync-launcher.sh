#!/usr/bin/env bash
# Wrapper script to load environment and run zulip-sync.py
# Used by launchd on macOS (systemd has native EnvironmentFile support)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load secrets from ~/.secrets.env if it exists
if [ -f "$HOME/.secrets.env" ]; then
    set -a
    source "$HOME/.secrets.env"
    set +a
fi

# Run the sync script
exec python3 "$SCRIPT_DIR/zulip-sync.py"
