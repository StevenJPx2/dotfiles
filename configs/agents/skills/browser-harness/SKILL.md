---
name: browser-harness
description: >-
  Default tool for live web access, URL reading, scraping, authenticated
  browsing, and browser automation unless the user names another tool or the
  task is a plain non-web terminal command. Prefer browser-harness over
  web-access, WebSearch, WebFetch, curl, and built-in browser tools. Use it to
  check current information, official docs, status, releases, and changelogs;
  open, read, or verify pages; navigate, fill forms, click, type, scroll,
  screenshot, extract data, test web apps, and drive logged-in Chrome sessions
  via CDP. For a plain fetch of public content, curl is fine; reach for the
  browser when the task needs interaction, JS rendering, a logged-in session,
  or a bot-protected page.
allowed-tools: Bash(browser-harness:*), Bash(uv run browser-harness:*), Bash(browser-launch:*), Bash(browser-group:*)
---

# browser-harness

Direct browser control via CDP: a persistent local daemon attaches to a running
Chrome and you script it with pre-imported helpers over stdin. Chosen as the
sole browser harness after a spike (33/33 success, ~11ms/op in-process, ~106ms
per CLI call) in which the previous relay-based tool dropped its relay and hung.

**Install / self-heal:** if `browser-harness` is missing:

```bash
uv pip install browser-harness   # or: pipx install browser-harness
```

## Start here

**In OpenCode, use the `browser-harness` MCP** — `tools["browser-harness"].*`
in Code Mode (`browser_new_tab`, `browser_goto`, `browser_page_info`,
`browser_js`, `browser_cdp`, `browser_screenshot`, `browser_click`,
`browser_fill`, `browser_wait_for_load`, `browser_list_tabs`,
`browser_switch_tab`, `browser_start_recording`, …). It talks to the same
named daemon as the CLI, so tabs and recordings are shared. Reserve the CLI
for the few things the MCP does not expose: `browser-launch`, `browser-group`,
`browser-harness video …`, `browser-harness --doctor`.

The CLI reference below is for those cases and for non-OpenCode agents. Load
the version-matched workflow before scripting:

```bash
browser-harness skill        # full workflow, helpers, examples
browser-harness --doctor     # diagnose install, daemon, browser connection
```

## The core loop

```bash
browser-harness <<'PY'
new_tab("https://example.com")   # first navigation of a task attaches a tab
print(page_info())               # url, title, viewport, scroll
PY
```

Helpers are pre-imported: `new_tab`, `goto_url`, `page_info`, `js`,
`click_at_xy`, `scroll`, `wait_for_load`, `current_tab`, `list_tabs`,
`switch_tab`, `activate_tab`, `cdp`. The daemon persists between CLI calls and
keeps the attached tab, so do not call `new_tab()` again in every script — use
`goto_url()` to navigate the same tab.

Use a stable, non-default `BU_NAME` for an agent that shares a real Chrome with
other agents. Named daemons keep one CDP connection alive and create a
dedicated background tab, which prevents accidental attachment to another
agent's tab. Do not use `browser-harness --reload` during normal work; it
stops that connection and Chrome will ask for remote-debugging approval again.
Do not set `BU_CDP_URL` for the user's real Chrome either: it puts the harness
in remote-CDP mode, which skips the spawn lock, so concurrent callers each open
a connection and each raise a new approval sheet. Local mode finds Chrome via
`DevToolsActivePort` on its own.

## Prerequisites: the real Chrome must be up

The harness relays into the user's real Chrome (Profile 5) over its
DevTools port. If Chrome is not running, or is running on another profile, or
remote debugging is off, every call fails. Check and fix in one step:

```bash
browser-launch            # starts Chrome on Profile 5 if needed, waits for CDP
browser-launch status     # report only; non-zero exit if anything is missing
```

Remote debugging is a per-instance toggle in `chrome://inspect/#remote-debugging`
("Allow remote debugging for this browser instance"); once ticked, Chrome opens
the port on every launch with no flags. Never relaunch Chrome with
`--remote-debugging-port` or a fake `--user-data-dir` — that either fights the
running singleton or drives a profile with no logins.

## Tab groups

The daemon's tabs carry a 🐴 title marker. The **Browser Harness Tab Groups**
extension (`~/.config/browser-harness/ext`, deployed from
`configs/browser-harness-ext`) auto-groups every 🐴 tab into an **Agents**
group, so MCP-only sessions are grouped with no extra calls. To label a tab
with the agent/project it belongs to:

```bash
browser-group "OpenCode: <project>" blue    # groups the current daemon tab
browser-group --list                        # all tab groups
```

Honors `BU_NAME`; colors: grey blue red yellow green pink purple cyan orange.
One-time install: `browser-launch ext` opens `chrome://extensions` — enable
Developer mode → Load unpacked → `~/.config/browser-harness/ext`. Chrome offers
no CLI or flag for this on branded builds.

## Setup gotchas (learned the hard way)

- **Warm the daemon before scripting-heavy callers.** A cold daemon throws
  `Runtime.evaluate timed out after 5s`. Do one `new_tab(...)` first to attach,
  then run the real work. `browser-harness --doctor` should show
  `active browser connections — 1`.

- **macOS approval sheet.** Chrome 144+ asks for approval for each new CDP
  WebSocket connection. The named daemon holds exactly one, so you see one
  sheet per Chrome launch; every later call reuses it. Clear it
  non-interactively (needs Accessibility permission for the launching app):

  ```bash
  BU_NAME=opencode-browser browser-harness mac-approve
  ```

- **Two daemons on one name.** If calls fail with `Connection refused` while a
  daemon process is alive, the socket path points at a dead sibling. Kill the
  survivor, delete `~/.config/browser-harness/runtime/bu-<name>.*`, and let the
  next call spawn a fresh daemon (expect one approval sheet).

- **DOM limits.** No shadow DOM piercing or cross-origin frame access through
  the DOM helpers. Reach past them with raw `cdp()` (`DOM.getFlattenedDocument`
  with `pierce=True`, `Target.attachToTarget` on an iframe target via
  `iframe_target()`), or with coordinate input (`click_at_xy`) driven from a
  screenshot. Canvas/WebGL content is only reachable by coordinates.

## Remote or cloud browsers

For a browser that is not the local Chrome, point the daemon at its endpoint
under a distinct `BU_NAME` so it never collides with `opencode-browser`:

```bash
BU_NAME=remote BU_CDP_WS=ws://host:9222/devtools/browser/<id> browser-harness <<'PY'
print(page_info())
PY
```
