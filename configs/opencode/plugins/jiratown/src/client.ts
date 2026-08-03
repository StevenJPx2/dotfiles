import type { createOpencodeClient } from "@opencode-ai/sdk"

let client: ReturnType<typeof createOpencodeClient> | undefined

/** The plugin's authenticated SDK client, set at plugin load from PluginInput.client. */
export function setClient(c: ReturnType<typeof createOpencodeClient>): void {
  client = c
}

export function getClient(): ReturnType<typeof createOpencodeClient> {
  if (!client) throw new Error("jiratown client not initialized (plugin not loaded?)")
  return client
}
