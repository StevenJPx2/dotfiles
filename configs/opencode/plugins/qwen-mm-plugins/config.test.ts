import { afterAll, beforeAll, describe, expect, test } from "bun:test"
import {
  QWEN_MM_CAPABILITIES,
  applyQwenMcpConfig,
  createQwenMcpConfig,
  selectCapabilities,
  type QwenMmCapability,
} from "./config"

const UPSTREAM = "qwen-mm-plugins[%s] @ git+https://github.com/QwenLM/Qwen-MM-Plugins.git@main"

function expectedConfig(capability: QwenMmCapability, environment?: Record<string, string>) {
  return {
    type: "local",
    command: ["uvx", "--from", UPSTREAM.replace("%s", capability), `qwen-mm-plugins-${capability}`],
    ...(environment ? { environment } : {}),
    enabled: true,
    timeout: 600_000,
  }
}

const credentialEnv = { DASHSCOPE_API_KEY: "{env:DASHSCOPE_API_KEY}" }
const searchEnv = { SERPER_API_KEY: "{env:SERPER_API_KEY}" }
const autolaunchEnv = { QWEN_MM_AUTOLAUNCH: "1" }

const originalDashscopeKey = process.env.DASHSCOPE_API_KEY
const originalSerperKey = process.env.SERPER_API_KEY

beforeAll(() => {
  process.env.DASHSCOPE_API_KEY = "test-dashscope-key"
  process.env.SERPER_API_KEY = "test-serper-key"
})

afterAll(() => {
  if (originalDashscopeKey === undefined) delete process.env.DASHSCOPE_API_KEY
  else process.env.DASHSCOPE_API_KEY = originalDashscopeKey
  if (originalSerperKey === undefined) delete process.env.SERPER_API_KEY
  else process.env.SERPER_API_KEY = originalSerperKey
})

describe("Qwen-MM-Plugins configuration", () => {
  test("uses core by default and supports all capabilities", () => {
    expect(selectCapabilities(undefined)).toEqual(["core"])
    expect(selectCapabilities("all")).toEqual([...QWEN_MM_CAPABILITIES])
    expect(selectCapabilities("core, api, core")).toEqual(["core", "api"])
    expect(() => selectCapabilities("bogus")).toThrow(/Unknown QWEN_MM_CAPABILITIES/)
  })

  test("builds the exact upstream uvx command and manifest parity for every capability", () => {
    expect(createQwenMcpConfig("core")).toEqual(expectedConfig("core"))
    expect(createQwenMcpConfig("api")).toEqual(expectedConfig("api", credentialEnv))
    expect(createQwenMcpConfig("search")).toEqual(expectedConfig("search", searchEnv))
    expect(createQwenMcpConfig("video-memory")).toEqual(expectedConfig("video-memory", credentialEnv))
    expect(createQwenMcpConfig("video-edit")).toEqual(expectedConfig("video-edit", credentialEnv))
    expect(createQwenMcpConfig("blender")).toEqual(expectedConfig("blender", autolaunchEnv))
    expect(createQwenMcpConfig("freecad")).toEqual(expectedConfig("freecad", autolaunchEnv))
  })

  test("omits API key injection when the key is not in the environment", () => {
    delete process.env.DASHSCOPE_API_KEY
    delete process.env.SERPER_API_KEY
    try {
      expect(createQwenMcpConfig("api")).toEqual(expectedConfig("api"))
      expect(createQwenMcpConfig("search")).toEqual(expectedConfig("search"))
      expect(createQwenMcpConfig("blender")).toEqual(expectedConfig("blender", autolaunchEnv))
    } finally {
      process.env.DASHSCOPE_API_KEY = "test-dashscope-key"
      process.env.SERPER_API_KEY = "test-serper-key"
    }
  })

  test("does not replace an explicit MCP configuration", () => {
    const custom = { type: "local" as const, command: ["custom-server"], enabled: false }
    const config = { mcp: { "qwen-mm-plugins-core": custom } } as Parameters<typeof applyQwenMcpConfig>[0]

    applyQwenMcpConfig(config, ["core", "search"])

    expect(config.mcp["qwen-mm-plugins-core"]).toBe(custom)
    expect(config.mcp["qwen-mm-plugins-search"]).toEqual(expectedConfig("search", searchEnv))
  })
})

describe("plugin entry", () => {
  test("exports only functions so the opencode loader accepts it", async () => {
    const mod = await import("../qwen-mm-plugins.ts")
    const values = Object.values(mod)
    expect(values.length).toBeGreaterThan(0)
    for (const value of values) {
      expect(typeof value).toBe("function")
    }
  })
})
