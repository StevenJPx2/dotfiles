# Config Schema

How application configs are defined in this dotfiles system.

## Location

Each managed application has a directory: `configs/<app-name>/`

## config.json Schema

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `install_path` | string | **YES** | Target path. Supports `~` expansion. |
| `pre_install` | string | no | Shell command run BEFORE copying files |
| `post_install` | string | no | Shell command run AFTER copying files |

### Schema Definition

File: `scripts/config_dict.py`

```python
class ConfigDict(TypedDict, total=False):
    install_path: str
    pre_install: str
    post_install: str
```

## Examples

**Minimal** (most configs):
```json
{"install_path": "~/.config/fish"}
```

**With hooks** (when setup/reload is needed):
```json
{
  "pre_install": "[ -d ~/.tmux/plugins/tpm ] && : || { git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm; }",
  "install_path": "~/.config/tmux",
  "post_install": "tmux source ~/.config/tmux/tmux.conf"
}
```

**Non-standard install path** (like k9s which uses Application Support):
```json
{
  "pre_install": "rm -rf ~/Library/Application\\ Support/k9s/",
  "install_path": "~/.config/k9s",
  "post_install": "ln -s ~/.config/k9s/ ~/Library/Application\\ Support/k9s"
}
```

**Direct to parent directory** (like starship which expects `~/.config/starship.toml`):
```json
{"install_path": "~/.config/"}
```

## File Conventions

| Convention | Example | Result |
|------------|---------|--------|
| `dot_` prefix becomes `.` | `dot_gitconfig` | `.gitconfig` |
| `config.json` is never copied | - | It's metadata only |
| Directory structure preserved | `configs/fish/functions/foo.fish` | `~/.config/fish/functions/foo.fish` |

## Creating a New Config

```bash
just create <name>
```

This creates `configs/<name>/config.json` with default content:
```json
{"install_path": "~/.config/<name>"}
```

Then add your config files to `configs/<name>/`.

## When to Use Hooks

| Scenario | Hook | Example |
|----------|------|---------|
| Clone dependencies first | `pre_install` | tmux plugin manager |
| Clean up conflicting paths | `pre_install` | k9s Application Support symlink |
| Reload service after deploy | `post_install` | skhd, yabai restart |
| Source new config | `post_install` | tmux source |
| Create symlinks | `post_install` | k9s to Application Support |

## Current Configs

| Name | Install Path | Hooks |
|------|--------------|-------|
| alacritty | `~/.config/alacritty` | - |
| fish | `~/.config/fish` | - |
| ghostty | `~/.config/ghostty` | - |
| git | `~/.config/git` | - |
| gowall | `~/.config/gowall` | - |
| k9s | `~/.config/k9s` | pre + post (symlink to Application Support) |
| neovim | `~/.config/nvim` | - |
| opencode | `~/.config/opencode` | - |
| posting | `~/.config/posting` | - |
| skhd | `~/.config/skhd` | post (restart service) |
| smug | `~/.config/smug` | - |
| starship | `~/.config/` | - |
| tmux | `~/.config/tmux` | pre (clone tpm) + post (source) |
| yabai | `~/.config/yabai` | post (restart service) |
| yazi | `~/.config/yazi` | - |
