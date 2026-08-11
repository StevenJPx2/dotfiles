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
export const DEFAULT_TTL_MINUTES = 60
export const MIN_TTL_MINUTES = 1
export const MAX_TTL_MINUTES = 240
export const MAX_TITLE_CHARS = 200
export const MAX_HTML_BYTES = 500_000
export const ARTIFACT_HOST = "at.stjhn.xyz"
export const ID_LENGTH = 6
const ID_HEX = `[0-9a-f]{${ID_LENGTH}}`
export const ID_PATTERN = new RegExp(`^${ID_HEX}$`)
export const HEALTH_SERVICE = "opencode-artifacts"
export const LOCAL_ARTIFACT_PATH = "/__artifact"

export type ArtifactRecord = {
  title: string
  html: string
  expiresAt: number
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
    Number.isFinite(record.expiresAt)
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

  if (!Number.isInteger(ttlMinutes) || ttlMinutes < MIN_TTL_MINUTES || ttlMinutes > MAX_TTL_MINUTES) {
    throw new Error(`ttlMinutes must be an integer from ${MIN_TTL_MINUTES} to ${MAX_TTL_MINUTES}`)
  }
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

  const hostMatch = hostname.match(new RegExp(`^(${ID_HEX})\.${ARTIFACT_HOST.replaceAll(".", "\\\.")}$`))
  if (hostMatch && pathname === "/") return { kind: "artifact", id: hostMatch[1] }

  if (hostname === ARTIFACT_HOST) {
    const baseMatch = pathname.match(new RegExp("^/__artifact/(" + ID_HEX + ")$"))
    if (baseMatch) return { kind: "artifact", id: baseMatch[1] }
  }

  return { kind: "not-found" }
}

export function localArtifactUrl(id: string, port = DEFAULT_PORT): string {
  return `http://127.0.0.1:${port}${LOCAL_ARTIFACT_PATH}/${id}`
}

export function publicArtifactUrl(id: string): string {
  return `https://${id}.${ARTIFACT_HOST}/`
}

export function baseArtifactUrl(id: string): string {
  return `https://${ARTIFACT_HOST}${LOCAL_ARTIFACT_PATH}/${id}`
}

export async function selectPublicUrl(
  id: string,
  probe: (url: string) => Promise<boolean>,
): Promise<string | null> {
  for (const url of [publicArtifactUrl(id), baseArtifactUrl(id)]) {
    if (await probe(url)) return url
  }
  return null
}

export function securityHeaders(): Headers {
  return new Headers({
    "Content-Type": "text/html; charset=utf-8",
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
    "Content-Security-Policy":
      "default-src 'none'; style-src 'unsafe-inline'; img-src data:; font-src data:; script-src 'none'; connect-src 'none'; frame-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
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

  const headers = securityHeaders()
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
