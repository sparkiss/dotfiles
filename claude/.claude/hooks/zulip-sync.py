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
ZULIP_STREAM = os.environ.get('ZULIP_STREAM_CLAUDE_CODE', 'claude-code')

TRANSCRIPT_DIR = Path.home() / '.claude' / 'projects'
SENT_HASHES = set()  # Track what we've already sent


def format_content_block(block: dict) -> str | None:
    """Format a content block for Zulip display."""
    block_type = block.get('type', '')

    if block_type == 'text':
        return block.get('text', '')

    elif block_type == 'tool_use':
        tool_name = block.get('name', 'unknown')
        tool_input = block.get('input', {})
        # Format input as JSON
        formatted_input = json.dumps(tool_input, indent=2)
        return f"**Tool: {tool_name}**\n```json\n{formatted_input}\n```"

    elif block_type == 'tool_result':
        content = block.get('content', '')
        is_error = block.get('is_error', False)
        status = "Error" if is_error else "Result"
        # Content might be a string or list
        if isinstance(content, list):
            # Extract text from content list
            text_parts = []
            for item in content:
                if isinstance(item, dict) and item.get('type') == 'text':
                    text_parts.append(item.get('text', ''))
            content = '\n'.join(text_parts)
        return f"**Tool {status}**\n```\n{content}\n```"

    elif block_type == 'thinking':
        # Skip thinking blocks - don't include in output
        return None

    return str(block)


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
            auth=(ZULIP_BOT_EMAIL or "", ZULIP_BOT_API_KEY or ""),
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
                        # Check if content is a list of tool results
                        if isinstance(content, list):
                            formatted_parts = []
                            for item in content:
                                if isinstance(item, dict):
                                    formatted_parts.append(format_content_block(item))
                                else:
                                    formatted_parts.append(str(item))
                            content = '\n\n'.join(formatted_parts)
                        messages.append(('user', str(content)))
                    elif msg.get('type') == 'assistant':
                        # Assistant message - format all content blocks
                        content_blocks = msg.get('message', {}).get('content', [])
                        formatted_parts = []
                        for block in content_blocks:
                            if isinstance(block, dict):
                                formatted = format_content_block(block)
                                if formatted:  # Skip None (thinking blocks)
                                    formatted_parts.append(formatted)
                        if formatted_parts:
                            messages.append(('assistant', '\n\n'.join(formatted_parts)))
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

        filepath = Path(event.src_path.decode() if isinstance(event.src_path, bytes) else event.src_path)
        if filepath.suffix != '.jsonl':
            return

        # Get session ID from path
        session_id = str(filepath.stem)

        # Parse all messages
        messages = parse_transcript(filepath)

        # Get previously seen count
        last_count = self.last_counts.get(event.src_path, 0)

        # Send only new messages
        for role, content in messages[last_count:]:
            send_to_zulip(role, content, session_id)

        self.last_counts[event.src_path] = len(messages)


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
    print(f"ZULIP_STREAM_CLAUDE_CODE: {ZULIP_STREAM}", flush=True)

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
