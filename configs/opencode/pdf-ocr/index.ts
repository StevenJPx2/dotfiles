import { execFile } from "node:child_process"
import { createHash } from "node:crypto"
import { existsSync, mkdirSync, readFileSync, statSync, writeFileSync } from "node:fs"
import { homedir } from "node:os"
import { join, resolve } from "node:path"
import { promisify } from "node:util"
import { Plugin } from "@opencode/plugin"
import type { Result, ToolContext } from "@opencode/plugin/promise/tool"

export type { ToolContext }

export const OCR_TIMEOUT_MS = 5 * 60 * 1000
export const OCR_COMMAND = "indra-ocr"

export type ReadInput = { filePath?: string; path?: string; [key: string]: unknown }
export type Execute = (input: ReadInput, context: ToolContext) => Promise<Result>
export type FileStat = { size: number; mtimeMs: number }
export type OcrRunner = (args: { file: string; signal?: AbortSignal }) => Promise<string>
export type OcrDetails = { engine: string; cached: boolean; ms: number; error?: string }

// OpenCode replays tool transforms on registry reloads. Mark the wrapped
// executor so a replay returns the same function instead of wrapping twice.
const WRAPPED = Symbol.for("pdf-ocr.wrapped")

const execFileAsync = promisify(execFile)

export function defaultCacheDir(): string {
  const base = process.env.XDG_CACHE_HOME || join(homedir(), ".cache")
  return join(base, "opencode", "pdf-ocr")
}

export function isPdfPath(raw: unknown): raw is string {
  if (typeof raw !== "string") return false
  if (raw.includes("://")) return false
  return /\.pdf$/i.test(raw)
}

export function resolvePdfPath(raw: string, cwd = process.cwd()): string {
  return resolve(cwd, raw)
}

export function statForCache(path: string): FileStat | null {
  try {
    const s = statSync(path)
    if (!s.isFile()) return null
    return { size: s.size, mtimeMs: s.mtimeMs }
  } catch {
    return null
  }
}

export function cacheKey(path: string, stat: FileStat): string {
  return createHash("sha256")
    .update(path + "\0" + stat.size + "\0" + stat.mtimeMs)
    .digest("hex")
}

export function readCache(cacheDir: string, key: string): string | null {
  const file = join(cacheDir, key + ".md")
  if (!existsSync(file)) return null
  try {
    return readFileSync(file, "utf8")
  } catch {
    return null
  }
}

export function writeCache(cacheDir: string, key: string, markdown: string): void {
  try {
    mkdirSync(cacheDir, { recursive: true })
    writeFileSync(join(cacheDir, key + ".md"), markdown, "utf8")
  } catch {
    // Best effort: caching must never break a read.
  }
}

export const defaultOcrRunner: OcrRunner = async ({ file, signal }) => {
  const { stdout } = await execFileAsync(
    OCR_COMMAND,
    [file, "--format", "md", "--cores", "4"],
    { timeout: OCR_TIMEOUT_MS, signal, maxBuffer: 32 * 1024 * 1024 },
  )
  return String(stdout)
}

export function mergeOcrResult(result: Result, markdown: string, details: OcrDetails): Result {
  const ocrPart = { type: "text" as const, text: markdown }
  const prev = result.content
  let content

  if (prev === undefined) {
    content = [ocrPart]
  } else if (typeof prev === "string") {
    content = [ocrPart, { type: "text" as const, text: prev }]
  } else {
    content = [ocrPart, ...prev]
  }

  return {
    ...result,
    content,
    metadata: { ...result.metadata, ocr: details },
  }
}

export function withOcrFailure(result: Result, reason: string, details: OcrDetails): Result {
  return mergeOcrResult(result, "[OCR skipped: " + reason + "]", {
    ...details,
    error: reason,
  })
}

export function withOcrOutput(result: Result, ocr: string): Result {
  const original = result.output
  const base = original !== null && typeof original === "object" && !Array.isArray(original)
    ? { ...(original as Record<string, unknown>) }
    : { value: original }

  return { ...result, output: { ...base, ocr } }
}

export function wrapReadExecute(
  original: Execute,
  deps: { runOcr?: OcrRunner; cacheDir?: string } = {},
): Execute {
  const runOcr = deps.runOcr ?? defaultOcrRunner
  const cacheDir = deps.cacheDir ?? defaultCacheDir()

  if ((original as any)[WRAPPED]) return original

  const wrapped: Execute = async (input, context) => {
    // Run the original read first: this preserves permissions and media.
    const result = await original(input, context)

    const raw = input?.filePath ?? input?.path
    if (!isPdfPath(raw)) return result

    const full = resolvePdfPath(raw)
    const stat = statForCache(full)
    if (!stat) return result

    const key = cacheKey(full, stat)
    const started = Date.now()
    const cached = readCache(cacheDir, key)
    if (cached !== null) {
      return withOcrOutput(
        mergeOcrResult(result, cached, {
          engine: OCR_COMMAND,
          cached: true,
          ms: Date.now() - started,
        }),
        cached,
      )
    }

    try {
      const markdown = await runOcr({ file: full, signal: context.signal })
      writeCache(cacheDir, key, markdown)
      return withOcrOutput(
        mergeOcrResult(result, markdown, {
          engine: OCR_COMMAND,
          cached: false,
          ms: Date.now() - started,
        }),
        markdown,
      )
    } catch (error) {
      const reason = error instanceof Error ? error.message : String(error)
      const note = "[OCR skipped: " + reason + "]"
      return withOcrOutput(
        withOcrFailure(result, reason, {
          engine: OCR_COMMAND,
          cached: false,
          ms: Date.now() - started,
          error: reason,
        }),
        note,
      )
    }
  }

  Object.defineProperty(wrapped, WRAPPED, { value: true })
  return wrapped
}

export default Plugin.define({
  id: "pdf-ocr",
  async setup(ctx) {
    await ctx.tool.transform((editor) => {
      editor.update("read", (draft) => {
        draft.execute = wrapReadExecute(draft.execute)
        draft.output = {
          type: "object",
          properties: {
            type: { type: "string" },
            uri: { type: "string" },
            mime: { type: "string" },
            name: { type: "string" },
            content: { type: "string" },
            ocr: { type: "string" },
          },
          additionalProperties: true,
        } as typeof draft.output
      })
    })
  },
})
