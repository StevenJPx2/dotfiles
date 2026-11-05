---
name: desktop
description: >-
  Use before any task that operates the user's Mac outside a web page: clicking or reading a native or Electron app's UI, menus, menu bar items, dialogs, sheets, System Settings, Finder, notifications, window layout, app screenshots, launching or quitting apps, or reading Calendar, Contacts, Reminders, Messages, Maps or Shortcuts. Picks between agent-desktop (the default for app UI), iMCP, osascript, yabai and the Affinity MCP, and holds the agent-desktop rules. Use it even when the user just says "open X and…" or "click the button in Y". For web pages use the browsers skill.
---

# Desktop

Pick the narrowest tool that answers the task. A data API beats an app's UI,
and an exact AppleScript command beats clicking, because both are verifiable
and cannot misclick. Drive the UI with agent-desktop when nothing narrower
exists.

macos-harness was retired in favour of agent-desktop. Don't install it or
script raw CGEvent input, `cliclick` or System Events keystrokes as a
substitute.

| Task | Tool |
|---|---|
| Calendar events, contacts, reminders, Messages history, maps, weather, location | `iMCP` MCP (`tools.iMCP.*`) |
| Run one of the user's Shortcuts | iMCP `shortcuts_list` / `shortcuts_run` |
| Affinity documents | `affinity` MCP |
| A known, exact command in a scriptable app (Music, Finder, Mail, Notes, Safari) | `osascript` |
| Tile, move, focus or send windows to a space | `yabai -m` (it owns the layout) |
| Any other native or Electron app UI: buttons, fields, menus, sheets, alerts, menu bar, Notification Center, app screenshots | `agent-desktop` CLI |
| Web pages, even inside Yab or Safari windows | the `browsers` skill |

## agent-desktop

A CLI that reads and acts on the macOS accessibility tree. It is a tool, not an
agent: you run the observe, act, verify loop. Every command prints one JSON
envelope (`ok`, `data` or `error`).

Its skills are compiled into the binary and match its version exactly, so load
them from the CLI rather than relying on memory or a synced copy:

```bash
agent-desktop skills get desktop      # core loop, refs, retry rules (read once per task)
agent-desktop skills get platform     # macOS differences: surfaces, headed mode, keys
agent-desktop skills get desktop <commands-observation|commands-interaction|commands-system|workflows>
agent-desktop <command> --help        # flags; the skills don't repeat them
```

Skill text is in `.data.content`; pipe through `jq -r .data.content`.

### The loop

```bash
agent-desktop snapshot --skeleton --app "Notes" -i --compact   # shallow map of a big app
agent-desktop snapshot --root @s8f3k2p9:e3 -i --compact        # drill into one region
agent-desktop click @s8f3k2p9:e12                              # act on a qualified ref
agent-desktop snapshot --root @s8f3k2p9:e3 -i --compact        # verify: re-read that region
```

- Use `find --role --name --exact` when you already know the target; a small
  app needs only a plain `snapshot -i`.
- Refs (`@<snapshot_id>:e<N>`) are valid for one snapshot. After any change,
  re-drill. `STALE_REF` or `SNAPSHOT_NOT_FOUND` mean snapshot again;
  `AMBIGUOUS_TARGET` means narrow with `find` or `--root`.
- An action that opens a menu, sheet, alert or popover lists it in
  `data.surfaces`. Target that surface next (`--surface menu|sheet|alert`);
  refs from the window behind it are the wrong target. Use `--surface menubar`
  for File/Edit/View menus and menu bar apps. Never skeleton a surface.
- Wait for async UI with `wait` (or `--wait-for role:text` on the action
  itself), not `sleep`.
- When several agents share the Mac, give each its own `--session` (or
  `AGENT_DESKTOP_SESSION`) so their refs don't collide.
- Judge success by re-reading state (`get`, `is`, a fresh snapshot). On macOS an
  AX call can return success and do nothing.
- Chain several deterministic steps with `batch` to save round trips, and stop
  at real decision points: new refs, an irreversible action, unexpected state.

### Safety

- **Retry only when `disposition.retry` is `safe`** (delivery `not_delivered`).
  Anything else may have landed: read live state before deciding, and never
  repeat a click, keystroke, `toggle` or submission that might have gone
  through.
- **Stay headless.** Default ref actions are semantic: they don't take focus,
  move the pointer, synthesize keys or touch the clipboard. `--headed` sends
  real input and steals focus; use it only when the user allows physical
  input (double-click, hover, drag need it). Never switch to `--headed` to
  recover from a headless failure; try another route or stop.
- `launch` opens apps and `close-app` quits them; prefer acting on what is
  already open, and ask before quitting an app with unsaved work. Quit
  shortcuts return `POLICY_DENIED` without `--force`; don't force them.
- Ask before sending, deleting, purchasing or changing system settings, as you
  would on the web.
- Keep snapshots, screenshots, notification text and clipboard contents out of
  logs, commits and uploads; they often hold private data.

### Permissions

`agent-desktop permissions` checks without prompting. Accessibility is needed
for everything; Screen Recording only for `screenshot`; Automation only where
a command reports it. If one is missing, tell the user and ask before running
`agent-desktop permissions --guide` (opens System Settings with a drag-in
panel). Prefer the accessibility tree over screenshots anyway: it is cheaper
and gives refs you can act on.

When something fails, read `agent-desktop skills get platform troubleshooting`
before improvising.

## osascript

Use it for an exact, focus-safe command the app's dictionary exposes:

```bash
osascript -e 'tell application "Music" to playpause'
osascript -e 'tell application "Finder" to get name of every window'
```

Check the dictionary (`sdef /System/Applications/Music.app | rg -i <term>`)
instead of guessing verbs. Don't use `tell application "System Events" to
keystroke` or `click at`; that is blind UI scripting, which agent-desktop does
with refs and verification. A first call to a new app may raise an Automation
prompt the user must approve.

## yabai

yabai manages window layout here (`configs/yabai/yabairc`, keys in
`configs/skhd/skhdrc`). Query with `yabai -m query --windows --space` and move
with `yabai -m window --focus|--warp|--space`. agent-desktop's
`move-window`/`resize-window` fight the tiler; use them only on windows yabai
doesn't manage.
