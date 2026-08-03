import { tool } from "@opencode-ai/plugin"
import { listMonitors } from "../src/monitors.ts"

export default tool({
  description: "List all active jiratown monitors (id, name, source, delivery, enabled).",
  args: {},
  async execute() {
    const monitors = await listMonitors()
    return JSON.stringify({
      monitors: monitors.map((m) => ({
        id: m.id,
        name: m.name,
        source: m.source,
        delivery: m.delivery,
        enabled: m.enabled,
        pollIntervalSec: m.pollIntervalSec,
        createdAt: m.createdAt,
      })),
      hint: monitors.length === 0 ? "No monitors created yet. Use monitor_create to watch a Jira issue or GitHub PR." : undefined,
    })
  },
})
