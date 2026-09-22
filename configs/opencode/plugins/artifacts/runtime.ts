import { spawn } from "node:child_process"
import { fileURLToPath } from "node:url"
import {
  DEFAULT_PORT,
  HEALTH_SERVICE,
  localArtifactUrl,
  publicArtifactUrl,
} from "./host.ts"

const hostPath = fileURLToPath(new URL("./host.ts", import.meta.url))
const PROBE_ATTEMPTS = 5
const PROBE_RETRY_MS = 1_000
const PROBE_TIMEOUT_MS = 5_000
let hostStarting: Promise<void> | undefined

async function hostIsReady(port: number): Promise<boolean> {
  try {
    const response = await fetch(`http://127.0.0.1:${port}/health`, {
      signal: AbortSignal.timeout(1_000),
    })
    if (!response.ok) return false
    const body = await response.json()
    return typeof body === "object" && body !== null && body.service === HEALTH_SERVICE
  } catch {
    return false
  }
}

async function ensureHost(): Promise<void> {
  const port = Number(process.env.OPENCODE_ARTIFACT_PORT ?? DEFAULT_PORT)
  if (await hostIsReady(port)) return
  if (hostStarting) return hostStarting

  hostStarting = (async () => {
    const child = spawn("bun", ["run", hostPath], {
      detached: true,
      stdio: "ignore",
      env: { ...process.env, OPENCODE_ARTIFACT_PORT: String(port) },
    })
    child.on("error", () => {})
    child.on("exit", () => {})
    child.unref()

    for (let attempt = 0; attempt < 50; attempt++) {
      if (await hostIsReady(port)) return
      await Bun.sleep(100)
    }

    throw new Error(`artifact host did not start on 127.0.0.1:${port}`)
  })().finally(() => {
    hostStarting = undefined
  })

  return hostStarting
}

async function publicUrlRespondsWith(url: string, html: string): Promise<boolean> {
  for (let attempt = 0; attempt < PROBE_ATTEMPTS; attempt++) {
    try {
      const response = await fetch(url, { signal: AbortSignal.timeout(PROBE_TIMEOUT_MS) })
      if (response.status === 200 && (await response.text()) === html) return true
    } catch {
      // tunnel may still be establishing; retry briefly
    }
    await Bun.sleep(PROBE_RETRY_MS)
  }
  return false
}

export async function artifactResult(id: string, html: string, expiresAt: number): Promise<string> {
  await ensureHost()

  const localBaseUrl = process.env.OPENCODE_ARTIFACT_LOCAL_BASE_URL?.replace(/\/+$/, "")
  const publicUrl = localBaseUrl ? null : (await publicUrlRespondsWith(publicArtifactUrl(id), html))
    ? publicArtifactUrl(id)
    : null
  const result: {
    url?: string
    localUrl: string
    expiresAt: number
    tunnelConfigured: boolean
    warning?: string
  } = {
    localUrl: localBaseUrl
      ? `${localBaseUrl}/__artifact/${id}`
      : localArtifactUrl(id, Number(process.env.OPENCODE_ARTIFACT_PORT ?? DEFAULT_PORT)),
    expiresAt,
    tunnelConfigured: Boolean(publicUrl),
  }

  if (publicUrl) {
    result.url = publicUrl
  } else {
    result.warning =
      "Public tunnel not reachable (token file missing or tunnel down); artifact is available via localUrl only."
  }

  return JSON.stringify(result)
}

export const contentProps = {
  file: { type: "string" },
  markdown: { type: "string" },
  body: { type: "string" },
  styles: { type: "string" },
} as const

export type ContentArgs = { file?: string; markdown?: string; body?: string; styles?: string }
