// Restore catalog context limits for OpenAI models when signed in with ChatGPT.
//
// The built-in ChatGPT OAuth integration clamps every OpenAI model to
// context 400k / input 272k. This model transform runs after it and puts back
// the source (models.dev) limits, e.g. 1.05M / 922k for gpt-6-sol.
//
// Experimental: the ChatGPT/Codex backend may still reject prompts above 272k.
// If that happens, delete this file to return to the clamped limits.
import { Plugin } from "@opencode/plugin"

const PROVIDER_ID = "openai"
const CLAMPED_INPUT = 272_000

export default Plugin.define({
  id: "openai-context-limit",
  async setup(ctx) {
    await ctx.model.transform((editor) => {
      const source = editor.provider.get(PROVIDER_ID)
      if (!source) return

      for (const model of editor.list(PROVIDER_ID)) {
        if (model.limit.input !== CLAMPED_INPUT) continue

        const modelID = String(model.id)
        const limit = source.models.get(modelID)?.limit
        if (!limit || limit.context <= model.limit.context) continue

        editor.update(PROVIDER_ID, modelID, (draft) => {
          draft.limit = { ...draft.limit, context: limit.context, input: limit.input }
        })
      }
    })
  },
})
