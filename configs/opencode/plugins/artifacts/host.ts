import { randomBytes } from "node:crypto"
import {
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  renameSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs"
import { homedir } from "node:os"
import { join } from "node:path"
import { spawn, type ChildProcess } from "node:child_process"

export const DEFAULT_PORT = 41783
export const DEFAULT_TTL_MINUTES = 240
export const MIN_TTL_MINUTES = 1
export const MAX_TITLE_CHARS = 200
export const MAX_HTML_BYTES = 500_000
export const ARTIFACT_HOST = "at.stjhn.xyz"
export const ID_LENGTH = 6
const ID_HEX = `[0-9a-f]{${ID_LENGTH}}`
export const ID_PATTERN = new RegExp(`^${ID_HEX}$`)
export const HEALTH_SERVICE = "opencode-artifacts"
export const LOCAL_ARTIFACT_PATH = "/__artifact"

// WebTUI gruvbox-dark palette: https://github.com/webtui/webtui
const GRUVBOX = {
  bg0: "#282828",
  bg1: "#3c3836",
  bg2: "#504945",
  bg3: "#665c54",
  fg0: "#fbf1c7",
  fg1: "#ebdbb2",
  fg3: "#bdae93",
  fg4: "#a89984",
  gray: "#928374",
  red: "#fb4934",
  green: "#b8bb26",
  yellow: "#fabd2f",
  blue: "#83a598",
  purple: "#d3869b",
  aqua: "#8ec07c",
  orange: "#fe8019",
}

// Body-only artifacts get a small readable baseline; callers can override it with CSS.
export const DEFAULT_STYLES = `
:root {
  color-scheme: dark;
  background: ${GRUVBOX.bg0};
  color: ${GRUVBOX.fg1};
  font-family: 'JetBrains Mono', Menlo, Monaco, monospace;
  font-size: 16px;
  line-height: 1.5;
}
* { box-sizing: border-box; }
body { max-width: 48rem; margin: 0 auto; padding: 2rem 1.25rem; }
h1, h2, h3, h4, h5, h6 { color: ${GRUVBOX.green}; }
a { color: ${GRUVBOX.blue}; text-decoration: underline; }
a:hover { color: ${GRUVBOX.aqua}; }
code { color: ${GRUVBOX.orange}; background: ${GRUVBOX.bg1}; padding: 0.1em 0.35em; border-radius: 3px; }
pre { background: ${GRUVBOX.bg1}; border: 1px solid ${GRUVBOX.bg2}; padding: 1rem; overflow-x: auto; }
pre code { background: none; padding: 0; }
blockquote { border-left: 3px solid ${GRUVBOX.bg3}; margin-left: 0; padding-left: 1rem; color: ${GRUVBOX.fg4}; }
hr { border: none; border-top: 1px solid ${GRUVBOX.bg2}; }
table { border-collapse: collapse; width: 100%; }
th, td { border: 1px solid ${GRUVBOX.bg2}; padding: 0.4rem 0.6rem; text-align: left; }
th { background: ${GRUVBOX.bg1}; color: ${GRUVBOX.fg0}; }
img, svg, video { max-width: 100%; height: auto; }
button, input, select, textarea { font: inherit; color: inherit; }
::selection { background: ${GRUVBOX.bg2}; }
`

export type ArtifactRecord = {
  title: string
  html: string
  expiresAt: number
  markdown?: string
  body?: string
  styles?: string
}

export type ArtifactContent = {
  file?: string
  markdown?: string
  body?: string
  styles?: string
}

export type Route =
  | { kind: "health" }
  | { kind: "artifact"; id: string }
  | { kind: "not-found" }

export function createId(): string {
  return randomBytes(3).toString("hex")
}

export function isValidId(value: unknown): value is string {
  return typeof value === "string" && ID_PATTERN.test(value)
}

export function isValidRecord(value: unknown): value is ArtifactRecord {
  if (typeof value !== "object" || value === null) return false

  const record = value as Partial<ArtifactRecord>
  const htmlBytes = typeof record.html === "string" ? Buffer.byteLength(record.html, "utf8") : -1

  return (
    typeof record.title === "string" &&
    record.title.length >= 1 &&
    record.title.length <= MAX_TITLE_CHARS &&
    typeof record.html === "string" &&
    htmlBytes >= 1 &&
    htmlBytes <= MAX_HTML_BYTES &&
    typeof record.expiresAt === "number" &&
    Number.isFinite(record.expiresAt) &&
    (record.markdown === undefined || typeof record.markdown === "string") &&
    (record.body === undefined || typeof record.body === "string") &&
    (record.styles === undefined || typeof record.styles === "string")
  )
}

export function validateInput(title: string, html: string, ttlMinutes = DEFAULT_TTL_MINUTES): void {
  if (title.length < 1 || title.length > MAX_TITLE_CHARS) {
    throw new Error(`title must be 1..${MAX_TITLE_CHARS} characters`)
  }

  const htmlBytes = Buffer.byteLength(html, "utf8")
  if (htmlBytes < 1 || htmlBytes > MAX_HTML_BYTES) {
    throw new Error(`html must be 1..${MAX_HTML_BYTES} bytes`)
  }

  if (!Number.isInteger(ttlMinutes) || ttlMinutes < MIN_TTL_MINUTES) {
    throw new Error(`ttlMinutes must be an integer of at least ${MIN_TTL_MINUTES}`)
  }
}

export function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, (ch) =>
    ({
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#39;",
    })[ch] ?? ch,
  )
}

