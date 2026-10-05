// Push opencode notifications to ntfy (https://ntfy.stjhn.xyz/opencode).
//
// Runs in the opencode server process (the launchd background service and any
// --standalone client). Subscribes to the server event stream and publishes:
//   - session.idle      -> "completed" when a top-level session finishes a turn
//   - form.created      -> "needs an answer" for current V2 questions/forms
//   - permission.asked  -> "needs approval" when the agent is blocked on you
//
// Token (write-only to the `opencode` topic) is read from OPENCODE_NTFY_TOKEN,
// else ~/.local/share/opencode/ntfy-token (chmod 600, outside the dotfiles
// deploy target so `just update -r opencode` cannot wipe it). No token -> no-op.
import { Plugin } from "@opencode/plugin"
import type { OpenCodeEvent } from "@opencode/client"
import { createHash } from "node:crypto"
import { closeSync, mkdirSync, openSync, readFileSync, readdirSync, rmSync } from "node:fs"
import { homedir } from "node:os"
import { join } from "node:path"

const NTFY_URL = (process.env.OPENCODE_NTFY_URL ?? "https://ntfy.stjhn.xyz/opencode").replace(/\/+$/, "")
const CLAIM_ROOT = join(process.env.XDG_CACHE_HOME || join(homedir(), ".cache"), "opencode", "ntfy-notify-event-claims")
const DAY_MS = 24 * 60 * 60 * 1_000
const CLAIM_RETENTION_MS = 3 * DAY_MS
const PERMISSION_SETTLE_MS = 300
let lastClaimPruneAt = 0

function loadToken(): string | undefined {
  const fromEnv = process.env.OPENCODE_NTFY_TOKEN?.trim()
  if (fromEnv) return fromEnv
  try {
    return readFileSync(join(homedir(), ".local/share/opencode/ntfy-token"), "utf8").trim() || undefined
  } catch {
    return undefined
  }
}

// ntfy header values must be single-line ASCII; keep any unicode in the body.
function headerSafe(text: string, max = 100): string {
  return text.replace(/[\r\n]+/g, " ").replace(/[^\x20-\x7E]/g, "").trim().slice(0, max) || "OpenCode"
}

type PermissionAskedEvent = Extract<OpenCodeEvent, { type: "permission.asked" }>
type SessionIdleEvent = Extract<OpenCodeEvent, { type: "session.idle" }>
type SessionSummary = {
  title?: string
  parentID?: string
  outcome?: "succeeded" | "failed" | "interrupted"
}
type GetSession = (sessionID?: string) => Promise<SessionSummary | undefined>
type GetPendingPermissions = (sessionID: string) => Promise<ReadonlyArray<{ id: string }>>
type Publish = (headers: Record<string, string>, body: string) => Promise<void>

function pruneClaimDays(now: number): void {
  if (now - lastClaimPruneAt < DAY_MS) return

  let days: string[]

  try {
    days = readdirSync(CLAIM_ROOT)
  } catch {
    return
  }

  lastClaimPruneAt = now

  for (const day of days) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(day)) continue

    const dayStart = Date.parse(`${day}T00:00:00.000Z`)
    if (!Number.isFinite(dayStart) || now - dayStart <= CLAIM_RETENTION_MS) continue

    try {
      rmSync(join(CLAIM_ROOT, day), { recursive: true, force: true })
    } catch {
      continue
    }
  }
}

function isAlreadyClaimed(error: unknown): boolean {
  return error instanceof Error && "code" in error && error.code === "EEXIST"
}

function claimEvent(event: OpenCodeEvent): boolean {
  const day = new Date().toISOString().slice(0, 10)
  const directory = join(CLAIM_ROOT, day)
  const eventHash = createHash("sha256").update(event.id).digest("hex")

  try {
    mkdirSync(directory, { recursive: true, mode: 0o700 })
    pruneClaimDays(Date.now())

    const descriptor = openSync(join(directory, eventHash), "wx", 0o600)
    closeSync(descriptor)

    return true
  } catch (error) {
    if (isAlreadyClaimed(error)) return false

    console.log(`[ntfy-notify] event dedupe failed: ${error}`)
    return false
  }
}

function formatForm(form: {
  title: string
  fields: ReadonlyArray<{
    key: string
    title?: string
    description?: string
    hidden?: boolean
    options?: ReadonlyArray<{ label: string }>
  }>
}): string {
  const fields = form.fields
    .filter((field) => !field.hidden)
    .map((field) => {
      const prompt = `${field.title || field.key}: ${field.description || "Please provide a value."}`
      const options = field.options?.map(({ label }) => label).join(", ")

      return options ? `${prompt}\nOptions: ${options}` : prompt
    })
    .join("\n\n")
  const body = fields ? `${form.title}\n\n${fields}` : form.title

  return body.slice(0, 500) || "OpenCode is waiting for your answer."
}

