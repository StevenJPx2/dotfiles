import { afterAll, beforeAll, describe, expect, test } from "bun:test"
import { mkdtempSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import {
  ARTIFACT_HOST,
  DEFAULT_STYLES,
  HEALTH_SERVICE,
  artifactPath,
  composeContent,
  createId,
  deleteRecord,
  handleRequest,
  isExpired,
  isValidId,
  isValidRecord,
  publicArtifactUrl,
  readRecord,
  renderBody,
  resolveContent,
  routeRequest,
  securityHeaders,
  startServer,
  sweepRecords,
  validateInput,
  writeRecord,
} from "./host.ts"

const cacheRoot = mkdtempSync(join(tmpdir(), "opencode-artifacts-test-"))
process.env.XDG_CACHE_HOME = cacheRoot

beforeAll(() => {
  process.env.OPENCODE_ARTIFACT_TUNNEL_TOKEN_FILE = join(cacheRoot, "missing-token")
})

afterAll(() => {
  delete process.env.OPENCODE_ARTIFACT_TUNNEL_TOKEN_FILE
  delete process.env.XDG_CACHE_HOME
  rmSync(cacheRoot, { recursive: true, force: true })
})

describe("artifact host helpers", () => {
  test("validates ids and routes only artifact hostnames", () => {
    const id = createId()
    expect(id).toMatch(/^[0-9a-f]{6}$/)
    expect(isValidId(id)).toBe(true)
    expect(isValidId("a".repeat(5))).toBe(false)
    expect(isValidId("g".repeat(6))).toBe(false)

    expect(routeRequest(ARTIFACT_HOST, `/${id}`)).toEqual({ kind: "artifact", id })
    expect(routeRequest(ARTIFACT_HOST, "/")).toEqual({ kind: "not-found" })
    expect(routeRequest(ARTIFACT_HOST, `/nope`)).toEqual({ kind: "not-found" })
    expect(routeRequest(ARTIFACT_HOST, `/${id}/extra`)).toEqual({ kind: "not-found" })
    expect(routeRequest(`${id}.at.stjhn.xyz`, "/")).toEqual({ kind: "not-found" })

    expect(routeRequest("127.0.0.1:41783", "/health")).toEqual({ kind: "health" })
    expect(routeRequest("localhost", "/health")).toEqual({ kind: "health" })
    expect(routeRequest("127.0.0.1", `/${id}`)).toEqual({ kind: "not-found" })
    expect(routeRequest("127.0.0.1", `/__artifact/${id}`)).toEqual({ kind: "artifact", id })
    expect(routeRequest("localhost", `/__artifact/${id}`)).toEqual({ kind: "artifact", id })
    expect(routeRequest("127.0.0.1", "/__artifact/nope")).toEqual({ kind: "not-found" })
    expect(routeRequest("example.com", "/health")).toEqual({ kind: "not-found" })
    expect(routeRequest("example.com", "/")).toEqual({ kind: "not-found" })
  })

  test("detects expiry and deletes expired records", () => {
    const id = createId()
    const record = { title: "Expired", html: "<p>x</p>", expiresAt: 100 }
    expect(isExpired(record, 100)).toBe(true)
    writeRecord(id, record)
    expect(readRecord(id, 101)).toBeNull()
  })

  test("validates title, html bytes, and ttl bounds", () => {
    expect(() => validateInput("", "x")).toThrow()
    expect(() => validateInput("a".repeat(201), "x")).toThrow()
    expect(() => validateInput("x", "")).toThrow()
    expect(() => validateInput("x", "é".repeat(250_001))).toThrow()
    expect(() => validateInput("x", "x", 0)).toThrow()
    expect(() => validateInput("x", "x", 241)).toThrow()
    expect(() => validateInput("x", "x", 60)).not.toThrow()
  })

  test("rejects invalid or corrupt records", () => {
    expect(isValidRecord(null)).toBe(false)
    expect(isValidRecord({ title: "x", html: "y", expiresAt: "soon" })).toBe(false)
    expect(isValidRecord({ title: "x", html: "y", expiresAt: NaN })).toBe(false)
    expect(isValidRecord({ title: "", html: "y", expiresAt: Date.now() + 1000 })).toBe(false)
    expect(isValidRecord({ title: "x", html: "y", expiresAt: Date.now() + 1000 })).toBe(true)
    expect(isValidRecord({ title: "x", html: "y", expiresAt: Date.now() + 1000, body: "<p>b</p>", styles: "p{}" })).toBe(true)
    expect(isValidRecord({ title: "x", html: "y", expiresAt: Date.now() + 1000, body: 5 })).toBe(false)
  })

  test("wraps body with a gruvbox baseline and honors custom styles", () => {
    expect(DEFAULT_STYLES).toContain("#282828")
    expect(DEFAULT_STYLES).toContain("#b8bb26")

    const document = renderBody("<h1>hi</h1>")
    expect(document).toContain("<!doctype html>")
    expect(document).toContain("<style>")
    expect(document).toContain("<h1>hi</h1>")
    expect(document).toContain("#282828")
    expect(document).not.toContain("<title>")

    const titled = renderBody("<h1>hi</h1>", DEFAULT_STYLES, "My Page")
    expect(titled).toContain("<title>My Page</title>")

    const escaped = renderBody("<h1>hi</h1>", DEFAULT_STYLES, "<b>& \"x\"</b>")
    expect(escaped).toContain("<title>&lt;b&gt;&amp; &quot;x&quot;&lt;/b&gt;</title>")

    const custom = renderBody("<h1>hi</h1>", "h1 { color: hotpink; }", "T")
    expect(custom).toContain("h1 { color: hotpink; }")
    expect(custom).not.toContain("#282828")
  })

  test("composes content: body or html, never both, merges prior styles on edit", () => {
    const styled = composeContent({ body: "<p>a</p>", styles: "p { color: red; }" }, {}, "Doc Title")
    expect(styled.html).toContain("p { color: red; }")
    expect(styled.html).toContain("<title>Doc Title</title>")
    expect(styled.body).toBe("<p>a</p>")
    expect(styled.styles).toBe("p { color: red; }")

    const plain = composeContent({ body: "<p>a</p>" })
    expect(plain.html).toContain("<style>")
    expect(plain.body).toBe("<p>a</p>")
    expect(plain.styles).toBeUndefined()

    const raw = composeContent({ html: "<p>raw</p>" })
    expect(raw.html).toBe("<p>raw</p>")
    expect(raw.body).toBeUndefined()

    const prior = { body: "<p>old</p>", styles: "p { color: hotpink; }" }
    const editedBody = composeContent({ body: "<p>new</p>" }, prior, "New Title")
    expect(editedBody.html).toContain("hotpink")
    expect(editedBody.html).toContain("<p>new</p>")
    expect(editedBody.html).toContain("<title>New Title</title>")

    const editedStyles = composeContent({ styles: "p { color: lime; }" }, prior)
    expect(editedStyles.html).toContain("lime")
    expect(editedStyles.html).toContain("<p>old</p>")

    const cleared = composeContent({ html: "<p>full</p>" }, prior)
    expect(cleared.body).toBeUndefined()
    expect(cleared.styles).toBeUndefined()

    expect(() => composeContent({})).toThrow()
    expect(() => composeContent({ html: "x", body: "y" })).toThrow()
    expect(() => composeContent({ html: "x", styles: "y" })).toThrow()
    expect(() => composeContent({ styles: "p{}" })).toThrow()
  })

  test("builds required security headers with quoted CSP", () => {
    const headers = securityHeaders()
    expect(headers.get("Content-Type")).toBe("text/html; charset=utf-8")
    expect(headers.get("Cache-Control")).toBe("no-store")
    expect(headers.get("X-Content-Type-Options")).toBe("nosniff")
    expect(headers.get("Referrer-Policy")).toBe("no-referrer")
    expect(headers.get("Content-Security-Policy")).toBe(
      "default-src 'none'; style-src 'unsafe-inline'; img-src data:; font-src data:; script-src 'none'; connect-src 'none'; frame-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
    )
  })

  test("health reports the artifact service identity", async () => {
    const response = handleRequest(new Request("http://127.0.0.1/health"))
    expect(response.status).toBe(200)
    expect(await response.json()).toEqual({ service: HEALTH_SERVICE })
  })

  test("sweeps expired and corrupt records on startup", () => {
    const liveId = createId()
    writeRecord(liveId, { title: "Live", html: "<p>live</p>", expiresAt: Date.now() + 60_000 })

    const expiredId = createId()
    writeRecord(expiredId, { title: "Expired", html: "<p>x</p>", expiresAt: Date.now() - 1 })

    const corruptId = createId()
    writeRecord(corruptId, { title: "Corrupt", html: "x", expiresAt: Date.now() + 60_000 })
    writeFileSync(artifactPath(corruptId), "{not json")

    expect(sweepRecords()).toBe(2)
    expect(readRecord(liveId)).not.toBeNull()
    expect(readRecord(expiredId)).toBeNull()
    expect(readRecord(corruptId)).toBeNull()
  })

  test("deletes an existing record and reports missing or invalid ids", () => {
    const id = createId()
    expect(deleteRecord(id)).toBe(false)
    writeRecord(id, { title: "Gone", html: "<p>gone</p>", expiresAt: Date.now() + 60_000 })
    expect(deleteRecord(id)).toBe(true)
    expect(readRecord(id)).toBeNull()
    expect(deleteRecord("nope")).toBe(false)
  })

  test("serves via the public Host-header route and the localhost fallback, rejects methods and missing ids", async () => {
    const id = createId()
    writeRecord(id, { title: "Live", html: "<h1>live</h1>", expiresAt: Date.now() + 60_000 })
    const server = startServer(0)

    try {
      const publicResponse = await fetch(`http://127.0.0.1:${server.port}/${id}`, {
        headers: { host: ARTIFACT_HOST },
      })
      expect(publicResponse.status).toBe(200)
      expect(await publicResponse.text()).toBe("<h1>live</h1>")
      expect(publicResponse.headers.get("cache-control")).toBe("no-store")

      const localResponse = await fetch(`http://127.0.0.1:${server.port}/__artifact/${id}`)
      expect(localResponse.status).toBe(200)
      expect(await localResponse.text()).toBe("<h1>live</h1>")

      const methodResponse = await fetch(`http://127.0.0.1:${server.port}/__artifact/${id}`, { method: "POST" })
      expect(methodResponse.status).toBe(405)

      const missingResponse = await fetch(`http://127.0.0.1:${server.port}/__artifact/${"a".repeat(6)}`)
      expect(missingResponse.status).toBe(404)

      const wrongHostResponse = await fetch(`http://127.0.0.1:${server.port}/${id}`)
      expect(wrongHostResponse.status).toBe(404)

      const healthResponse = await fetch(`http://127.0.0.1:${server.port}/health`)
      expect(healthResponse.status).toBe(200)
      expect(await healthResponse.json()).toEqual({ service: HEALTH_SERVICE })
    } finally {
      server.stop()
    }
  })

  test("builds the direct public URL on the artifact host", () => {
    expect(publicArtifactUrl("abc123")).toBe(`https://${ARTIFACT_HOST}/abc123`)
  })
})
