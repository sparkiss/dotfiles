#!/usr/bin/env python3
"""
Syncs Claude Code conversations to Mattermost in real-time.
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

WEBHOOK_URL = os.environ.get('MATTERMOST_CLAUDE_WEBHOOK_URL')
TRANSCRIPT_DIR = Path.home() / '.claude' / 'projects'
SENT_HASHES = set()  # Track what we've already sent


def send_to_mattermost(role: str, content: str, session_id: str):
    """Send a message to Mattermost."""
    if not WEBHOOK_URL:
        return

    # Avoid duplicates
    msg_hash = hashlib.md5(f"{session_id}:{role}:{content}".encode()).hexdigest()
    if msg_hash in SENT_HASHES:
        return
    SENT_HASHES.add(msg_hash)

    # Format based on role
    if role == 'user':
        username = "You"
        icon = ":bust_in_silhouette:"
        color = "#0099FF"
    else:
        username = "Claude"
        icon = ":robot_face:"
        color = "#9B59B6"

    # Truncate very long messages
    if len(content) > 4000:
        content = content[:4000] + "\n\n... (truncated)"

    payload = {
        "username": username,
        "icon_emoji": icon,
        "attachments": [{
            "color": color,
            "text": content,
            "footer": f"Session: {session_id[:8]}"
        }]
    }

    try:
        requests.post(WEBHOOK_URL, json=payload, timeout=5)
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
            send_to_mattermost(role, content, session_id)

        self.last_counts[str(filepath)] = len(messages)


def main():
    if not WEBHOOK_URL:
        print("Error: MATTERMOST_CLAUDE_WEBHOOK_URL not set")
        return

    print(f"Watching {TRANSCRIPT_DIR} for Claude conversations...")
    print(f"Sending to: {WEBHOOK_URL[:50]}...")

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
