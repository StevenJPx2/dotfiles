// Push opencode notifications to ntfy (https://ntfy.stjhn.xyz/opencode).
//
// Runs in the opencode server process (the launchd background service and any
// --standalone client). Subscribes to the server event stream and publishes:
//   - session.idle       -> "your turn" when a top-level session finishes a turn
//   - permission.asked   -> "needs approval" when the agent is blocked on you
//
// Token (write-only to the `opencode` topic) is read from OPENCODE_NTFY_TOKEN,
// else ~/.local/share/opencode/ntfy-token (chmod 600, outside the dotfiles
// deploy target so `just update -r opencode` cannot wipe it). No token -> no-op.
import { Plugin } from "@opencode/plugin"
import { readFileSync } from "node:fs"
import { homedir } from "node:os"
import { join } from "node:path"

const NTFY_URL = (process.env.OPENCODE_NTFY_URL ?? "https://ntfy.stjhn.xyz/opencode").replace(/\/+$/, "")

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

export default Plugin.define({
  id: "ntfy-notify",
  setup(ctx) {
    const token = loadToken()
    console.log(`[ntfy-notify] setup: token ${token ? "present" : "MISSING"}, url ${NTFY_URL}`)
    if (!token) return // not configured -> silent no-op

    async function publish(headers: Record<string, string>, body: string) {
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

    async function getSession(sessionID?: string) {
      if (!sessionID) return undefined
      try {
        return await ctx.session.get({ sessionID })
      } catch {
        return undefined
      }
    }

    const controller = new AbortController()

    void (async () => {
      try {
        console.log(`[ntfy-notify] subscribed to event stream`)
        for await (const event of ctx.event.subscribe({ signal: controller.signal })) {
          if (event.type === "session.idle" || event.type === "permission.asked") console.log(`[ntfy-notify] event ${event.type}`)
          if (event.type === "session.idle") {
            const s = await getSession((event as { data?: { sessionID?: string } }).data?.sessionID)
            if (!s || s.parentID) continue // skip subagent/child sessions
            const title = s.title || "OpenCode"
            const outcome = s.outcome === "failed" ? "rotating_light" : s.outcome === "interrupted" ? "warning" : "white_check_mark"
            await publish(
              { Title: headerSafe(`OpenCode: ${title}`), Tags: outcome, Priority: "default" },
              `${title}\nSession idle — your turn.`,
            )
          } else if (event.type === "permission.asked") {
            const d = (event as { data?: { sessionID?: string; action?: string; resources?: string[]; message?: string } }).data ?? {}
            const s = await getSession(d.sessionID)
            const title = s?.title || "OpenCode"
            const detail = d.message || `${d.action ?? "permission"} ${(d.resources ?? []).join(", ")}`.trim()
            await publish(
              { Title: headerSafe(`OpenCode needs approval: ${title}`), Tags: "warning", Priority: "high" },
              detail.slice(0, 300),
            )
          }
        }
      } catch (e) {
        console.log(`[ntfy-notify] loop ended: ${e}`)
      }
    })()

    return () => controller.abort()
  },
})
