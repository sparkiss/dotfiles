#!/bin/bash

# Build script for cross-compiling Rust binaries
# Usage: ./build.sh

set -e

echo "Building Rust binaries for multiple targets..."

# Claude Zulip Sync
echo "Building claude-zulip-sync..."
cd "$(dirname "$0")"

# Build for Linux x64
echo "  Building for linux-x64..."
cargo build --release --target x86_64-unknown-linux-gnu

# Build for macOS ARM64
echo "  Building for macos-arm64..."
cargo build --release --target aarch64-apple-darwin

# Copy binaries to appropriate locations
mkdir -p bin

if [ -f "target/x86_64-unknown-linux-gnu/release/claude-zulip-sync" ]; then
    cp target/x86_64-unknown-linux-gnu/release/claude-zulip-sync bin/claude-zulip-sync-linux-x64
    echo "  ✓ Linux x64 binary created: bin/claude-zulip-sync-linux-x64"
fi

if [ -f "target/aarch64-apple-darwin/release/claude-zulip-sync" ]; then
    cp target/aarch64-apple-darwin/release/claude-zulip-sync bin/claude-zulip-sync-macos-arm64
    echo "  ✓ macOS ARM64 binary created: bin/claude-zulip-sync-macos-arm64"
fi

echo "Claude Zulip Sync build complete!"