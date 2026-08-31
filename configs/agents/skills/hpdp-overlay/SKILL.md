---
name: hpdp-overlay
description: Develop, test, visually validate, and ship HPDP Overlay changes across merchant apps and shared packages. Use when working in the hpdp-overlay repository, on ADEPT tickets, merchant presets, Lit overlay UI, live merchant previews, or its PR workflow.
---

# HPDP Overlay Coding Workflow

Follow this workflow for every coding task in this repository. Read the nearest `AGENTS.md`
and `CLAUDE.md` files before editing. The repository uses a bare Git store with linked
worktrees; edit `main` or a task worktree, never the bare repository root.

## 1. Intake and monitor

- Identify every Jira key, merchant, requested behavior, and acceptance evidence.
- This repository uses a bare Git store at the repository root. The checked-out main worktree is
  `main/`; feature worktrees are sibling directories such as `ADEPT-43742/`. Run Git commands from
  a worktree, not from the bare root, and inspect the current branch before changing files:
  `git branch --show-current`, `git status --short`, `git worktree list`.
- For a new task, create an isolated sibling worktree beside `main/`:
  `./scripts/new-worktree ADEPT-12345` from the `main/` worktree, or
  `./main/scripts/new-worktree ADEPT-12345` from the bare repository root. The result must be
  `/path/to/hpdp-overlay/ADEPT-12345`, never a nested `hpdp-overlay-worktrees/` directory.
  Use a full branch name when needed, for example
  `./scripts/new-worktree fix/ADEPT-12345-filter -b main`.
- If a Jira key is present, create one Jira monitor per ticket with `monitor_create`.
- If an active PR exists, create one shared GitHub monitor for the PR.
- For Slack issue threads, prefer `slackcli` for intake and thread history. Read a thread with
  `slackcli conversations read <channel-id> --thread-ts <thread-timestamp> --json`; use
  `slackcli search messages "<query>"` to find related context. Never paste Slack credentials or
  private message payloads into source files, commits, or Jira comments. The CLI is available at
  https://github.com/shaharia-lab/slackcli.
 - Prefer `jira-cli` for gathering Jira data. Configure it once with `jira init` using the Cloud
   installation and `JIRA_API_TOKEN`; never print or commit the token. Use non-interactive output
   for agent work, for example:
  `jira issue view "$KEY" --comments 10`,
  `jira issue list --jql "key = $KEY" --raw`, and
   `jira issue list --plain --no-headers --columns key,summary,status,assignee`.
   Use `jira me` when the current Jira account is needed. Keep Atlassian MCP for mutations or
   operations jira-cli cannot expose. For attachments, use the raw issue response to extract
  metadata, then download the authenticated `.content` URL because jira-cli has no attachment
  download command:
  `jira issue view "$KEY" --raw | jq '.fields.attachment[] | {filename, content, thumbnail}'`;
  `URL=$(jira issue view "$KEY" --raw | jq -r '.fields.attachment[] | select(.filename == "<file>") | .content')`;
  `curl -fsSL -u "$ATLASSIAN_EMAIL:$ATLASSIAN_API_KEY" -o /tmp/<file> "$URL"`.
  Prefer the bundled helper for this workflow:
  `.agent/skills/hpdp-overlay/scripts/download-jira-attachment.sh "$KEY"` to list files,
  `.agent/skills/hpdp-overlay/scripts/download-jira-attachment.sh "$KEY" "<file>"` to download
  one, or add `--all` to download every attachment. It accepts `JIRA_EMAIL` or
  `ATLASSIAN_EMAIL` and `JIRA_API_KEY`, `JIRA_API_TOKEN`, or `ATLASSIAN_API_KEY` without exposing
   them. Never print or commit Jira credentials or downloaded ticket attachments. Reference:
   https://github.com/ankitpokhrel/jira-cli.
   Jira CLI authentication is shell-local: `jira init` writes the CLI configuration but does not
   persist the API token. If the agent's Bash shell reports that a token is required, use the
   configured Fish login shell (`fish -lc 'jira issue view "$KEY"'`) or export `JIRA_API_TOKEN`
   in the current shell before invoking `jira`. Do not assume a token exported by Fish startup
   files is visible to Bash tools.
  - First verify that the ticket requires a repository change. If the behavior is already correct,
    do not assign the ticket or transition it; document the verification in Jira and leave the
    existing ownership/status unchanged. When a repository change is required, assign the ticket
    to the current user and transition it to `In Progress` (transition id `31`). Verify both the
    assignee and status before editing.
  - Keep Jira comments and Slack thread replies short, informal, direct, and plain-language.
    Explain what was done or the current blocker without technical details unless specifically
    asked. Do not paste commands, commit hashes, selectors, implementation details, tool output,
    or unrelated verification steps into comments.
