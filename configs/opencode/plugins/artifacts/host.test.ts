import { afterAll, beforeAll, describe, expect, test } from "bun:test"
import { mkdtempSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import {
  ARTIFACT_HOST,
  HEALTH_SERVICE,
  artifactPath,
  baseArtifactUrl,
  createId,
  handleRequest,
  isExpired,
  isValidId,
  isValidRecord,
  publicArtifactUrl,
  readRecord,
  routeRequest,
  securityHeaders,
  selectPublicUrl,
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

    expect(routeRequest(`${id}.at.stjhn.xyz`, "/")).toEqual({ kind: "artifact", id })
    expect(routeRequest(`${id}.at.stjhn.xyz`, "/not-root")).toEqual({ kind: "not-found" })
    expect(routeRequest(`${id}.at.stjhn.xyz`, `/__artifact/${id}`)).toEqual({ kind: "not-found" })
    expect(routeRequest(ARTIFACT_HOST, `/__artifact/${id}`)).toEqual({ kind: "artifact", id })
    expect(routeRequest(ARTIFACT_HOST, "/")).toEqual({ kind: "not-found" })
    expect(routeRequest(ARTIFACT_HOST, `/__artifact/nope`)).toEqual({ kind: "not-found" })
    expect(routeRequest(ARTIFACT_HOST, `/__artifact/${id}/extra`)).toEqual({ kind: "not-found" })
    expect(routeRequest("127.0.0.1:41783", "/health")).toEqual({ kind: "health" })
    expect(routeRequest("localhost", "/health")).toEqual({ kind: "health" })
    expect(routeRequest("example.com", "/health")).toEqual({ kind: "not-found" })
    expect(routeRequest("example.com", "/")).toEqual({ kind: "not-found" })
    expect(routeRequest("127.0.0.1", `/__artifact/${id}`)).toEqual({ kind: "artifact", id })
    expect(routeRequest("localhost", `/__artifact/${id}`)).toEqual({ kind: "artifact", id })
    expect(routeRequest("127.0.0.1", "/__artifact/nope")).toEqual({ kind: "not-found" })
  })

  test("detects expiry and deletes expired records", () => {
    const id = createId()
    const record = { title: "Expired", html: "<p>x</p>", expiresAt: 100 }
    expect(isExpired(record, 100)).toBe(true)
    writeRecord(id, record)
    expect(readRecord(id, 101)).toBeNull()
    expect(() => artifactPath(id)).not.toThrow()
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

  test("serves via the public Host-header route and the localhost fallback, rejects methods and missing ids", async () => {
    const id = createId()
    writeRecord(id, { title: "Live", html: "<h1>live</h1>", expiresAt: Date.now() + 60_000 })
    const server = startServer(0)

    try {
      const publicResponse = await fetch(`http://127.0.0.1:${server.port}/`, {
        headers: { host: `${id}.at.stjhn.xyz` },
      })
      expect(publicResponse.status).toBe(200)
      expect(await publicResponse.text()).toBe("<h1>live</h1>")
      expect(publicResponse.headers.get("cache-control")).toBe("no-store")

      const localResponse = await fetch(`http://127.0.0.1:${server.port}/__artifact/${id}`)
      expect(localResponse.status).toBe(200)
      expect(await localResponse.text()).toBe("<h1>live</h1>")

      const methodResponse = await fetch(`http://127.0.0.1:${server.port}/__artifact/${id}`, { method: "POST" })
      expect(methodResponse.status).toBe(405)

      const missingResponse = await fetch(`http://127.0.0.1:${server.port}/__artifact/${"a".repeat(32)}`)
      expect(missingResponse.status).toBe(404)

      const wrongHostResponse = await fetch(`http://127.0.0.1:${server.port}/`)
      expect(wrongHostResponse.status).toBe(404)

      const healthResponse = await fetch(`http://127.0.0.1:${server.port}/health`)
      expect(healthResponse.status).toBe(200)
      expect(await healthResponse.json()).toEqual({ service: HEALTH_SERVICE })
    } finally {
      server.stop()
    }
  })

  test("serves via the base public Host-header route and rejects non-artifact base paths", async () => {
    const id = createId()
    writeRecord(id, { title: "Live", html: "<h1>base</h1>", expiresAt: Date.now() + 60_000 })
    const server = startServer(0)

    try {
      const baseResponse = await fetch(`http://127.0.0.1:${server.port}/__artifact/${id}`, {
        headers: { host: ARTIFACT_HOST },
      })
      expect(baseResponse.status).toBe(200)
      expect(await baseResponse.text()).toBe("<h1>base</h1>")
      expect(baseResponse.headers.get("cache-control")).toBe("no-store")

      const baseRootResponse = await fetch(`http://127.0.0.1:${server.port}/`, {
        headers: { host: ARTIFACT_HOST },
      })
      expect(baseRootResponse.status).toBe(404)

      const baseMissingResponse = await fetch(`http://127.0.0.1:${server.port}/__artifact/${"a".repeat(32)}`, {
        headers: { host: ARTIFACT_HOST },
      })
      expect(baseMissingResponse.status).toBe(404)
    } finally {
      server.stop()
    }
  })

  test("selects the deep public URL first, then the base-path fallback, and null when both fail", async () => {
    const id = createId()
    const deep = publicArtifactUrl(id)
    const base = baseArtifactUrl(id)
    expect(base).toBe(`https://${ARTIFACT_HOST}/__artifact/${id}`)

    const seen: string[] = []
    const deepOk = await selectPublicUrl(id, async (url) => {
      seen.push(url)
      return url === deep
    })
    expect(deepOk).toBe(deep)
    expect(seen).toEqual([deep])

    const baseOnly = await selectPublicUrl(id, async (url) => url === base)
    expect(baseOnly).toBe(base)

    const bothFail = await selectPublicUrl(id, async () => false)
    expect(bothFail).toBeNull()
  })
})