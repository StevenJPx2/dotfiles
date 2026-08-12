import { spawn } from "node:child_process"
import { fileURLToPath } from "node:url"
import { tool } from "@opencode-ai/plugin"
import {
  DEFAULT_PORT,
  DEFAULT_TTL_MINUTES,
  HEALTH_SERVICE,
  composeContent,
  createId,
  deleteRecord,
  isValidId,
  localArtifactUrl,
  publicArtifactUrl,
  readRecord,
  renderBody,
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

async function artifactResult(id: string, html: string, expiresAt: number): Promise<string> {
  await ensureHost()

  const publicUrl = (await publicUrlRespondsWith(publicArtifactUrl(id), html))
    ? publicArtifactUrl(id)
    : null
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
}

const contentArgs = {
  html: z.string().optional(),
  body: z.string().optional(),
  styles: z.string().optional(),
}

export const ArtifactsPlugin = async () => ({
  tool: {
    artifact_publish: tool({
      description:
        "Publish an artifact from body content or complete static HTML. Omit styles to use the built-in stylesheet.",
      args: {
        title: z.string(),
        ...contentArgs,
        ttlMinutes: z.number().int().min(1).max(240).optional().default(DEFAULT_TTL_MINUTES),
      },
      async execute({ title, ttlMinutes = DEFAULT_TTL_MINUTES, ...content }) {
        const composed = composeContent(content, {}, title)
        validateInput(title, composed.html, ttlMinutes)

        const id = createId()
        const expiresAt = Date.now() + ttlMinutes * 60_000
        writeRecord(id, { title, html: composed.html, body: composed.body, styles: composed.styles, expiresAt })
        return artifactResult(id, composed.html, expiresAt)
      },
    }),
    artifact_edit: tool({
      description: "Edit an existing artifact while keeping its URL and ID.",
      args: {
        id: z.string(),
        title: z.string().optional(),
        ...contentArgs,
        ttlMinutes: z.number().int().min(1).max(240).optional(),
      },
      async execute({ id, title, ttlMinutes, ...content }) {
        if (!isValidId(id)) throw new Error("invalid artifact id")

        const current = readRecord(id)
        if (!current) throw new Error("artifact not found or expired")
        if (title === undefined && ttlMinutes === undefined && Object.keys(content).every((key) => content[key as keyof typeof content] === undefined)) {
          throw new Error("provide a title, body, styles, html, or ttlMinutes change")
        }

        const nextTitle = title ?? current.title

        let html = current.html
        let body = current.body
        let styles = current.styles
        if (Object.values(content).some((value) => value !== undefined)) {
          const composed = composeContent(content, { body: current.body, styles: current.styles }, nextTitle)
          html = composed.html
          body = composed.body
          styles = composed.styles
        } else if (title !== undefined && current.body !== undefined) {
          html = renderBody(current.body, current.styles, nextTitle)
        }

        validateInput(nextTitle, html, ttlMinutes ?? DEFAULT_TTL_MINUTES)

        const expiresAt = ttlMinutes === undefined ? current.expiresAt : Date.now() + ttlMinutes * 60_000
        writeRecord(id, { title: nextTitle, html, body, styles, expiresAt })
        return artifactResult(id, html, expiresAt)
      },
    }),
    artifact_delete: tool({
      description: "Delete an existing artifact immediately.",
      args: { id: z.string() },
      async execute({ id }) {
        if (!isValidId(id)) throw new Error("invalid artifact id")
        return JSON.stringify({ id, deleted: deleteRecord(id) })
      },
    }),
  },
})

export default ArtifactsPlugin
