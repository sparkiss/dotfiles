#!/usr/bin/env python3
"""
Syncs opencode conversations to Zulip in real-time.
Run this in background or as systemd service.

OpenCode stores messages as:
- ~/.local/share/opencode/storage/message/<session_id>/<msg_id>.json
- ~/.local/share/opencode/storage/part/<msg_id>/<part_id>.json (actual content)
"""

import json
import os
import time
import hashlib
import requests
from pathlib import Path
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

# Zulip configuration from environment
ZULIP_SITE = os.environ.get('ZULIP_SITE')
ZULIP_BOT_EMAIL = os.environ.get('ZULIP_BOT_EMAIL')
ZULIP_BOT_API_KEY = os.environ.get('ZULIP_BOT_API_KEY')
ZULIP_STREAM = os.environ.get('ZULIP_STREAM_OPEN_CODE', 'opencode')

# OpenCode storage paths
STORAGE_DIR = Path.home() / '.local' / 'share' / 'opencode' / 'storage'
MESSAGE_DIR = STORAGE_DIR / 'message'
PART_DIR = STORAGE_DIR / 'part'

SENT_HASHES = set()  # Track what we've already sent


def get_message_content(msg_id: str) -> str:
    """Get message content from part files."""
    part_dir = PART_DIR / msg_id
    if not part_dir.exists():
        return ""

    text_parts = []
    # Sort by filename to maintain order
    for part_file in sorted(part_dir.glob("*.json")):
        try:
            with open(part_file, 'r') as f:
                part = json.load(f)
                if part.get('type') == 'text':
                    text = part.get('text', '')
                    if text:
                        text_parts.append(text)
        except (json.JSONDecodeError, IOError):
            continue

    return '\n'.join(text_parts)


def send_to_zulip(role: str, content: str, session_id: str):
    """Send a message to Zulip."""
    if not all([ZULIP_SITE, ZULIP_BOT_EMAIL, ZULIP_BOT_API_KEY]):
        print("Missing Zulip credentials, skipping send", flush=True)
        return

    if not content.strip():
        return

    # Avoid duplicates
    msg_hash = hashlib.md5(f"{session_id}:{role}:{content}".encode()).hexdigest()
    if msg_hash in SENT_HASHES:
        return
    SENT_HASHES.add(msg_hash)

    # Format based on role
    if role == 'user':
        prefix = "**You**"
    else:
        prefix = "**OpenCode**"

    # Truncate very long messages
    if len(content) > 10000:
        content = content[:10000] + "\n\n... (truncated)"

    # Format message with role prefix
    formatted_content = f"{prefix}\n\n{content}"

    # Use short session ID for topic
    short_session = session_id.replace('ses_', '')[:8]

    try:
        resp = requests.post(
            f"{ZULIP_SITE}/api/v1/messages",
            auth=(ZULIP_BOT_EMAIL or "", ZULIP_BOT_API_KEY or ""),
            data={
                "type": "stream",
                "to": ZULIP_STREAM,
                "topic": f"Session {short_session}",
                "content": formatted_content
            },
            timeout=10
        )
        if resp.status_code != 200:
            print(f"Zulip error: {resp.status_code} {resp.text}", flush=True)
    except Exception as e:
        print(f"Failed to send: {e}", flush=True)


class MessageHandler(FileSystemEventHandler):
    def __init__(self):
        self.processed = set()  # Track processed message IDs

    def process_message(self, filepath: Path):
        """Process a message file."""
        if filepath.suffix != '.json':
            return

        msg_id = filepath.stem
        if msg_id in self.processed:
            return

        try:
            with open(filepath, 'r') as f:
                msg = json.load(f)
        except (json.JSONDecodeError, IOError) as e:
            print(f"Error reading {filepath}: {e}", flush=True)
            return

        role = msg.get('role', '')
        session_id = msg.get('sessionID', '')

        if not role or not session_id:
            return

        # Small delay to let part files be written
        time.sleep(0.5)

        # Get content from parts
        content = get_message_content(msg_id)

        if content:
            self.processed.add(msg_id)
            send_to_zulip(role, content, session_id)
            print(f"Sent {role} message from session {session_id[:16]}...", flush=True)

    def on_created(self, event):
        if event.is_directory:
            return
        filepath = Path(event.src_path)
        self.process_message(filepath)

    def on_modified(self, event):
        if event.is_directory:
            return
        filepath = Path(event.src_path)
        # Re-process on modify in case parts weren't ready
        msg_id = filepath.stem
        if msg_id in self.processed:
            return
        self.process_message(filepath)


def main():
    if not all([ZULIP_SITE, ZULIP_BOT_EMAIL, ZULIP_BOT_API_KEY]):
        print("Error: Missing Zulip configuration. Set these environment variables:")
        print("  ZULIP_SITE (e.g., https://zulip.example.com)")
        print("  ZULIP_BOT_EMAIL")
        print("  ZULIP_BOT_API_KEY")
        print("  ZULIP_STREAM_OPEN_CODE (optional, defaults to 'opencode')")
        return

    print(f"Watching {MESSAGE_DIR} for opencode conversations...", flush=True)
    print(f"Parts directory: {PART_DIR}", flush=True)
    print(f"Sending to: {ZULIP_SITE} stream '{ZULIP_STREAM}'", flush=True)

    if not MESSAGE_DIR.exists():
        print(f"Warning: Message directory does not exist: {MESSAGE_DIR}", flush=True)
        MESSAGE_DIR.mkdir(parents=True, exist_ok=True)

    event_handler = MessageHandler()
    observer = Observer()

    # Watch message directory recursively
    observer.schedule(event_handler, str(MESSAGE_DIR), recursive=True)
    observer.start()

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()


if __name__ == '__main__':
    main()
