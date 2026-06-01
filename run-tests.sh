#!/bin/bash
# Runs ClaudeStripCore unit tests via swiftc (no SwiftPM dependency).
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

mkdir -p build
echo "Compiling test runner..."
swiftc ClaudeStrip/Sources/Core/*.swift Tests/main.swift -o build/test-runner

echo "Running tests..."
./build/test-runner