export function renderBody(body: string, styles = DEFAULT_STYLES, title?: string): string {
  const titleTag = title ? `<title>${escapeHtml(title)}</title>\n` : ""

  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
${titleTag}<style>${styles}</style>
</head>
<body>${body}</body>
</html>`
}

export function renderMarkdown(markdown: string, styles = DEFAULT_STYLES, title?: string): string {
  return renderBody(Bun.markdown.html(markdown), styles, title)
}

export function replaceFirst(value: string, search: string, replacement: string): string {
  const index = value.indexOf(search)
  if (index === -1) throw new Error("patch search text not found")

  return `${value.slice(0, index)}${replacement}${value.slice(index + search.length)}`
}

export type ComposedContent = {
  html: string
  markdown?: string
  body?: string
  styles?: string
}

export function composeContent(
  content: ArtifactContent,
  prior: Pick<ArtifactRecord, "body" | "markdown" | "styles"> = {},
  title?: string,
): ComposedContent {
  if (content.file !== undefined && (content.markdown !== undefined || content.body !== undefined)) {
    throw new Error("provide either file or markdown/body, not both")
  }

  if (content.file !== undefined) {
    const source = readFileSync(content.file, "utf8")
    if (/\.(md|markdown)$/i.test(content.file)) {
      return { html: renderMarkdown(source, content.styles, title), markdown: source, styles: content.styles }
    }
    return { html: renderBody(source, content.styles, title), body: source, styles: content.styles }
  }

  if (content.markdown !== undefined && content.body !== undefined) {
    throw new Error("provide either markdown or body, not both")
  }

  if (content.markdown !== undefined) {
    return { html: renderMarkdown(content.markdown, content.styles, title), markdown: content.markdown, styles: content.styles }
  }

  const body = content.body ?? prior.body
  const styles = content.styles ?? prior.styles
  if (body === undefined && prior.markdown !== undefined) {
    return { html: renderMarkdown(prior.markdown, styles, title), markdown: prior.markdown, styles }
  }
  if (body === undefined) throw new Error("provide markdown or body")

  return { html: renderBody(body, styles, title), body, styles }
}

export function isExpired(record: Pick<ArtifactRecord, "expiresAt">, now = Date.now()): boolean {
  return record.expiresAt <= now
}

export function artifactDirectory(): string {
  return join(
    process.env.XDG_CACHE_HOME ?? join(homedir(), ".cache"),
    "opencode-artifacts",
  )
}

export function artifactPath(id: string): string {
  return join(artifactDirectory(), `${id}.json`)
}

export function writeRecord(id: string, record: ArtifactRecord): void {
  if (!isValidId(id)) throw new Error("invalid artifact id")

  const directory = artifactDirectory()
  mkdirSync(directory, { recursive: true })

  const temporaryPath = join(directory, `.${id}.${process.pid}.${Date.now()}.tmp`)
  writeFileSync(temporaryPath, JSON.stringify(record), "utf8")
  renameSync(temporaryPath, artifactPath(id))
}

export function readRecord(id: string, now = Date.now()): ArtifactRecord | null {
  if (!isValidId(id)) return null

  const path = artifactPath(id)
  if (!existsSync(path)) return null

  try {
    const parsed = JSON.parse(readFileSync(path, "utf8")) as unknown
    if (!isValidRecord(parsed) || isExpired(parsed, now)) {
      rmSync(path, { force: true })
      return null
    }
    return parsed
  } catch {
    rmSync(path, { force: true })
    return null
  }
}

export function deleteRecord(id: string): boolean {
  if (!isValidId(id)) return false

  const path = artifactPath(id)
  if (!existsSync(path)) return false
  rmSync(path, { force: true })
  return true
}

export function sweepRecords(now = Date.now()): number {
  const directory = artifactDirectory()
  if (!existsSync(directory)) return 0

  let removed = 0
  for (const entry of readdirSync(directory)) {
    if (!entry.endsWith(".json")) continue

    const path = join(directory, entry)
    try {
      const parsed = JSON.parse(readFileSync(path, "utf8")) as unknown
      if (!isValidRecord(parsed) || isExpired(parsed, now)) {
        rmSync(path, { force: true })
        removed++
      }
    } catch {
      rmSync(path, { force: true })
      removed++
    }
  }
  return removed
}

export function routeRequest(host: string, pathname: string): Route {
  const hostname = host.toLowerCase().replace(/:\d+$/, "")
  const isLocalhost = hostname === "localhost" || hostname === "127.0.0.1"

  if (isLocalhost && pathname === "/health") return { kind: "health" }

  const localMatch = isLocalhost ? pathname.match(new RegExp(`^/__artifact/(${ID_HEX})$`)) : null
  if (localMatch) return { kind: "artifact", id: localMatch[1] }

  if (hostname === ARTIFACT_HOST) {
    const publicMatch = pathname.match(new RegExp(`^/(${ID_HEX})$`))
    if (publicMatch) return { kind: "artifact", id: publicMatch[1] }
  }

  return { kind: "not-found" }
}

export function localArtifactUrl(id: string, port = DEFAULT_PORT): string {
  return `http://127.0.0.1:${port}${LOCAL_ARTIFACT_PATH}/${id}`
}

