script file *args:
  python3 scripts/{{file}} {{args}}

create +args:
  just script new_config.py {{args}}

update *args:
  just script place_configs.py {{args}}

setup:
  ./scripts/setup.sh

post_setup:
  ./scripts/post_setup.sh

install:
  brew bundle install -f --cleanup
  just post_setup

bundle:
  brew update
  brew upgrade
  brew bundle dump --formula --cask --tap --describe -f
