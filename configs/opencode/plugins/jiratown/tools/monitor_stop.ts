import { tool } from "@opencode-ai/plugin"
import { stopMonitor } from "../src/monitors.ts"

export default tool({
  description: "Stop a jiratown monitor by id. Its events stop being routed into the session.",
  args: {
    id: tool.schema.string().describe("Monitor id (from monitor_list or monitor_create)"),
  },
  async execute(args) {
    const m = await stopMonitor(args.id)
    if ("error" in m) return JSON.stringify({ error: m.error })
    return JSON.stringify({ ok: true, monitorId: m.id, stopped: !m.enabled })
  },
})