- For one PR covering multiple tickets, keep the tickets related and list every full key
  comma-separated in the branch, commit/PR title, and PR Jira section. Never use slashed shorthand.
- Treat routed monitor events as new requirements. Check the diff before acting on them.

## 2. Classify the change

Choose the smallest blast-radius tier:

- **T1**: one merchant preset, selector, label, or theme value.
- **T2**: merchant knowledge, scaffold, or shared pattern.
- **T3**: shared defaults or layouts.
- **T4**: config schema or public config contract.
- **T5**: core, UI, or shared types.

Prefer a merchant-specific fix. Promote a fix only when the behavior is demonstrably general.
For shared changes, list every affected merchant and add a regression plan.

## 3. Implement with tests first

- Form a failing test for the behavior before production code.
- Use factory functions for test data. Avoid `let` and `beforeEach`.
- Respect boundaries: config has no DOM knowledge; UI never reads host-page DOM; core owns
  host DOM discovery, observers, and event forwarding.
- Use TypeScript strict mode, Valibot for schemas, Lit for UI, Bun for commands, and Biome
  for formatting. Do not add `any`, `@ts-expect-error`, unrelated refactors, or compatibility
  shims.
- Keep functions and files within the lint budgets in `AGENTS.md`.
- Add a changeset for changes under `packages/*`; merchant apps and docs do not need one.

## 4. Validate locally

Run the narrowest relevant checks first, then the full gates:

```bash
bun run typecheck
bun run lint
bun run test
bun run test:coverage
bun run format:check
bun run build
```

For config changes also run `bun run validate-configs`. For shared or deployment changes run
`bun run precheck`, `bun run validate-deploy-manifest`, and the relevant package/build checks.
Report coverage against the repository thresholds: 95% lines/functions/statements and 88%
branches. Never claim a visual change is verified from tests alone.

## 5. Verify user-visible changes live

- Start the appropriate base merchant dev server from the existing `main/` worktree and inspect its
  status. From the bare `./hpdp-overlay` root use `(cd ./main && bun run dev)`; from a sibling task
  worktree use `(cd ../main && bun run dev)`. Do not create another worktree for `main`. Run feature
  builds and feature-side verification from the task worktree.
- For CSP-strict merchants, use `bun run live-overlay <merchant> [url]`; do not substitute a
  localhost injection that the merchant CSP will block.
- Before browser work, run `chrome-use browsers` and select the existing connected Chrome profile.
  Pass `--browser <id>` to every command. Reuse its current tab, cookies, IP, and human-verification
  state; do not launch a new browser, create a new profile/session, open `about:blank`, or clear
  cookies between attempts.
- Confirm the selected profile's identity (for example, `steven@adeptmind.ai`) and inspect its tabs
  before testing. If restarting Chrome leaves only a blank tab or no warm merchant session, state
  that caveat explicitly; do not describe the reopened profile as an existing warm session.
- Verify the HPDP overlay itself, not only the host merchant PDP. Inject or load the applicable
  overlay bundle, confirm `#am-overlay` is mounted, and exercise the changed behavior through the
  overlay before recording a result.
