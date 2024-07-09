script file *args:
  python3 scripts/{{file}} {{args}}

create +args:
  just script new_config.py {{args}}

update *args:
  just script place_configs.py {{args}}

bundle:
  brew bundle dump --formula --cask --tap --mas --describe -f
