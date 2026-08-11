import type { Config, Plugin, PluginOptions } from "@opencode-ai/plugin"

export const QWEN_MM_CAPABILITIES = [
  "core",
  "api",
  "search",
  "video-memory",
  "video-edit",
  "blender",
  "freecad",
] as const

export type QwenMmCapability = (typeof QWEN_MM_CAPABILITIES)[number]

const UPSTREAM = "https://github.com/QwenLM/Qwen-MM-Plugins.git@main"
const STARTUP_TIMEOUT_MS = 600_000

type QwenMcpConfig = {
  type: "local"
  command: string[]
  environment?: Record<string, string>
  enabled: true
  timeout: number
}

function isCapability(value: string): value is QwenMmCapability {
  return (QWEN_MM_CAPABILITIES as readonly string[]).includes(value)
}

export function selectCapabilities(value = process.env.QWEN_MM_CAPABILITIES): QwenMmCapability[] {
  const requested = value?.trim()

  if (!requested) return ["core"]

  const names = requested.split(",").map((name) => name.trim()).filter(Boolean)
  if (names.includes("all")) return [...QWEN_MM_CAPABILITIES]

  const invalid = names.filter((name) => !isCapability(name))
  if (invalid.length > 0) {
    throw new Error(`Unknown QWEN_MM_CAPABILITIES value(s): ${invalid.join(", ")}`)
  }

  return [...new Set(names)] as QwenMmCapability[]
}

function configuredCapabilities(options?: PluginOptions): QwenMmCapability[] {
  const value = options?.capabilities

  if (typeof value === "string") return selectCapabilities(value)
  if (Array.isArray(value) && value.every((item) => typeof item === "string")) {
    return selectCapabilities(value.join(","))
  }

  return selectCapabilities()
}

function environmentFor(capability: QwenMmCapability): Record<string, string> | undefined {
  const environment: Record<string, string> = {}

  if (["api", "video-memory", "video-edit"].includes(capability)) {
    const key = process.env.DASHSCOPE_API_KEY
    if (key) environment.DASHSCOPE_API_KEY = "{env:DASHSCOPE_API_KEY}"
  }

  if (capability === "search") {
    const key = process.env.SERPER_API_KEY
    if (key) environment.SERPER_API_KEY = "{env:SERPER_API_KEY}"
  }

  if (["blender", "freecad"].includes(capability)) {
    environment.QWEN_MM_AUTOLAUNCH = "1"
  }

  return Object.keys(environment).length > 0 ? environment : undefined
}

export function createQwenMcpConfig(capability: QwenMmCapability): QwenMcpConfig {
  const environment = environmentFor(capability)

  return {
    type: "local",
    command: [
      "uvx",
      "--from",
      `qwen-mm-plugins[${capability}] @ git+${UPSTREAM}`,
      `qwen-mm-plugins-${capability}`,
    ],
    ...(environment ? { environment } : {}),
    enabled: true,
    // First use may build the isolated uvx environment.
    timeout: STARTUP_TIMEOUT_MS,
  }
}

export function applyQwenMcpConfig(config: Config, capabilities: QwenMmCapability[]): void {
  config.mcp ??= {}

  for (const capability of capabilities) {
    const name = `qwen-mm-plugins-${capability}`
    if (config.mcp[name]) continue
    config.mcp[name] = createQwenMcpConfig(capability)
  }
}

export const QwenMmPlugins: Plugin = async (_input, options) => ({
  config: async (config) => {
    applyQwenMcpConfig(config, configuredCapabilities(options))
  },
})

export default QwenMmPlugins
