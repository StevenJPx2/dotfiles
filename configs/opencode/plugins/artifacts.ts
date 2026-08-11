import { spawn } from "node:child_process"
import { fileURLToPath } from "node:url"
import { tool } from "@opencode-ai/plugin"
import {
  DEFAULT_PORT,
  DEFAULT_TTL_MINUTES,
  HEALTH_SERVICE,
  createId,
  localArtifactUrl,
  selectPublicUrl,
  validateInput,
  writeRecord,
} from "./artifacts/host.ts"

const z = tool.schema
const hostPath = fileURLToPath(new URL("./artifacts/host.ts", import.meta.url))
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

export const ArtifactsPlugin = async () => ({
  tool: {
    artifact_publish: tool({
      description:
        "Publish complete static HTML when the user requests a hosted artifact or when a visual plan materially helps. Returns a short-lived public URL when the tunnel is reachable, otherwise a local fallback; hosting details stay hidden from the caller.",
      args: {
        title: z.string(),
        html: z.string(),
        ttlMinutes: z.number().int().min(1).max(240).optional().default(DEFAULT_TTL_MINUTES),
      },
      async execute({ title, html, ttlMinutes = DEFAULT_TTL_MINUTES }) {
        validateInput(title, html, ttlMinutes)

        const id = createId()
        const expiresAt = Date.now() + ttlMinutes * 60_000
        writeRecord(id, { title, html, expiresAt })
        await ensureHost()

        const publicUrl = await selectPublicUrl(id, (url) => publicUrlRespondsWith(url, html))
        const result: {
          url?: string
          localUrl: string
          expiresAt: number
          tunnelConfigured: boolean
          warning?: string
        } = {
          localUrl: localArtifactUrl(id, Number(process.env.OPENCODE_ARTIFACT_PORT ?? DEFAULT_PORT)),
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
      },
    }),
  },
})

export default ArtifactsPlugin
