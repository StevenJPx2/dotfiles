import {
  DEFAULT_TTL_MINUTES,
  composeContent,
  isValidId,
  readRecord,
  renderMarkdown,
  renderBody,
  replaceFirst,
  validateInput,
  writeRecord,
} from "../host.ts"
import { artifactResult, contentProps, type ContentArgs } from "../runtime.ts"

type EditArgs = ContentArgs & {
  id: string
  title?: string
  ttlMinutes?: number
  patch?: { search: string; replace: string }
}

export const editTool = {
  name: "artifact_edit",
  description: "Edit an existing artifact while keeping its URL and ID.",
  input: {
    type: "object",
    properties: {
      id: { type: "string" },
      title: { type: "string" },
      ...contentProps,
      ttlMinutes: { type: "integer", minimum: 1 },
      patch: {
        type: "object",
        properties: { search: { type: "string", minLength: 1 }, replace: { type: "string" } },
        required: ["search", "replace"],
        additionalProperties: false,
      },
    },
    required: ["id"],
    additionalProperties: false,
  },
  async execute(raw: unknown) {
    const { id, title, ttlMinutes, patch, ...content } = raw as EditArgs
    if (!isValidId(id)) throw new Error("invalid artifact id")

    const current = readRecord(id)
    if (!current) throw new Error("artifact not found or expired")
    const hasContent = Object.values(content).some((value) => value !== undefined)
    if (patch !== undefined && hasContent) {
      throw new Error("provide either patch or file/markdown/body/styles, not both")
    }
    if (title === undefined && ttlMinutes === undefined && !hasContent && patch === undefined) {
      throw new Error("provide a title, file, markdown, body, styles, or ttlMinutes change")
    }

    const nextTitle = title ?? current.title

    let html = current.html
    let markdown = current.markdown
    let body = current.body
    let styles = current.styles
    if (patch !== undefined) {
      const source = current.markdown ?? current.body ?? current.html
      const patched = replaceFirst(source, patch.search, patch.replace)
      if (current.markdown !== undefined) {
        markdown = patched
        html = renderMarkdown(markdown, styles, nextTitle)
      } else if (current.body !== undefined) {
        body = patched
        html = renderBody(body, styles, nextTitle)
      } else {
        html = patched
      }
    } else if (hasContent) {
      const composed = composeContent(content, { body: current.body, markdown: current.markdown, styles: current.styles }, nextTitle)
      html = composed.html
      markdown = composed.markdown
      body = composed.body
      styles = composed.styles
    } else if (title !== undefined && current.markdown !== undefined) {
      html = renderMarkdown(current.markdown, current.styles, nextTitle)
    } else if (title !== undefined && current.body !== undefined) {
      html = renderBody(current.body, current.styles, nextTitle)
    }

    validateInput(nextTitle, html, ttlMinutes ?? DEFAULT_TTL_MINUTES)

    const expiresAt = ttlMinutes === undefined ? current.expiresAt : Date.now() + ttlMinutes * 60_000
    writeRecord(id, { title: nextTitle, html, markdown, body, styles, expiresAt })
    return { content: await artifactResult(id, html, expiresAt) }
  },
} as const
