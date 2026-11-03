import { describe, expect, test } from "bun:test"
import type { ToolEditor } from "@opencode/plugin/promise/tool"
import plugin, { moveDirectToolsToCodeMode } from "../codemode-only"

type Entry = { id: string; options?: { codemode?: boolean; namespace?: string; permission?: string; pinned?: boolean } }

function editorFor(entries: Entry[]): Pick<ToolEditor, "list" | "update"> {
  return {
    list: () => entries as ReturnType<ToolEditor["list"]>,
    update: (id, update) => {
      const entry = entries.find((item) => item.id === id)
      if (entry) update(entry as Parameters<Parameters<ToolEditor["update"]>[1]>[0])
    },
  }
}

describe("codemode-only", () => {
  test("moves direct tools without changing their namespace or permission", () => {
    const tools: Entry[] = [
      { id: "read", options: { codemode: false, permission: "read" } },
      { id: "extension_action", options: { codemode: false, namespace: "extension", permission: "extension_action" } },
      { id: "already_in_code_mode", options: { namespace: "extension" } },
      { id: "question", options: { codemode: false, permission: "question" } },
    ]
    moveDirectToolsToCodeMode(editorFor(tools))
    expect(tools).toEqual([
      { id: "read", options: { codemode: true, permission: "read" } },
      { id: "extension_action", options: { codemode: true, namespace: "extension", permission: "extension_action" } },
      { id: "already_in_code_mode", options: { namespace: "extension" } },
      { id: "question", options: { codemode: false, permission: "question" } },
    ])
  })

  test("makes question direct even when it was registered in Code Mode", () => {
    const tools: Entry[] = [
      { id: "question", options: { codemode: true, permission: "question", pinned: true } },
      { id: "extension_question", options: { codemode: false, namespace: "extension" } },
    ]
    moveDirectToolsToCodeMode(editorFor(tools))
    expect(tools).toEqual([
      { id: "question", options: { codemode: false, permission: "question" } },
      { id: "extension_question", options: { codemode: true, namespace: "extension" } },
    ])
  })

  test("registers a replayable transform for new registry contents", async () => {
    let transform: typeof moveDirectToolsToCodeMode | undefined
    await plugin.setup({ tool: { transform: async (fn: typeof moveDirectToolsToCodeMode) => { transform = fn } } } as Parameters<typeof plugin.setup>[0])
    expect(transform).toBeDefined()
    const tools: Entry[] = [{ id: "shell", options: { codemode: false } }]
    transform!(editorFor(tools))
    tools.push({ id: "late_tool", options: { codemode: false } })
    transform!(editorFor(tools))
    expect(tools.every((tool) => tool.options?.codemode === true)).toBe(true)
  })
})
