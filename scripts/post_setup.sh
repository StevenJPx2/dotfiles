#!/bin/sh

# Init Rust
rustup-init -y
source "$HOME/.cargo/env.fish"

# Fish
if [ "$SHELL" != /opt/homebrew/bin/fish ]; then
  chsh -s /opt/homebrew/bin/fish
fi

curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher

# Yabai

echo "$(whoami) ALL=(root) NOPASSWD: sha256:$(shasum -a 256 "$(which yabai)" | cut -d " " -f 1) $(which yabai) --load-sa" | sudo tee /private/etc/sudoers.d/yabai
