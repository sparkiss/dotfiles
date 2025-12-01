#!/bin/bash

# Build script for compiling Rust binaries
# Usage: ./build.sh

set -e

cd "$(dirname "$0")"

# Detect platform
OS="$(uname -s)"
ARCH="$(uname -m)"

echo "Detected platform: $OS $ARCH"
echo "Building claude-zulip-sync..."

mkdir -p bin

case "$OS" in
    Linux)
        echo "  Building for linux-x64..."
        cargo build --release --target x86_64-unknown-linux-gnu
        if [ -f "target/x86_64-unknown-linux-gnu/release/claude-zulip-sync" ]; then
            cp target/x86_64-unknown-linux-gnu/release/claude-zulip-sync bin/claude-zulip-sync-linux-x64
            echo "  ✓ Linux x64 binary created: bin/claude-zulip-sync-linux-x64"
        fi
        ;;
    Darwin)
        if [ "$ARCH" = "arm64" ]; then
            echo "  Building for macos-arm64..."
            cargo build --release --target aarch64-apple-darwin
            if [ -f "target/aarch64-apple-darwin/release/claude-zulip-sync" ]; then
                cp target/aarch64-apple-darwin/release/claude-zulip-sync bin/claude-zulip-sync-macos-arm64
                echo "  ✓ macOS ARM64 binary created: bin/claude-zulip-sync-macos-arm64"
            fi
        else
            echo "  Building for macos-x64..."
            cargo build --release --target x86_64-apple-darwin
            if [ -f "target/x86_64-apple-darwin/release/claude-zulip-sync" ]; then
                cp target/x86_64-apple-darwin/release/claude-zulip-sync bin/claude-zulip-sync-macos-x64
                echo "  ✓ macOS x64 binary created: bin/claude-zulip-sync-macos-x64"
            fi
        fi
        ;;
    *)
        echo "Unsupported platform: $OS"
        exit 1
        ;;
esac

echo "Claude Zulip Sync build complete!"