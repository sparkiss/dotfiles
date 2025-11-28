#!/usr/bin/env python3
"""
Syncs Claude Code conversations to Zulip in real-time.
Run this in background or as systemd service.
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
ZULIP_STREAM = os.environ.get('ZULIP_STREAM', 'claude-code')

TRANSCRIPT_DIR = Path.home() / '.claude' / 'projects'
SENT_HASHES = set()  # Track what we've already sent


def send_to_zulip(role: str, content: str, session_id: str):
    """Send a message to Zulip."""
    if not all([ZULIP_SITE, ZULIP_BOT_EMAIL, ZULIP_BOT_API_KEY]):
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
        prefix = "**Claude**"

    # Truncate very long messages
    if len(content) > 10000:
        content = content[:10000] + "\n\n... (truncated)"

    # Format message with role prefix
    formatted_content = f"{prefix}\n\n{content}"

    try:
        requests.post(
            f"{ZULIP_SITE}/api/v1/messages",
            auth=(ZULIP_BOT_EMAIL, ZULIP_BOT_API_KEY),
            data={
                "type": "stream",
                "to": ZULIP_STREAM,
                "topic": f"Session {session_id[:8]}",
                "content": formatted_content
            },
            timeout=10
        )
    except Exception as e:
        print(f"Failed to send: {e}")


def parse_transcript(filepath: Path) -> list:
    """Parse JSONL transcript file."""
    messages = []
    try:
        with open(filepath, 'r') as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    msg = json.loads(line)
                    if msg.get('type') == 'user':
                        # User message
                        content = msg.get('message', {})
                        if isinstance(content, dict):
                            content = content.get('content', '')
                        messages.append(('user', str(content)))
                    elif msg.get('type') == 'assistant':
                        # Assistant message - extract text from content blocks
                        content_blocks = msg.get('message', {}).get('content', [])
                        text_parts = []
                        for block in content_blocks:
                            if isinstance(block, dict) and block.get('type') == 'text':
                                text_parts.append(block.get('text', ''))
                        if text_parts:
                            messages.append(('assistant', '\n'.join(text_parts)))
                except json.JSONDecodeError:
                    continue
    except Exception as e:
        print(f"Error parsing {filepath}: {e}")
    return messages


class TranscriptHandler(FileSystemEventHandler):
    def __init__(self):
        self.last_counts = {}  # filepath -> message count

    def on_modified(self, event):
        if event.is_directory:
            return

        filepath = Path(event.src_path)
        if filepath.suffix != '.jsonl':
            return

        # Get session ID from path
        session_id = filepath.stem

        # Parse all messages
        messages = parse_transcript(filepath)

        # Get previously seen count
        last_count = self.last_counts.get(str(filepath), 0)

        # Send only new messages
        for role, content in messages[last_count:]:
            send_to_zulip(role, content, session_id)

        self.last_counts[str(filepath)] = len(messages)


def main():
    if not all([ZULIP_SITE, ZULIP_BOT_EMAIL, ZULIP_BOT_API_KEY]):
        print("Error: Missing Zulip configuration. Set these environment variables:")
        print("  ZULIP_SITE (e.g., https://zulip.example.com)")
        print("  ZULIP_BOT_EMAIL")
        print("  ZULIP_BOT_API_KEY")
        print("  ZULIP_STREAM (optional, defaults to 'claude-code')")
        return

    print(f"Watching {TRANSCRIPT_DIR} for Claude conversations...")
    print(f"Sending to: {ZULIP_SITE} stream '{ZULIP_STREAM}'")

    event_handler = TranscriptHandler()
    observer = Observer()

    # Watch all project directories recursively
    observer.schedule(event_handler, str(TRANSCRIPT_DIR), recursive=True)
    observer.start()

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()


if __name__ == '__main__':
    main()
