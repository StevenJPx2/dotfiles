import {
  DEFAULT_TTL_MINUTES,
  composeContent,
  createId,
  validateInput,
  writeRecord,
} from "../host.ts"
import { artifactResult, contentProps, type ContentArgs } from "../runtime.ts"

type PublishArgs = ContentArgs & { title: string; ttlMinutes?: number }

export const publishTool = {
  name: "artifact_publish",
  description:
    "Publish an artifact from a Markdown string/file (preferred) or an HTML body string/file. Use an HTML body for charts and embedded content; omit styles to use the built-in stylesheet.",
  input: {
    type: "object",
    properties: {
      title: { type: "string" },
      ...contentProps,
      ttlMinutes: { type: "integer", minimum: 1 },
    },
    required: ["title"],
    additionalProperties: false,
  },
  async execute(raw: unknown) {
    const { title, ttlMinutes = DEFAULT_TTL_MINUTES, ...content } = raw as PublishArgs
    const composed = composeContent(content, {}, title)
    validateInput(title, composed.html, ttlMinutes)

    const id = createId()
    const expiresAt = Date.now() + ttlMinutes * 60_000
    writeRecord(id, { title, html: composed.html, markdown: composed.markdown, body: composed.body, styles: composed.styles, expiresAt })
    return { content: await artifactResult(id, composed.html, expiresAt) }
  },
} as const
