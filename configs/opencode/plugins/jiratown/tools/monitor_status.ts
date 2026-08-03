import { tool } from "@opencode-ai/plugin"
import { getMonitor } from "../src/monitors.ts"

export default tool({
  description: "Get the status of a single jiratown monitor by id (enabled state, source, delivery, cursors).",
  args: {
    id: tool.schema.string().describe("Monitor id (from monitor_list or monitor_create)"),
  },
  async execute(args) {
    const m = await getMonitor(args.id)
    if (!m) return JSON.stringify({ error: `no monitor ${args.id}` })
    return JSON.stringify({
      id: m.id,
      name: m.name,
      source: m.source,
      delivery: m.delivery,
      enabled: m.enabled,
      sessionID: m.sessionID,
      pollIntervalSec: m.pollIntervalSec,
      cursors: m.cursors,
      createdAt: m.createdAt,
      updatedAt: m.updatedAt,
    })
  },
})
