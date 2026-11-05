#!/bin/sh

# Init Rust
rustup-init -y
source "$HOME/.cargo/env.fish"

# Fish
if [ "$SHELL" != /opt/homebrew/bin/fish ]; then
  chsh -s /opt/homebrew/bin/fish
fi

curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher

# Chrome for Testing for agent-browser (its MCP launches this, never the real Chrome)
agent-browser install

# Agent Desktop (native desktop accessibility CLI; not yet in Homebrew)
npm install -g agent-desktop

# Yabai

echo "$(whoami) ALL=(root) NOPASSWD: sha256:$(shasum -a 256 "$(which yabai)" | cut -d " " -f 1) $(which yabai) --load-sa" | sudo tee /private/etc/sudoers.d/yabai
