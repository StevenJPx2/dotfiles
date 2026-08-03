import type { Monitor } from "./monitors.ts"
import { getMonitor, listMonitors, updateCursor } from "./monitors.ts"
import { pollJira } from "./jira.ts"
import { pollGithub } from "./github.ts"
import { routeToSession, toMonitorEvent, toMonitorEventGithub, type MonitorEvent } from "./route.ts"

const LOOP_SEC = 5
const timers = new Map<string, ReturnType<typeof setInterval>>()

/** One pass over an enabled poll monitor: fetch new events from its source and route them. */
export async function pollOnce(
  client: ReturnType<typeof import("@opencode-ai/sdk").createOpencodeClient>,
  monitor: Monitor,
): Promise<number> {
  let events: MonitorEvent[] = []
  let cursorKey: string

  if (monitor.source.type === "jira") {
    cursorKey = `jira:${monitor.source.issueKey}`
    try {
      const r = await pollJira(monitor.source.issueKey, monitor.cursors[cursorKey])
      events = r.events.map((e) => toMonitorEvent(e, monitor.source))
      await updateCursor(monitor, cursorKey, r.cursor)
    } catch (err) {
      console.error(`[jiratown] jira poll failed for ${monitor.id}: ${err instanceof Error ? err.message : err}`)
      return 0
    }
  } else {
    cursorKey = `github:${monitor.source.repo}#${monitor.source.prNumber}`
    try {
      const r = pollGithub(monitor.source.repo, monitor.source.prNumber, monitor.cursors[cursorKey])
      events = r.events.map((e) => toMonitorEventGithub(e, monitor.source))
      await updateCursor(monitor, cursorKey, r.cursor)
    } catch (err) {
      console.error(`[jiratown] github poll failed for ${monitor.id}: ${err instanceof Error ? err.message : err}`)
      return 0
    }
  }

  for (const e of events) {
    const res = await routeToSession(client, monitor, e)
    if (!res.ok) console.error(`[jiratown] route failed for ${monitor.id}: ${res.error}`)
  }
  return events.length
}

async function tick(
  client: ReturnType<typeof import("@opencode-ai/sdk").createOpencodeClient>,
): Promise<void> {
  const monitors = await listMonitors()
  for (const m of monitors) {
    if (!m.enabled || m.delivery !== "poll") continue
    const fresh = await getMonitor(m.id) // re-read in case it was stopped mid-tick
    if (!fresh || !fresh.enabled) continue
    const lastPolledAt = Number(fresh.cursors.__lastPolledAt ?? 0)
    if (lastPolledAt && Date.now() - lastPolledAt < fresh.pollIntervalSec * 1000) continue
    await pollOnce(client, fresh)
    await updateCursor(fresh, "__lastPolledAt", Date.now())
  }
}

/** Start the shared poll loop (singleton — safe to call from multiple tool invocations). */
export function ensurePollLoop(client: ReturnType<typeof import("@opencode-ai/sdk").createOpencodeClient>): void {
  if (timers.has("loop")) return
  const t = setInterval(() => {
    tick(client).catch((err) => console.error("[jiratown] poll tick error:", err))
  }, LOOP_SEC * 1000)
  timers.set("loop", t)
  // First tick immediately so a monitor starts paying attention without waiting LOOP_SEC.
  tick(client).catch(() => {})
}

/** Stop the poll loop (on plugin dispose). */
export function stopPollLoop(): void {
  for (const t of timers.values()) clearInterval(t)
  timers.clear()
}
