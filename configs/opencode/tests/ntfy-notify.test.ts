import { afterEach, describe, expect, test } from "bun:test"
import { mkdtempSync, rmSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"

const originalFetch = globalThis.fetch
const originalToken = process.env.OPENCODE_NTFY_TOKEN
const originalURL = process.env.OPENCODE_NTFY_URL
const originalCacheHome = process.env.XDG_CACHE_HOME
const testCacheHome = mkdtempSync(join(tmpdir(), "ntfy-notify-test-"))

process.env.OPENCODE_NTFY_TOKEN = "test-token"
process.env.OPENCODE_NTFY_URL = "https://ntfy.test/opencode"
process.env.XDG_CACHE_HOME = testCacheHome

const { default: plugin } = await import("../plugins/ntfy-notify")

afterEach(() => {
  globalThis.fetch = originalFetch
  rmSync(testCacheHome, { recursive: true, force: true })

  if (originalToken === undefined) delete process.env.OPENCODE_NTFY_TOKEN
  else process.env.OPENCODE_NTFY_TOKEN = originalToken

  if (originalURL === undefined) delete process.env.OPENCODE_NTFY_URL
  else process.env.OPENCODE_NTFY_URL = originalURL

  if (originalCacheHome === undefined) delete process.env.XDG_CACHE_HOME
  else process.env.XDG_CACHE_HOME = originalCacheHome
})

describe("ntfy-notify", () => {
  test("sends one approval only while it is pending, plus question and completion notifications", async () => {
    const requests: Array<{ headers: Headers; body: string }> = []
    const permissionChecks: string[] = []
    const pendingPermissions = new Set(["permission-auto", "permission-pending"])

    let resolveEventsHandled!: () => void
    const eventsHandled = new Promise<void>((resolve) => {
      resolveEventsHandled = resolve
    })

    setTimeout(() => pendingPermissions.delete("permission-auto"), 75)

    globalThis.fetch = async (_input, init) => {
      requests.push({
        headers: new Headers(init?.headers),
        body: typeof init?.body === "string" ? init.body : "",
      })

      return new Response(null, { status: 200 })
    }

    async function* events() {
      const created = Date.now()

      yield {
        id: "event-form",
        created,
        type: "form.created",
        data: {
          form: {
            sessionID: "session-1",
            title: "OpenCode needs input",
            fields: [
              {
                key: "scope",
                title: "Scope",
                description: "Which files should I change?",
                options: [{ value: "all", label: "All files" }],
              },
            ],
          },
        },
      }
      yield {
        id: "event-auto-permission",
        created,
        type: "permission.asked",
        data: {
          id: "permission-auto",
          sessionID: "session-1",
          action: "edit",
          resources: ["generated-file"],
          message: "This permission is auto-approved.",
        },
      }
      const pendingPermission = {
        id: "event-pending-permission",
        created,
        type: "permission.asked",
        data: {
          id: "permission-pending",
          sessionID: "session-1",
          action: "edit",
          resources: ["README.md"],
          message: "Allow this edit?",
        },
      }

      for (let attempt = 0; attempt < 12; attempt++) yield pendingPermission

      yield { id: "event-idle", created, type: "session.idle", data: { sessionID: "session-1" } }
      resolveEventsHandled()
    }

    const context = {
      event: { subscribe: () => events() },
      session: { get: async () => ({ title: "Test session" }) },
      permission: {
        list: async ({ sessionID }: { sessionID: string }) => {
          permissionChecks.push(sessionID)

          return [...pendingPermissions].map((id) => ({ id }))
        },
      },
    } as unknown as Parameters<typeof plugin.setup>[0]

    const cleanup = await plugin.setup(context)
    await eventsHandled
    cleanup?.()

    expect(requests).toHaveLength(3)
    expect(requests[0]?.headers.get("Title")).toBe("OpenCode has a question: Test session")
    expect(requests[0]?.body).toContain("Which files should I change?")
    expect(requests[1]?.headers.get("Title")).toBe("OpenCode needs approval: Test session")
    expect(requests[1]?.body).toBe("Allow this edit?")
    expect(requests[2]?.headers.get("Title")).toBe("OpenCode: Test session")
    expect(requests[2]?.body).toContain("Session complete")
    expect(permissionChecks).toHaveLength(2)
  })
})
