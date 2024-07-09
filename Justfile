update:
  python3.8 scripts/place_configs.py

bundle:
  brew bundle dump --formula --cask --tap --mas --describe -f
