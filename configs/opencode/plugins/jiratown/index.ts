import type { Plugin, Hooks } from "@opencode-ai/plugin"
import { setClient } from "./src/client.ts"
import { ensurePollLoop, stopPollLoop } from "./src/poll.ts"
import { ensureWebhookServer, stopWebhookServer } from "./src/webhook.ts"
import monitorCreate from "./tools/monitor_create.ts"
import monitorList from "./tools/monitor_list.ts"
import monitorStatus from "./tools/monitor_status.ts"
import monitorStop from "./tools/monitor_stop.ts"

export const Jiratown: Plugin = async (input) => {
  setClient(input.client)

  // Start the poll loop so poll-delivery monitors run as soon as the plugin is loaded.
  ensurePollLoop(input.client)
  ensureWebhookServer(input.client)

  const hooks: Hooks = {
    dispose: () => {
      stopPollLoop()
      stopWebhookServer()
      return Promise.resolve()
    },
    tool: {
      monitor_create: monitorCreate,
      monitor_list: monitorList,
      monitor_status: monitorStatus,
      monitor_stop: monitorStop,
    },
  }
  return hooks
}

export default Jiratown
