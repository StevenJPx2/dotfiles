import { afterEach, beforeEach, expect, test } from "bun:test"
import { mkdtempSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join, resolve } from "node:path"
import plugin, {
  cacheKey,
  isPdfPath,
  mergeOcrResult,
  resolvePdfPath,
  wrapReadExecute,
  withOcrFailure,
  withOcrOutput,
  type Execute,
  type FileStat,
  type OcrRunner,
  type ToolContext,
} from "../pdf-ocr"

let dir: string
let pdfPath: string
let cacheDir: string

beforeEach(() => {
  dir = mkdtempSync(join(tmpdir(), "pdf-ocr-test-"))
  pdfPath = join(dir, "doc.pdf")
  cacheDir = join(dir, "cache")
  writeFileSync(pdfPath, "%PDF-1.4\nfake")
})

afterEach(() => {
  rmSync(dir, { recursive: true, force: true })
})

test("detects only real filesystem .pdf paths", () => {
  expect(isPdfPath("paper.pdf")).toBe(true)
  expect(isPdfPath("/tmp/A.PDF")).toBe(true)
  expect(isPdfPath("notes.txt")).toBe(false)
  expect(isPdfPath("skill://host/paper.pdf")).toBe(false)
  expect(isPdfPath("https://x/paper.pdf")).toBe(false)
  expect(isPdfPath(undefined)).toBe(false)
})

test("resolves relative paths against cwd and leaves absolute paths alone", () => {
  expect(resolvePdfPath("doc.pdf", "/workspace")).toBe("/workspace/doc.pdf")
  expect(resolvePdfPath("/abs/doc.pdf", "/workspace")).toBe("/abs/doc.pdf")
})

test("cache key changes with path, size and mtime", () => {
  const stat: FileStat = { size: 10, mtimeMs: 1000 }
  const key = cacheKey("/tmp/doc.pdf", stat)

  expect(cacheKey("/tmp/doc.pdf", { size: 10, mtimeMs: 1000 })).toBe(key)
  expect(cacheKey("/tmp/other.pdf", stat)).not.toBe(key)
  expect(cacheKey("/tmp/doc.pdf", { size: 11, mtimeMs: 1000 })).not.toBe(key)
  expect(cacheKey("/tmp/doc.pdf", { size: 10, mtimeMs: 1001 })).not.toBe(key)
})

test("prepends OCR text and preserves original content, output and metadata", () => {
  const original = {
    output: "OUT",
    content: [
      { type: "text" as const, text: "orig" },
      { type: "file" as const, uri: "file://x", mime: "application/pdf", name: "doc.pdf" },
    ],
    metadata: { pageCount: 1 },
  }
  const details = { engine: "indra-ocr", cached: false, ms: 5 }
  const merged = mergeOcrResult(original, "# OCR", details)

  expect((merged.content as any[])[0]).toEqual({ type: "text", text: "# OCR" })
  expect((merged.content as any[])[1]).toEqual(original.content[0])
  expect((merged.content as any[])[2]).toEqual(original.content[1])
  expect(merged.output).toBe("OUT")
  expect(merged.metadata?.pageCount).toBe(1)
  expect(merged.metadata?.ocr).toEqual(details)
  expect(original.content).toEqual([
    { type: "text", text: "orig" },
    { type: "file", uri: "file://x", mime: "application/pdf", name: "doc.pdf" },
  ])
  expect(original.metadata).toEqual({ pageCount: 1 })

  const fromString = mergeOcrResult({ content: "hello" }, "# OCR", details)
  expect(fromString.content).toEqual([
    { type: "text", text: "# OCR" },
    { type: "text", text: "hello" },
  ])

  const fromUndefined = mergeOcrResult({}, "# OCR", details)
  expect(fromUndefined.content).toEqual([{ type: "text", text: "# OCR" }])
})

test("leaves non-PDF reads completely unchanged", async () => {
  const originalResult = { content: [{ type: "text" as const, text: "file text" }] }
  let calls = 0
  const runOcr: OcrRunner = async () => {
    calls++
    throw new Error("should not be called")
  }
  const original: Execute = async () => originalResult
  const wrapped = wrapReadExecute(original, { runOcr, cacheDir })
  const ctx = { signal: new AbortController().signal } as unknown as ToolContext

  expect(await wrapped({ filePath: "notes.txt" }, ctx)).toEqual(originalResult)
  expect(calls).toBe(0)
})

test("OCRs a PDF, prepends text, then serves the cache", async () => {
  const originalResult = {
    output: { type: "media", uri: "file://x", mime: "application/pdf", name: "doc.pdf" },
    content: [{ type: "file" as const, uri: "file://x", mime: "application/pdf" }],
    metadata: { pageCount: 2 },
  }
  const original: Execute = async () => originalResult
  const calls: Array<{ file: string; signal?: AbortSignal }> = []
  const runOcr: OcrRunner = async (args) => {
    calls.push(args)
    return "# OCR text"
  }
  const wrapped = wrapReadExecute(original, { runOcr, cacheDir })
  const ctx = { signal: new AbortController().signal } as unknown as ToolContext

  const first: any = await wrapped({ filePath: pdfPath }, ctx)
  expect(calls).toEqual([{ file: resolve(pdfPath), signal: ctx.signal }])
  expect((first.content as any[])[0]).toEqual({ type: "text", text: "# OCR text" })
  expect((first.content as any[])[1]).toEqual(originalResult.content[0])
  expect(first.metadata.ocr.cached).toBe(false)
  expect(first.metadata.pageCount).toBe(2)
  expect((first.output as any).ocr).toBe("# OCR text")
  expect(first.output.type).toBe("media")
  expect(first.output.uri).toBe("file://x")
  expect(first.output.mime).toBe("application/pdf")
  expect(first.output.name).toBe("doc.pdf")

  const second: any = await wrapped({ filePath: pdfPath }, ctx)
  expect(calls.length).toBe(1)
  expect(second.metadata.ocr.cached).toBe(true)
  expect((second.content as any[])[0]).toEqual({ type: "text", text: "# OCR text" })
  expect((second.output as any).ocr).toBe("# OCR text")
})