async function notifyCompletion(event: SessionIdleEvent, getSession: GetSession, publish: Publish) {
  const session = await getSession(event.data.sessionID)

  if (!session || session.parentID) return

  const title = session.title || "OpenCode"
  const outcome = session.outcome === "failed" ? "rotating_light" : session.outcome === "interrupted" ? "warning" : "white_check_mark"

  await publish(
    { Title: headerSafe(`OpenCode: ${title}`), Tags: outcome, Priority: "default" },
    `${title}\nSession complete — your turn.`,
  )
}

async function notifyPermission(
  event: PermissionAskedEvent,
  getPendingPermissions: GetPendingPermissions,
  getSession: GetSession,
  publish: Publish,
) {
  if (!claimEvent(event)) return

  await new Promise<void>((resolve) => setTimeout(resolve, PERMISSION_SETTLE_MS))

  let pendingPermissions: ReadonlyArray<{ id: string }>

  try {
    pendingPermissions = await getPendingPermissions(event.data.sessionID)
  } catch (error) {
    console.log(`[ntfy-notify] pending permission check failed: ${error}`)
    return
  }

  if (!pendingPermissions.some(({ id }) => id === event.data.id)) {
    return
  }

  console.log(`[ntfy-notify] event ${event.type}`)

  const session = await getSession(event.data.sessionID)
  const title = session?.title || "OpenCode"
  const detail = event.data.message || `${event.data.action} ${event.data.resources.join(", ")}`.trim()

  await publish(
    { Title: headerSafe(`OpenCode needs approval: ${title}`), Tags: "warning", Priority: "high" },
    detail.slice(0, 300),
  )
}

async function notifyQuestion(sessionID: string, body: string, getSession: GetSession, publish: Publish) {
  const session = await getSession(sessionID)

  if (session?.parentID) return

  const title = session?.title || "OpenCode"

  await publish(
    { Title: headerSafe(`OpenCode has a question: ${title}`), Tags: "question", Priority: "high" },
    body,
  )
}

async function handleEvent(
  event: OpenCodeEvent,
  getPendingPermissions: GetPendingPermissions,
  getSession: GetSession,
  publish: Publish,
) {
  if (event.type !== "session.idle" && event.type !== "permission.asked" && event.type !== "form.created") return

  if (event.type === "permission.asked") {
    return notifyPermission(event, getPendingPermissions, getSession, publish)
  }

  if (!claimEvent(event)) return

  if (
    event.type === "session.idle" ||
    event.type === "form.created"
  ) {
    console.log(`[ntfy-notify] event ${event.type}`)
  }

  if (event.type === "session.idle") return notifyCompletion(event, getSession, publish)
  if (event.type === "form.created") {
    return notifyQuestion(event.data.form.sessionID, formatForm(event.data.form), getSession, publish)
  }
}

export default Plugin.define({
  id: "ntfy-notify",
  setup(ctx) {
    const token = loadToken()
    console.log(`[ntfy-notify] setup: token ${token ? "present" : "MISSING"}, url ${NTFY_URL}`)
    if (!token) return // not configured -> silent no-op

    async function publish(headers: Record<string, string>, body: string): Promise<void> {
      try {
        const r = await fetch(NTFY_URL, {
          method: "POST",
          headers: { Authorization: `Bearer ${token}`, ...headers },
          body,
          signal: AbortSignal.timeout(5_000),
        })
        console.log(`[ntfy-notify] publish -> ${r.status}`)
      } catch (e) {
        console.log(`[ntfy-notify] publish error: ${e}`)
      }
    }

    async function getSession(sessionID?: string): Promise<SessionSummary | undefined> {
      if (!sessionID) return undefined
      try {
        return await ctx.session.get({ sessionID })
      } catch {
        return undefined
      }
    }

    async function getPendingPermissions(sessionID: string): Promise<ReadonlyArray<{ id: string }>> {
      return ctx.permission.list({ sessionID })
    }

    const controller = new AbortController()

    void (async () => {
      try {
        console.log(`[ntfy-notify] subscribed to event stream`)
        for await (const rawEvent of ctx.event.subscribe({ signal: controller.signal })) {
          await handleEvent(rawEvent, getPendingPermissions, getSession, publish)
        }
      } catch (e) {
        console.log(`[ntfy-notify] loop ended: ${e}`)
      }
    })()

    return () => controller.abort()
  },
})
