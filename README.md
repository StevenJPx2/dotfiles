# dotfiles

This is the home place for my dotfiles.

## 💪 Features

- Entirely bootstrapped
- No dependencies
- `install.sh` to run on new machines.

## Setup

Run:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/StevenJPx2/dotfiles/main/install.sh)"
```

And enjoy! 🎉

## Development

- First ensure you have [`brew` installed](https://brew.sh/).
- [Install `just`](https://github.com/casey/just) if you do not have it installed yet.

### Update Brewfile

```sh
just bundle
```

### New Config Setup

```sh
just create [[name]]
```

This will then create a folder in `configs/` with a default `config.json`.

> [!NOTE]
> If you have a dot-preceding `.` dotfile, for visibility sake, you can replace it with `dot_`.
> Ex: `.tmux.conf` -> `dot_tmux.conf`
> This will auto-translate it to the correct file name.

### Update all configs

```sh
just update
```

This will also diff the files with your current config and ensure you are informed of all the changes you'll be making.

#### Update all configs, skipping the diff

```sh
just update -y
```

### Update a single config

```sh
just update [[name]]
```
