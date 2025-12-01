# OpenCode Zulip Sync

Real-time sync of OpenCode conversations to Zulip.

## What it does

Watches OpenCode transcript files and posts conversations to a Zulip stream as they happen. Useful for:
- Sharing AI coding sessions with your team
- Keeping a searchable log of OpenCode interactions
- Reviewing conversations later

## Installation

```bash
# Install dependencies
pip install watchdog requests

# Stow the package
cd ~/dotfiles
stow opencode

# Enable the service (Linux)
systemctl --user enable opencode-zulip
systemctl --user start opencode-zulip

# Or on macOS
launchctl load ~/Library/LaunchAgents/com.opencode.zulip-sync.plist
```

## Setup

1. **Create a Zulip bot:**
   - Go to Zulip → Settings → Personal settings → Bots
   - Add a new bot (Generic bot)
   - Copy the bot email and API key

2. **Create `~/.secrets.env`:**
   ```bash
   ZULIP_SITE=https://your-zulip-server.zulipchat.com
   ZULIP_BOT_EMAIL=opencode-bot@your-zulip-server.zulipchat.com
   ZULIP_BOT_API_KEY=your-api-key-here
   ZULIP_STREAM=opencode
   ```

3. **Create the stream** in Zulip (or use an existing one)

## Service Management

**Linux:**
```bash
systemctl --user start opencode-zulip
systemctl --user stop opencode-zulip
systemctl --user status opencode-zulip
```

**macOS:**
```bash
launchctl load ~/Library/LaunchAgents/com.opencode.zulip-sync.plist
launchctl unload ~/Library/LaunchAgents/com.opencode.zulip-sync.plist
```

## Files

```
opencode/
├── .opencode/hooks/
│   ├── opencode-zulip-sync.py           # Main sync script
│   └── opencode-zulip-sync-launcher.sh  # Wrapper for macOS launchd
├── .config/systemd/user/
│   └── opencode-zulip.service           # Linux systemd service
└── Library/LaunchAgents/
    └── com.opencode.zulip-sync.plist    # macOS launchd service
```