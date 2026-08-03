import { mkdir, readFile, writeFile } from "node:fs/promises"
import path from "node:path"
import { fileURLToPath } from "node:url"

/** Root of the jiratown plugin (…/configs/opencode/plugins/jiratown). */
export const PLUGIN_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..")

const STATE_DIR = path.join(PLUGIN_ROOT, ".state")
const STATE_FILE = path.join(STATE_DIR, "monitors.json")

export type Delivery = "poll" | "webhook"

export interface JiraSource {
  type: "jira"
  issueKey: string
}

export interface GithubSource {
  type: "github"
  repo: string // owner/name
  prNumber: number
}

export type MonitorSource = JiraSource | GithubSource

export interface Monitor {
  id: string
  name: string
  source: MonitorSource
  delivery: Delivery
  /** The opencode session that created this monitor; events are routed into it. */
  sessionID: string
  /** Poll interval seconds (poll delivery only). */
  pollIntervalSec: number
  /** True while events should be routed. */
  enabled: boolean
  createdAt: string
  updatedAt: string
  /** Last polled cursors keyed by source, so the next poll only sees NEW events. */
  cursors: Record<string, unknown>
}

interface MonitorRegistry {
  monitors: Monitor[]
}

function emptyRegistry(): MonitorRegistry {
  return { monitors: [] }
}

export async function loadMonitors(): Promise<MonitorRegistry> {
  try {
    const raw = JSON.parse(await readFile(STATE_FILE, "utf8")) as MonitorRegistry
    return { monitors: raw.monitors ?? [] }
  } catch {
    return emptyRegistry()
  }
}

async function saveMonitors(reg: MonitorRegistry): Promise<void> {
  await mkdir(STATE_DIR, { recursive: true })
  await writeFile(STATE_FILE, JSON.stringify(reg, null, 2))
}

export async function createMonitor(
  input: Pick<Monitor, "name" | "source" | "delivery" | "sessionID" | "pollIntervalSec">,
): Promise<Monitor> {
  const reg = await loadMonitors()
  const now = new Date().toISOString()
  const monitor: Monitor = {
    id: `m-${Date.now().toString(36)}-${crypto.randomUUID().slice(0, 6)}`,
    name: input.name,
    source: input.source,
    delivery: input.delivery,
    sessionID: input.sessionID,
    pollIntervalSec: input.delivery === "webhook" ? 0 : Math.max(15, input.pollIntervalSec || 60),
    enabled: true,
    createdAt: now,
    updatedAt: now,
    cursors: {},
  }
  reg.monitors.push(monitor)
  await saveMonitors(reg)
  return monitor
}

export async function listMonitors(): Promise<Monitor[]> {
  const reg = await loadMonitors()
  return reg.monitors
}

export async function getMonitor(id: string): Promise<Monitor | undefined> {
  const reg = await loadMonitors()
  return reg.monitors.find((m) => m.id === id)
}

export async function stopMonitor(id: string): Promise<Monitor | { error: string }> {
  const reg = await loadMonitors()
  const m = reg.monitors.find((x) => x.id === id)
  if (!m) return { error: `no monitor ${id}` }
  m.enabled = false
  m.updatedAt = new Date().toISOString()
  await saveMonitors(reg)
  return m
}

export async function updateCursor(monitor: Monitor, key: string, cursor: unknown): Promise<void> {
  const reg = await loadMonitors()
  const m = reg.monitors.find((x) => x.id === monitor.id)
  if (!m) return
  m.cursors[key] = cursor
  m.updatedAt = new Date().toISOString()
  await saveMonitors(reg)
}