- For iOS Safari coverage, this fork of agent-browser supports Appium/XCUITest through
  `chrome-use -p ios`: check devices with `chrome-use -p ios device list`, then use
  `chrome-use -p ios --device "iPhone 15 Pro" open <url>`, `snapshot`, `tap`, and `screenshot`.
  This is a separate iOS session, not the existing desktop Chrome session. It requires Xcode,
  an installed iOS runtime, Appium, and the XCUITest driver. A simulator validates Safari layout
  and Apple Pay button visibility; do not claim real wallet authorization without an Apple Pay
  sandbox profile or a configured physical device.
- The desktop chrome-use provider controls Chrome, not macOS Safari. Desktop Apple Pay sheet
  verification requires an actual Safari session with Apple Pay configured.
- Unless the user explicitly asks not to, validate every UI change at mobile, tablet, and
  desktop resolutions. Use the available browser CLI/MCP to check the exact changed state at
  390px, 1024px, and 1440px.
- Compare the rendered result with the Jira/Figma reference, not only source code.
- Code review and live browser verification are both mandatory gates. For every user-visible
  ticket, including a no-op verification, review the relevant source/tests/diff and check the
  rendered state at 390px, 1024px, and 1440px before documenting the result. Existing code,
  history, or passing tests cannot substitute for the live checks.
- Capture focused evidence per visual change. Static changes need matched Before/After views;
  interaction changes need a focused recording. Reject blank, clipped, full-page, or unrelated
  captures. For the full capture/upload workflow follow the `pr-screenshots` skill
  (repo `.agent/skills/pr-screenshots`); the bullets below are the short form.
- Use `chrome-use` for the evidence artifact. For static changes, capture the same focused
  selector on the base and feature branches:
  `chrome-use screenshot "<selector>" /tmp/<ticket>-before.png` and
  `chrome-use screenshot "<selector>" /tmp/<ticket>-after.png`.
- Focused evidence must include the actual trigger/control and the changed result together.
  For a popover or tooltip, the crop must show the icon/button that opens it and the popover's
  relationship to that control; a crop containing only the floating panel is insufficient.
- If `chrome-use --clip` coordinates do not match CSS coordinates, capture the full viewport first
  and crop the identical pixel rectangle from both images with `sips`. Inspect both resulting
  images before uploading; reject crops that hide the trigger, clip the result, or show unrelated
  content.
- For interaction changes, record only the reproduction flow. Start recording without a URL,
  drive the already-open page, then stop it:
  `chrome-use record start /tmp/<ticket>.webm` -> interact ->
  `chrome-use record stop`.
- Record from a clean, deliberate state so the recorder captures real motion, not a near-static
  frame. Reset first (reload + re-inject, or close any open modal) so the flow starts fresh, keep
  the viewport fixed for the whole take, and put a visible pause (`chrome-use wait 1000`-`2000`)
  between each step (scroll into view -> click -> focus -> type -> submit -> results). The
  DOM-driven UI settles fast, so back-to-back commands with no waits produce only a handful of
  unique frames.
- Before sharing a recording, confirm it actually has motion:
  `ffmpeg -i /tmp/<ticket>.webm -vf "mpdecimate,showinfo" -f null - 2>&1 | grep -c "n:"`. A count
  in the low single digits means the take was effectively static — re-record with the deliberate
  pauses above rather than shipping a frozen clip.
- To share a recording as a link (e.g. a Jira/Slack request), convert the WebM to an animated GIF
  and upload the GIF to PIXHOST — ImgBB FLATTENS animated GIFs to a single static frame on
  upload, so a GIF via ImgBB renders frozen in the PR (verified 2026-08-06, ADEPT-43739).
  PNG screenshots go to ImgBB; only animated GIFs go to pixhost. Convert with
  `ffmpeg -y -i /tmp/<ticket>.webm -vf 'fps=12,scale=900:-1:flags=lanczos' -loop 0 /tmp/<ticket>.gif`
  (add `tpad=start_mode=clone:start_duration=1,tpad=stop_mode=clone:stop_duration=1.5` plus
  step-label overlays so a looped flow is readable), then upload with
  `curl -fsS https://api.pixhost.to/images -F "img=@/tmp/<ticket>.gif;type=image/gif" -F "content_type=0" -F "max_th_size=600" | jq -r '.show_url'`
  and scrape the direct `https://imgN.pixhost.to/images/...gif` URL from the show page — embed the
  DIRECT URL in PR bodies (GitHub renders it inline; the show page is fine for chat).
