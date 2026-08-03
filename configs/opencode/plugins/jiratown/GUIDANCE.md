# jiratown — monitoring guidance

jiratown is a monitor plugin. It lets you create **monitors** that watch a Jira issue or a
GitHub PR and route NEW events into the session you're currently working in, so you can react
to them as they happen.

## When to create a monitor

- **You found or are working on a Jira ticket** → create a Jira monitor for its issue key. You
  will be notified of new comments, description edits, and status/assignee/priority changes.
- **You are on a branch with an active PR (or just opened one)** → create a GitHub monitor for
  `repo#prNumber`. You will be notified of new reviews (including bot reviews), PR and
  line-level comments, CI failures, merge conflicts, and the PR being merged or closed.

## How to create one

Use the `monitor_create` tool:

- Jira: `monitor_create({ name: "<key>", sourceType: "jira", issueKey: "ADEPT-12345" })`
- GitHub: `monitor_create({ name: "<pr>", sourceType: "github", repo: "owner/name", prNumber: 42 })`

Defaults to `delivery: "poll"` (checks every 60s). Use `delivery: "webhook"` for live push when
the webhook listener is configured. You can lower `pollIntervalSec` (min 15) for time-sensitive
work, but prefer the default to avoid hammering the APIs.

## Lifecycle

- `monitor_list` — see all monitors.
- `monitor_status { id }` — detail on one.
- `monitor_stop { id }` — stop routing events for a monitor.

## When an event arrives

Events are fed into your session as a message (e.g. a new review comment, a CI failure, a Jira
status change). Treat it like any new input: read it, decide whether it needs action, and act
(or tell the user it needs a decision). If the event is non-actionable (e.g. CI all-passing),
acknowledge it and move on — do not fabricate work from it.
