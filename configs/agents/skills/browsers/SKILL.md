---
name: browsers
description: >-
  Use before any web task to pick the tool: browser-harness for the user's real Chrome (logins, profiles, tab groups); the agent-browser MCP for public sites, forms and multi-step flows in its own headless Chrome; lightpanda fetch or Jina read_url to read a public page as text; the safari MCP for Safari. GitHub, Jira and Slack use their own CLIs.
---

# Browsers

Pick one tool per task. When unsure, ask: does this need the user's logins?

| Task | Tool |
|---|---|
| Anything logged in, another Chrome profile, tab groups, evidence for a ticket | `browser-harness` (see its skill) |
| Public site: click through pages, fill forms, test a web app, screenshots or video | `agent-browser` MCP |
| Read one public page as text | Jina `read_url`; `lightpanda fetch` for pages that need JavaScript |
| Safari behaviour | `safari` MCP |
| GitHub, Jira, Slack | Their CLIs or skills, not a browser |

## agent-browser

`tools["agent-browser"].*` in Code Mode. It runs its own headless Chrome for
Testing with an empty profile, so it never touches the user's Chrome.

- After each navigation, take a snapshot and act on its `@e` refs. Refs expire
  when the page changes.
- Keep snapshots small: interactive elements only, scoped to a selector, or a
  limited depth. Use eval to extract data instead of reading a whole snapshot.
- Parallel agents share the `opencode` session by default. Pass a distinct
  `session` on every call when several agents browse at once.
- Close the session when done.
- Known bugs in 0.39.1:
  - A click can report success and do nothing (#2146). After a click that
    matters, check the URL or text changed.
  - The first command right after a close can fail with `EOF` (#2138). Retry
    once.
- Don't attach it to the user's Chrome (`--auto-connect`, `--cdp`). That's
  untested here, and #2146 makes clicks miss in background tabs.
- Don't use `--engine lightpanda` for extraction. It returns empty results
  without an error.
- For a site login, prefer browser-harness. Only export cookies with
  `state save` if the user agrees: the file holds session tokens in plain
  text.
- The MCP loads only the `core` tools. For anything else, such as video, run
  the CLI on the same session; it reaches the MCP's browser:
  `agent-browser --session opencode record start <file.webm>`. The full guide
  is `agent-browser skills get core`.

## Reading a page as text

- Static docs, blogs, Wikipedia: Jina `read_url`. Its output is cleaner.
- Public pages that need JavaScript:

  ```bash
  lightpanda fetch --dump markdown --strip-mode clutter \
    --wait-until networkidle --fail-on-http-error <url>
  ```

  Add `--wait-selector "<css>" --wait-ms 15000` when content loads late. Drop
  `--strip-mode clutter` if the page looks cut short.
- Treat empty output, exit 1 with `BotChallenge`, or a "Just a moment" page as
  a failure, and fall back to Jina.
- Never use Lightpanda for logged-in or private pages.
