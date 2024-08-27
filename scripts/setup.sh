#!/bin/sh

export PATH="$PATH:/opt/homebrew/bin"

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

xcode-select --install