export function publicArtifactUrl(id: string): string {
  return `https://${ARTIFACT_HOST}/${id}`
}

export function securityHeaders(allowScripts = false): Headers {
  return new Headers({
    "Content-Type": "text/html; charset=utf-8",
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
    "Content-Security-Policy": `default-src 'none'; style-src 'unsafe-inline'; img-src data:; font-src data:; script-src ${allowScripts ? "'unsafe-inline' https:" : "'none'"}; connect-src ${allowScripts ? "https:" : "'none'"}; frame-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'`,
  })
}

export function handleRequest(request: Request): Response {
  const url = new URL(request.url)
  const route = routeRequest(request.headers.get("host") ?? url.hostname, url.pathname)

  if (route.kind === "health") {
    return new Response(JSON.stringify({ service: HEALTH_SERVICE }), {
      headers: { "Content-Type": "application/json" },
    })
  }

  if (route.kind !== "artifact") return new Response("Not found", { status: 404 })

  if (request.method !== "GET" && request.method !== "HEAD") {
    return new Response("Method not allowed", { status: 405, headers: { Allow: "GET, HEAD" } })
  }

  const record = readRecord(route.id)
  if (!record) return new Response("Not found", { status: 404 })

  const headers = securityHeaders(record.body !== undefined)
  if (request.method === "HEAD") return new Response(null, { headers })
  return new Response(record.html, { headers })
}

export function startServer(port = Number(process.env.OPENCODE_ARTIFACT_PORT ?? DEFAULT_PORT)) {
  return Bun.serve({ hostname: "127.0.0.1", port, fetch: handleRequest })
}

let tunnelProcess: ChildProcess | undefined
let tunnelRestartTimer: ReturnType<typeof setTimeout> | undefined
let tunnelRestartDelay = 1_000

export function tunnelTokenFile(): string | undefined {
  const configHome = process.env.XDG_CONFIG_HOME ?? join(homedir(), ".config")
  const defaultPath = join(configHome, "opencode", "artifacts", "tunnel-token")
  const path = process.env.OPENCODE_ARTIFACT_TUNNEL_TOKEN_FILE ?? defaultPath

  try {
    return existsSync(path) && statSync(path).isFile() ? path : undefined
  } catch {
    return undefined
  }
}

export function startTunnelOnce(): ChildProcess | undefined {
  if (tunnelProcess) return tunnelProcess

  const tokenFile = tunnelTokenFile()
  if (!tokenFile) return undefined

  const child = spawn("cloudflared", ["tunnel", "run", "--token-file", tokenFile], {
    detached: true,
    stdio: "ignore",
  })

  const restart = () => {
    if (tunnelProcess !== child) return
    tunnelProcess = undefined
    if (tunnelRestartTimer || !tunnelTokenFile()) return

    const delay = tunnelRestartDelay
    tunnelRestartDelay = Math.min(tunnelRestartDelay * 2, 30_000)
    tunnelRestartTimer = setTimeout(() => {
      tunnelRestartTimer = undefined
      startTunnelOnce()
    }, delay)
  }

  child.on("error", restart)
  child.on("exit", restart)
  child.unref()
  tunnelProcess = child
  return tunnelProcess
}

export function run(): void {
  startServer()
  sweepRecords()
  startTunnelOnce()
}

if (import.meta.main) run()
