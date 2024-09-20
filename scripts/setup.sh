#!/bin/sh

export PATH="$PATH:/opt/homebrew/bin"

# Fish settings
if grep -q /opt/homebrew/bin/fish /etc/shells; then
  echo "Fish is already installed"
else
  echo /opt/homebrew/bin/fish | sudo tee -a /etc/shells
fi

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

xcode-select --install
