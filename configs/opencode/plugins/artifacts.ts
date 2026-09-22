import { Plugin } from "@opencode/plugin"
import { publishTool } from "./artifacts/tools/publish.ts"
import { editTool } from "./artifacts/tools/edit.ts"
import { deleteTool } from "./artifacts/tools/delete.ts"

export default Plugin.define({
  id: "artifacts",
  setup(ctx) {
    ctx.tool.transform((editor) => {
      editor.add(publishTool)
      editor.add(editTool)
      editor.add(deleteTool)
    })
  },
})
