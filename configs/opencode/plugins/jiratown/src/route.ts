import type { Monitor, MonitorSource } from "./monitors.ts"
import type { JiraEvent } from "./jira.ts"
import type { GithubEvent } from "./github.ts"

export type MonitorEvent = {
  source: MonitorSource
  kind: string
  at: string
  summary: string
  body?: string
  actionable: boolean
}

function eventToText(e: MonitorEvent): string {
  const lines = [
    `[jiratown monitor] ${e.summary}`,
    e.body ? `\n${e.body}` : "",
  ]
  return lines.filter(Boolean).join("\n")
}

/**
 * Route a monitor event into the session that created the monitor. Uses the SDK client's
 * `session.prompt` with `noReply: true` so the event is fed to the running agent without
 * blocking; the agent sees it and decides what to do.
 */
export async function routeToSession(
  client: ReturnType<typeof import("@opencode-ai/sdk").createOpencodeClient>,
  monitor: Monitor,
  event: MonitorEvent,
): Promise<{ ok: boolean; error?: string }> {
  const text = eventToText(event)
  try {
    await client.session.prompt({
      path: { id: monitor.sessionID },
      body: {
        parts: [{ type: "text", text }],
        noReply: true,
      },
    })
    return { ok: true }
  } catch (err) {
    return { ok: false, error: err instanceof Error ? err.message : String(err) }
  }
}

export function toMonitorEvent(e: JiraEvent, source: MonitorSource): MonitorEvent {
  return { source, kind: e.kind, at: e.at, summary: e.summary, body: e.body, actionable: e.actionable }
}

export function toMonitorEventGithub(e: GithubEvent, source: MonitorSource): MonitorEvent {
  return { source, kind: e.kind, at: e.at, summary: e.summary, body: e.body, actionable: e.actionable }
}
