import { tool } from "@opencode-ai/plugin"
import { createMonitor, type Delivery, type MonitorSource } from "../src/monitors.ts"
import { ensurePollLoop } from "../src/poll.ts"
import { getClient } from "../src/client.ts"
import { ensureWebhookServer } from "../src/webhook.ts"

export default tool({
  description:
    "Create a monitor that watches a Jira issue or GitHub PR and routes NEW events (comments, description/changelog changes, reviews, CI failures, merge conflicts, merge) into the current session so you can react to them. Delivery is 'poll' (periodic) or 'webhook' (live push).",
  args: {
    name: tool.schema.string().describe("Human-readable monitor name, e.g. 'ADEPT-12345', 'PR #42'"),
    sourceType: tool.schema.enum(["jira", "github"]).describe("What to watch"),
    issueKey: tool.schema.string().describe("Jira issue key, e.g. ADEPT-12345 (required if sourceType=jira)").optional(),
    repo: tool.schema.string().describe("GitHub owner/name, e.g. AdeptMind/hpdp-overlay (required if sourceType=github)").optional(),
    prNumber: tool.schema.number().describe("GitHub PR number (required if sourceType=github)").optional(),
    delivery: tool.schema.enum(["poll", "webhook"]).describe("How events arrive: 'poll' (periodic check, default) or 'webhook' (live push)").default("poll"),
    pollIntervalSec: tool.schema.number().describe("Poll interval in seconds (poll delivery only; min 15, default 60)").optional(),
  },
  async execute(args, context) {
    if (args.sourceType === "jira" && !args.issueKey) return JSON.stringify({ error: "issueKey is required for a jira monitor" })
    if (args.sourceType === "github" && (!args.repo || !args.prNumber)) return JSON.stringify({ error: "repo and prNumber are required for a github monitor" })

    const source: MonitorSource =
      args.sourceType === "jira"
        ? { type: "jira", issueKey: args.issueKey! }
        : { type: "github", repo: args.repo!, prNumber: args.prNumber! }

    const m = await createMonitor({
      name: args.name,
      source,
      delivery: args.delivery as Delivery,
      sessionID: context.sessionID,
      pollIntervalSec: args.pollIntervalSec ?? 60,
    })

    ensurePollLoop(getClient())
    ensureWebhookServer(getClient())

    return JSON.stringify({
      ok: true,
      monitor: {
        id: m.id,
        name: m.name,
        source: m.source,
        delivery: m.delivery,
        pollIntervalSec: m.pollIntervalSec,
        sessionID: m.sessionID,
      },
      hint: `Monitor ${m.id} created. New ${m.source.type === "jira" ? "Jira" : "GitHub"} events will be routed into this session as they happen. Stop it with the monitor_stop tool.`,
    })
  },
})
