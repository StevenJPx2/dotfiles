import { Plugin } from "@opencode/plugin"
import type { ToolEditor } from "@opencode/plugin/promise/tool"

// Keep interactive questions on the native tool list; route other tools through
// Code Mode without changing their executors, namespaces, or permissions.
// OpenCode replays this transform on registry reloads.
export function moveDirectToolsToCodeMode(editor: Pick<ToolEditor, "list" | "update">): void {
  for (const tool of editor.list()) {
    if (tool.id === "question") {
      if (tool.options?.codemode !== false) {
        editor.update(tool.id, (draft) => {
          const { pinned, ...options } = draft.options ?? {}
          draft.options = { ...options, codemode: false }
        })
      }
      continue
    }
    if (tool.options?.codemode !== false) continue
    editor.update(tool.id, (draft) => {
      draft.options = { ...draft.options, codemode: true }
    })
  }
}

export default Plugin.define({
  id: "codemode-only",
  async setup(ctx) {
    await ctx.tool.transform(moveDirectToolsToCodeMode)
  },
})
