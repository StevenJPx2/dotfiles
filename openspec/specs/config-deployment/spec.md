# Config Deployment

How configs are deployed from this repo to the system.

## Entry Points

| Command | Description |
|---------|-------------|
| `just update` | Deploy ALL configs (with diff prompts) |
| `just update <name>` | Deploy single config |
| `just update -y` | Deploy all, skip diff prompts |
| `just update -r` | Replace mode: delete target directory first |

## Deployment Flow

```
just update [name]
     |
     v
scripts/place_configs.py
     |
     v
+------------------------------------------+
|  For each configs/*/config.json:         |
|                                          |
|  1. Parse config.json                    |
|  2. Run pre_install command (if defined) |
|  3. Create install_path directory        |
|  4. For each file (except config.json):  |
|     a. If file exists at target:         |
|        - Show unified diff               |
|        - Prompt: accept changes? [Y]/N   |
|     b. Copy file to target               |
|        (rename dot_ prefix to .)         |
|  5. Run post_install command (if defined)|
|                                          |
+------------------------------------------+
```

## Key Files

| File | Purpose |
|------|---------|
| `scripts/place_configs.py` | Main deployment logic |
| `scripts/config_dict.py` | TypedDict schema for config.json |
| `scripts/new_config.py` | Scaffolds new config directories |
| `Justfile` | Command interface |

## Behavior Details

**Path expansion**: `~` is expanded to home directory via `Path.expanduser()`

**Diff checking**: Only triggers when:
- Target file already exists
- `-y` flag is NOT set
- File is text (binary files skip diff)

**Replace mode** (`-r`): Deletes entire `install_path` directory before copying. Use when you want a clean slate.

**Binary files**: Files that raise `UnicodeDecodeError` are copied without diff checking.

## Debugging

### Config Not Deploying

1. **Verify config.json is valid JSON**
   ```bash
   cat configs/<name>/config.json | python -m json.tool
   ```

2. **Check install_path is set**
   ```bash
   jq '.install_path' configs/<name>/config.json
   ```

3. **Run deployment and watch output**
   ```bash
   just update <name>
   ```
   Look for:
   - "running `<command>`" messages (hooks executing)
   - Python tracebacks (exceptions)
   - Diff output (file conflicts)

### Pre/Post Install Failing

Hooks run via `subprocess.run(command, shell=True)`.

Common issues:
- **Command not found**: PATH may not include expected directories
- **Permission denied**: Command needs sudo or different permissions
- **Missing dependencies**: Required tool not installed

Debug by running the hook command manually:
```bash
# Copy the command from config.json and run it directly
```

### Files Not Appearing at Target

Check:
1. Is the file named `config.json`? (Always skipped - it's metadata)
2. Did you answer "N" at a diff prompt? Re-run with `just update <name>`
3. Is target directory writable? Check permissions on `install_path`

### Wrong File Names

If a file should start with `.` but doesn't:
- Rename it in the repo to use `dot_` prefix
- Example: `.gitignore` should be stored as `dot_gitignore`

### Stale Files at Target

Deployment only copies/overwrites - it doesn't delete removed files.

To fully sync (delete + copy):
```bash
just update <name> -r
```

Warning: This deletes the entire target directory first.
