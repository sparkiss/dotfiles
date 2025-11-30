# Claude Code Zulip Sync

Real-time sync of Claude Code conversations to Zulip.

## What it does

Watches Claude Code transcript files and posts conversations to a Zulip stream as they happen. Useful for:
- Sharing AI coding sessions with your team
- Keeping a searchable log of Claude interactions
- Reviewing conversations later

## Installation

```bash
# Install dependencies
pip install watchdog requests

# Stow the package
cd ~/dotfiles
stow claude

# Enable the service
./install.sh --setup-claude-zulip
```

## Setup

1. **Create a Zulip bot:**
   - Go to Zulip → Settings → Personal settings → Bots
   - Add a new bot (Generic bot)
   - Copy the bot email and API key

2. **Create `~/.secrets.env`:**
   ```bash
   ZULIP_SITE=https://your-zulip-server.zulipchat.com
   ZULIP_BOT_EMAIL=claude-bot@your-zulip-server.zulipchat.com
   ZULIP_BOT_API_KEY=your-api-key-here
   ZULIP_STREAM=claude-code
   ```

3. **Create the stream** in Zulip (or use an existing one)

## Service Management

**Linux:**
```bash
systemctl --user start claude-zulip
systemctl --user stop claude-zulip
systemctl --user status claude-zulip
```

**macOS:**
```bash
launchctl load ~/Library/LaunchAgents/com.claude.zulip-sync.plist
launchctl unload ~/Library/LaunchAgents/com.claude.zulip-sync.plist
```

## Files

```
claude/
├── .claude/hooks/
│   ├── zulip-sync.py           # Main sync script
│   └── zulip-sync-launcher.sh  # Wrapper for macOS launchd
├── .config/systemd/user/
│   └── claude-zulip.service    # Linux systemd service
└── Library/LaunchAgents/
    └── com.claude.zulip-sync.plist  # macOS launchd service
```