test("falls back to original result plus a note when OCR fails", async () => {
  const originalResult = { content: [{ type: "text" as const, text: "orig" }] }
  const original: Execute = async () => originalResult
  const runOcr: OcrRunner = async () => {
    throw new Error("CLI missing")
  }
  const wrapped = wrapReadExecute(original, { runOcr, cacheDir })
  const ctx = { signal: new AbortController().signal } as unknown as ToolContext

  const result: any = await wrapped({ filePath: pdfPath }, ctx)
  expect((result.content as any[])[0].text).toContain("OCR skipped")
  expect((result.content as any[])[0].text).toContain("CLI missing")
  expect((result.content as any[])[1]).toEqual(originalResult.content[0])
  expect(result.metadata.ocr.error).toBe("CLI missing")
  expect(result.output.ocr).toBe("[OCR skipped: CLI missing]")

  const direct: any = withOcrFailure(originalResult, "boom", {
    engine: "indra-ocr",
    cached: false,
    ms: 1,
  })
  expect((direct.content as any[])[0]).toEqual({ type: "text", text: "[OCR skipped: boom]" })
})

test("abort handling forwards the signal and stays non-fatal", async () => {
  const controller = new AbortController()
  const originalResult = { content: [{ type: "text" as const, text: "orig" }] }
  const original: Execute = async () => originalResult
  let captured: AbortSignal | undefined
  const runOcr: OcrRunner = async ({ signal }) => {
    captured = signal
    throw new Error("aborted")
  }
  const wrapped = wrapReadExecute(original, { runOcr, cacheDir })
  const ctx = { signal: controller.signal } as unknown as ToolContext

  const result: any = await wrapped({ filePath: pdfPath }, ctx)
  expect(captured).toBe(controller.signal)
  expect((result.content as any[])[0].text).toContain("aborted")
  expect((result.content as any[])[1]).toEqual(originalResult.content[0])
})

test("propagates errors from the original read and never runs OCR", async () => {
  let calls = 0
  const runOcr: OcrRunner = async () => {
    calls++
    return ""
  }
  const original: Execute = async () => {
    throw new Error("denied")
  }
  const wrapped = wrapReadExecute(original, { runOcr, cacheDir })
  const ctx = { signal: new AbortController().signal } as unknown as ToolContext

  await expect(wrapped({ filePath: pdfPath }, ctx)).rejects.toThrow("denied")
  expect(calls).toBe(0)
})

test("keeps non-PDF output untouched", async () => {
  const originalResult = {
    output: { type: "media", uri: "file://x", mime: "application/pdf", name: "doc.pdf" },
    content: [{ type: "text" as const, text: "file text" }],
  }
  const runOcr: OcrRunner = async () => {
    throw new Error("should not be called")
  }
  const original: Execute = async () => originalResult
  const wrapped = wrapReadExecute(original, { runOcr, cacheDir })
  const ctx = { signal: new AbortController().signal } as unknown as ToolContext

  const result: any = await wrapped({ filePath: "notes.txt" }, ctx)
  expect(result).toEqual(originalResult)
  expect("ocr" in (result as any).output).toBe(false)
})

test("withOcrOutput keeps media fields and does not mutate the original", () => {
  const original = { output: { type: "media", uri: "file://x" } }
  const result = withOcrOutput(original, "T")

  expect((result.output as any).ocr).toBe("T")
  expect(result.output).toEqual({ type: "media", uri: "file://x", ocr: "T" })
  expect(result).not.toBe(original)
  expect(result.output).not.toBe(original.output)
  expect(original.output).toEqual({ type: "media", uri: "file://x" })
})

test("wrapping is idempotent", () => {
  const original: Execute = async () => ({ content: [] })
  const deps = { runOcr: (async () => "") as OcrRunner, cacheDir }
  const once = wrapReadExecute(original, deps)
  const twice = wrapReadExecute(once, deps)

  expect(twice).toBe(once)
})

test("plugin registers a transform that wraps read", async () => {
  let transform: ((editor: any) => void) | undefined
  await plugin.setup({
    tool: { transform: async (fn: any) => { transform = fn } },
  } as unknown as Parameters<typeof plugin.setup>[0])
  expect(transform).toBeDefined()

  const fakeOriginal: Execute = async () => ({ content: [] })
  const draft = { execute: fakeOriginal, output: undefined }
  const editor = {
    update: (id: string, cb: (d: typeof draft) => void) => {
      if (id === "read") cb(draft)
    },
  }

  transform!(editor)
  expect(draft.execute).not.toBe(fakeOriginal)
  expect(draft.output).toBeDefined()
  expect((draft.output as any).additionalProperties).toBe(true)
  expect((draft.output as any).properties.ocr).toEqual({ type: "string" })
})
