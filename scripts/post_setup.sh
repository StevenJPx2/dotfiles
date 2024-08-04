#!/bin/sh

# Rust
rustup-init
source "$HOME/.cargo/env.fish"
# Fish
curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher
