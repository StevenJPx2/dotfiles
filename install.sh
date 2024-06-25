#!/bin/sh

echo "Installing brew..."

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

echo "Installed brew! 🎉"

# ~~~~~~

echo "Installing brew bundle..."

cp ./Brewfile ~/Brewfile
brew bundle install

echo "Installed brew bundle!"

# ~~~~~~

gum spin --title "Moving configs to locations.." --spinner monkey -- just config

echo "Success! 🎉"

# ~~~~~~
