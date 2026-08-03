import { createHmac, timingSafeEqual } from "node:crypto"
import { listMonitors, updateCursor, type Monitor } from "./monitors.ts"
import { routeToSession, type MonitorEvent } from "./route.ts"

type Client = ReturnType<typeof import("@opencode-ai/sdk").createOpencodeClient>

let server: ReturnType<typeof Bun.serve> | undefined

function secretFor(source: "github" | "jira"): string | undefined {
  return source === "github" ? process.env.JIRATOWN_GITHUB_WEBHOOK_SECRET : process.env.JIRATOWN_JIRA_WEBHOOK_SECRET
}

function validSignature(body: string, signature: string | null, secret: string | undefined): boolean {
  if (!secret || !signature) return false
  const expected = `sha256=${createHmac("sha256", secret).update(body).digest("hex")}`
  const actual = Buffer.from(signature)
  const wanted = Buffer.from(expected)
  return actual.length === wanted.length && timingSafeEqual(actual, wanted)
}

function githubEvent(payload: any, eventName: string, deliveryId: string): MonitorEvent | undefined {
  const repo = payload.repository?.full_name
  const prNumber = Number(payload.pull_request?.number ?? payload.issue?.number)
  if (!repo || !Number.isInteger(prNumber)) return undefined

  const actor = payload.sender?.login ?? payload.review?.user?.login ?? "someone"
  const reviewBody = payload.review?.body
  const commentBody = payload.comment?.body
  const check = payload.check_run ?? payload.check_suite
  const action = payload.action ?? "changed"
  let summary = `GitHub ${eventName} ${action} by ${actor} on ${repo}#${prNumber}`
  let body: string | undefined
  let kind = eventName

  if (eventName === "pull_request_review") {
    summary = `GitHub review ${action} by ${actor} on ${repo}#${prNumber}`
    body = reviewBody
    kind = "review"
  } else if (eventName === "pull_request_review_comment" || eventName === "issue_comment") {
    summary = `GitHub comment by ${actor} on ${repo}#${prNumber}`
    body = commentBody
    kind = "comment"
  } else if (eventName === "check_run" || eventName === "check_suite") {
    const conclusion = check?.conclusion ?? check?.status ?? "changed"
    summary = `GitHub CI ${conclusion} on ${repo}#${prNumber}`
    body = check?.output?.text ?? check?.latest_check_runs?.map((x: any) => x.name).join(", ")
    kind = "ci"
  } else if (eventName === "pull_request") {
    kind = action === "closed" && payload.pull_request?.merged ? "merged" : action === "synchronize" ? "commit" : action
    summary = `GitHub PR ${action}${payload.pull_request?.merged ? " and merged" : ""} on ${repo}#${prNumber}`
    body = payload.pull_request?.body
  }

  return {
    source: { type: "github", repo, prNumber },
    kind,
    at: payload.repository?.updated_at ?? new Date().toISOString(),
    summary,
    body: body ? `${body}\n\nWebhook delivery: ${deliveryId}` : `Webhook delivery: ${deliveryId}`,
    actionable: eventName !== "check_run" || /FAIL|ERROR|CANCEL|COMPLETED/i.test(String(check?.conclusion ?? check?.status ?? "")),
  }
}

function jiraEvent(payload: any, deliveryId: string): MonitorEvent | undefined {
  const issueKey = payload.issue?.key
  if (!issueKey) return undefined
  const eventName = payload.webhookEvent ?? payload.eventType ?? "issue changed"
  const items = payload.changelog?.items ?? []
  const changes = items.map((x: any) => `${x.field}: ${x.fromString ?? "none"} → ${x.toString ?? "none"}`).join("; ")
  const body = payload.comment?.body
    ? typeof payload.comment.body === "string"
      ? payload.comment.body
      : JSON.stringify(payload.comment.body)
    : changes || undefined
  return {
    source: { type: "jira", issueKey },
    kind: payload.comment ? "comment" : payload.changelog ? "changelog" : "description",
    at: payload.timestamp ? new Date(payload.timestamp).toISOString() : new Date().toISOString(),
    summary: `Jira ${issueKey} ${eventName}${changes ? ` (${changes})` : ""}`,
    body: body ? `${body}\n\nWebhook delivery: ${deliveryId}` : `Webhook delivery: ${deliveryId}`,
    actionable: true,
  }
}

function sameSource(monitor: Monitor, event: MonitorEvent): boolean {
  if (monitor.source.type !== event.source.type) return false
  if (monitor.source.type === "jira" && event.source.type === "jira") return monitor.source.issueKey === event.source.issueKey
  if (monitor.source.type === "github" && event.source.type === "github") {
    return monitor.source.repo === event.source.repo && monitor.source.prNumber === event.source.prNumber
  }
  return false
}

async function deliver(client: Client, event: MonitorEvent, deliveryId: string): Promise<number> {
  let delivered = 0
  for (const monitor of await listMonitors()) {
    if (!monitor.enabled || monitor.delivery !== "webhook" || !sameSource(monitor, event)) continue
    const cursorKey = `webhook:${deliveryId}`
    if (monitor.cursors[cursorKey]) continue
    const result = await routeToSession(client, monitor, event)
    if (!result.ok) console.error(`[jiratown] webhook route failed for ${monitor.id}: ${result.error}`)
    await updateCursor(monitor, cursorKey, true)
    if (result.ok) delivered++
  }
  return delivered
}

async function handle(request: Request, client: Client): Promise<Response> {
  const url = new URL(request.url)
  if (request.method === "GET" && url.pathname === "/health") return Response.json({ ok: true, plugin: "jiratown" })
  if (request.method !== "POST") return new Response("method not allowed", { status: 405 })

  const source = url.pathname === "/webhooks/github" ? "github" : url.pathname === "/webhooks/jira" ? "jira" : undefined
  if (!source) return new Response("not found", { status: 404 })

  const body = await request.text()
  const signature = source === "github" ? request.headers.get("x-hub-signature-256") : request.headers.get("x-jiratown-signature")
  if (!validSignature(body, signature, secretFor(source))) return new Response("invalid signature", { status: 401 })

  let payload: any
  try {
    payload = JSON.parse(body)
  } catch {
    return new Response("invalid json", { status: 400 })
  }

  const deliveryId = request.headers.get("x-github-delivery") ?? request.headers.get("x-jiratown-delivery") ?? crypto.randomUUID()
  const event = source === "github" ? githubEvent(payload, request.headers.get("x-github-event") ?? "github", deliveryId) : jiraEvent(payload, deliveryId)
  if (!event) return Response.json({ ok: true, delivered: 0 })

  const delivered = await deliver(client, event, deliveryId)
  return Response.json({ ok: true, delivered })
}

/** Start the in-process webhook listener once. Existing webhook monitors are handled on reload. */
export function ensureWebhookServer(client: Client): void {
  if (server) return
  const port = Number(process.env.JIRATOWN_WEBHOOK_PORT ?? 8787)
  const hostname = process.env.JIRATOWN_WEBHOOK_HOST ?? "0.0.0.0"
  server = Bun.serve({
    port,
    hostname,
    fetch: (request) => handle(request, client),
  })
  console.log(`[jiratown] webhook listener on ${hostname}:${server.port}`)
}

export function stopWebhookServer(): void {
  server?.stop()
  server = undefined
}