- Verify the hosted GIF actually animates before sending it: download the URL and count frames
  with `ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of csv=p=0` —
  a count > 1 means it animates.
- Upload image evidence with ImgBB through `imgup`, not `gh-image` or GitHub release assets:
  `imgup -H imgbb -f plain --no-clipboard /tmp/<ticket>-before.png /tmp/<ticket>-after.png`.
  Ensure `IMGBB_KEY` is configured before uploading. Put the returned URLs in a matched
  Before/After table in the PR body. If ImgBB is unavailable, use `imgup -H pixhost` as a
  temporary fallback and note that in the PR. Never commit screenshot files or create a
  GitHub release for evidence.
- For a deployed PR preview from `amt.adeptmind.ai`, inject the IIFE as a classic script tag,
  not with dynamic `import()`. The preview CDN does not send CORS headers, so `import()` fails:
  `const s = document.createElement("script"); s.src = "https://amt.adeptmind.ai/pr-<N>/opo/<merchant>.js?v=" + Date.now(); s.onload = () => window.adeptmind.opo.enable(); document.head.appendChild(s);`.
- Before using a deployed preview, confirm the PR has the matching `preview:<merchant>` label and
  use `https://amt.adeptmind.ai/pr-<N>/opo/<merchant>.js`. Verify the response is JavaScript
  before opening the browser flow; after injection verify `#am-overlay` mounts.
- Verify every hosted evidence URL with a successful image response and inspect the rendered image
  in the PR. Prefer ImgBB; if ImgBB is under maintenance, use `imgup -H pixhost` and record the
  fallback in the PR. Do not use anonymous Imgur or Catbox as an unverified fallback.
- If the merchant blocks automation, record the exact block and use mocks/code/tests only as a
  stated fallback. Never claim live verification that did not happen.

## 6. Review and ship

- Inspect `git diff` and `git diff --check`; justify every changed file.
- Rebase from `origin/main` before opening a PR. Never use destructive reset or checkout commands.
- Use `type/short-description` branch names with full ADEPT keys when applicable.
- Use conventional commits for both commit messages and PR titles. A PR title must use
  `<type>(<scope>): <imperative description>`; append full Jira keys only after the description,
  for example `fix(lululemon): hide initial size validation notice [ADEPT-43742]`. Keep the PR
  focused and include Summary, Jira, Changesets, Test plan, and concise visual evidence. Apply the
  appropriate `preview:<merchant>` label.
- Before asking for a merge to QA, post the PR in `#hpdp-engineering` with this format: tag
  `@hpdp-eng`, include the PR link, then `ptal` (please take a look). Add `urgent` when urgent,
  `ez` for an easy review, or `vez` for a very easy review such as a small CSS/config change.
  If QA has approved separately, add a short line saying `<name> has approved`. If there is a
  blocker, state it in a short, informal, all-lowercase line. End with a very short description of
  what the PR does. Keep the post informal and direct. For Slack, mention the group with
  `<!subteam^S04M6UL597A>` (the `@hpdp-eng` user group), and build multiline messages with
  `printf '%s\n'` or actual newlines; never send literal `\n` text.
- After opening the PR, transition every covered Jira ticket from `In Progress` to `In Review`
  (transition id `51`). Never transition tickets to `In QA`, `In Staging`, `Ready for Production`,
  or `Completed`; a passing CI event does not change Jira status.
- Run the repository PR gates from `.claude/skills/pr/SKILL.md` before pushing.
- Push only after all required gates pass. Monitor the active PR until review and CI events are
  resolved; let the running agent judge each routed event and record the resulting action.

## Stop conditions

Stop and report instead of guessing when the ticket, target merchant, acceptance reference,
worktree, or live-render result is ambiguous. Preserve unrelated user changes and never revert
them.
