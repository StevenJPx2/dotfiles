---
name: dotfiles
description: "Manage this dotfiles repository (StevenJPx2/dotfiles): bootstrap a machine, add or update a config package, run just recipes, and register remote skills. Use when editing configs/, scripts/, Brewfile, or skill sources; when running just update/bundle; or when onboarding a new machine."
---

# Dotfiles

This repo bootstraps a machine from `configs/` into `~/.config`, `~/.agents`, etc.
Each top-level entry under `configs/` is a package with a `config.json` describing
where it installs and optional pre/post commands.

## Layout

- `configs/<name>/config.json` — `{ "install_path": "~/.config/<name>", "pre_install", "post_install" }`
- `configs/<name>/...` — files to copy; a `dot_` prefix becomes `.` (e.g. `dot_zshrc` -> `.zshrc`)
- `configs/agents/skills/<skill>/SKILL.md` — local skills installed to `~/.agents/skills`
- `configs/chauffeur/skill-sources.json` — remote skill sources (git/http) + description overrides
- `configs/chauffeur/skill-exposure.json` — ranking (which skills are always considered)
- `scripts/place_configs.py` — installs packages (`just update`)
- `scripts/new_config.py` — scaffolds a package (`just create <name>`)
- `Justfile` — `update`, `bundle`, `create`, `refresh`, `install`

## Common tasks

### Add a new config package

```sh
just create <name>
# edit configs/<name>/config.json install_path
# drop files into configs/<name>/
just update <name>
```

### Update everything

```sh
just update          # diffs and prompts
just update -y       # skip prompts
```

### Update Brewfile

```sh
just bundle          # brew update && brew upgrade && brew bundle dump
```

### Add a remote skill

Remote skills are registered in `configs/chauffeur/skill-sources.json`, not via
`npx skills add`. Add a git source:

```json
{ "id": "<id>", "type": "git", "url": "https://github.com/<owner>/<repo>.git", "paths": ["skills/<name>"] }
```

Then optionally override its description under the `descriptions` object.
Skill folders must contain a `SKILL.md` with YAML `name` and `description`.

### Remove a skill

- Local: delete `configs/agents/skills/<name>/` and `~/.agents/skills/<name>/`
- Remote: remove the source (or path) from `skill-sources.json`

## Conventions

- `dot_` prefix auto-translates to `.` on install (see `place_configs.py`).
- `.git`, `.state`, `node_modules`, and `config.json` are skipped during install.
- Diff prompts appear unless `-y`/`--yes-all`.
- Skills live in `configs/agents/skills/` (local) or upstream repos (remote).
- Do not edit installed files under `~/.config`/`~/.agents` directly; edit here and re-run `just update`.

## This machine

- MacBookPro18,2: M1 Max, 32 GB. Not an M5 Pro, so never present local
  measurements as M5 Pro performance.

## Key files

- `scripts/place_configs.py` — install logic
- `scripts/update.sh` — `just update -y && just bundle`
- `install.sh` / `scripts/post_setup.sh` — first-machine bootstrap
