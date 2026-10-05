// OptMem (https://github.com/VictorTaelin/OptMem): permanent memory for agents.
//
// Replaces the "## Memory" block upstream asks you to paste into AGENTS.md:
//   - the instructions are injected into every top-level session's system prompt
//   - `memo` runs through native memo_* tools (argv, no shell quoting to break)
//   - subagent sessions get neither the prompt nor the tools, since upstream's
//     rule is that a subagent must never run memo
//
// Needs the tool itself (python3, one file):
//   curl -fsSL https://raw.githubusercontent.com/VictorTaelin/OptMem/main/install.sh | sh
// Without it the plugin stays silent. Options: { memo?: string, memoryDir?: string },
// defaulting to ~/.optmem/memo and $MEMORY_DIR or ~/.optmem/memory.
import { Plugin } from "@opencode/plugin"
import { execFile } from "node:child_process"
import { existsSync } from "node:fs"
import { homedir } from "node:os"
import { join } from "node:path"

const INSTALL = "curl -fsSL https://raw.githubusercontent.com/VictorTaelin/OptMem/main/install.sh | sh"
const TOOL_NAMES = ["memo_wake", "memo_note", "memo_nap", "memo_recall", "memo_zoom", "memo_forget"]
const BLOCK = {
  type: "string",
  pattern: "^\\d+-\\d+$",
  description: "A block id exactly as memo prints it, e.g. 16-31",
} as const

function expand(path: string): string {
  return path === "~" || path.startsWith("~/") ? join(homedir(), path.slice(1)) : path
}

function pretty(path: string): string {
  const home = homedir()
  return path.startsWith(home + "/") ? "~" + path.slice(home.length) : path
}

function instructions(memo: string, data: string): string {
  return `## Memory

Your memory is OptMem:
- The tools are memo_wake, memo_note, memo_nap, memo_recall, memo_zoom and memo_forget
- Your memories are in \`${data}\`

OptMem outlives every session, compaction, model and vendor change.
Without it you do not know who you are, or what was decided and tried.

### At startup: activating OptMem (mandatory)

Call memo_wake before any other tool call, in every session, and
then do exactly what it prints, to the end of its output.

Its output names shell commands such as \`${memo} nap 0-1 "<your line>"\` or
\`${memo} wake 2 296\`. Run each one through the matching tool instead of the
shell: memo_nap { block: "0-1", summary: "<your line>" }, memo_wake { part: 2, snapshot: 296 }.

### While working: register memories (mandatory)

Call memo_note with one line of at most 280 bytes whenever you learn
something new, or something worth keeping happens. That covers a task
worth real effort, a fact or insight the user teaches you, anything you
learn about their life (even indirectly), any event of lasting effect.

Do not register redundant memories.

If memo_note asks a compression: do it with memo_nap before your next action.

Never edit or delete anything under \`${data}\`: the tools manage it.

### When you need an old memory: search, or navigate

memo_recall searches every memory, word for word (case-insensitive regex).

Your memories also form a binary tree: #0-1, #2-3 ... exist as one-line
summaries, pairs of those as #0-3, and so on -- every \`#a-b\` line wake
prints is one node of it. memo_zoom opens a node into its two halves,
down to the raw memories.`
}

export default Plugin.define({
  id: "optmem",
  async setup(ctx) {
    const memo = expand(typeof ctx.options.memo === "string" ? ctx.options.memo : "~/.optmem/memo")
    const memoryDir = typeof ctx.options.memoryDir === "string" ? expand(ctx.options.memoryDir) : undefined
    const data = memoryDir ?? expand(process.env.MEMORY_DIR || "~/.optmem/memory")
    const prompt = instructions(pretty(memo), pretty(data))
    const parents = new Map<string, Promise<boolean>>()

    function isSubagent(sessionID: string): Promise<boolean> {
      let known = parents.get(sessionID)
      if (!known) {
        known = ctx.session.get({ sessionID }).then(
          (session) => Boolean(session.parentID),
          () => {
            parents.delete(sessionID)
            return false
          },
        )
        parents.set(sessionID, known)
      }
      return known
    }

    async function run(args: string[], context: { sessionID: string; signal: AbortSignal }) {
      if (await isSubagent(context.sessionID)) {
        throw new Error("You are a subagent. Don't run memo: only the top-level session records memories.")
      }
      if (!existsSync(memo)) throw new Error(`OptMem is not installed at ${pretty(memo)}. Ask the user to run: ${INSTALL}`)

      const env = memoryDir ? { ...process.env, MEMORY_DIR: memoryDir } : process.env
      const text = await new Promise<string>((resolve, reject) => {
        execFile(memo, args, { env, signal: context.signal, timeout: 30_000, maxBuffer: 4 << 20 }, (error, stdout, stderr) => {
          const output = [stdout.trimEnd(), stderr.trimEnd()].filter(Boolean).join("\n")
          // wake exits 1 with instructions on stdout when a compression must come first: that is output, not failure.
          if (error && !stdout.trim()) reject(new Error(output || error.message))
          else resolve(output)
        })
      })
      return { content: text }
    }

    await ctx.tool.transform((editor) => {
      editor.add({
        name: "memo_wake",
        description:
          "Read your OptMem memory. Call first, before any other tool, in every session, then do exactly what it prints. " +
          "Long memories arrive in parts: pass the part and snapshot it names to continue.",
        input: {
          type: "object",
          properties: {
            part: { type: "integer", minimum: 1, description: "Part to read, as named by the previous part's footer" },
            snapshot: { type: "integer", minimum: 0, description: "The T value from that footer; requires part" },
          },
          additionalProperties: false,
        },
        options: { codemode: false },
        execute: async (input, context) => {
          const { part, snapshot } = input as { part?: number; snapshot?: number }
          if (snapshot !== undefined && part === undefined) throw new Error("snapshot requires part")
          const args = ["wake"]
          if (part !== undefined) args.push(String(part))
          if (snapshot !== undefined) args.push(String(snapshot))
          return run(args, context)
        },
      })
      editor.add({
        name: "memo_note",
        description:
          "Record one memory in OptMem: one line, at most 280 bytes. Use whenever you learn something new or something worth " +
          "keeping happens. If the result asks for a compression, do it with memo_nap before your next action.",
        input: {
          type: "object",
          properties: { text: { type: "string", minLength: 1, description: "The memory: one line, at most 280 bytes" } },
          required: ["text"],
          additionalProperties: false,
        },
        options: { codemode: false },
        execute: async (input, context) => run(["note", (input as { text: string }).text], context),
      })
      editor.add({
        name: "memo_nap",
        description:
          "Answer the OptMem compression that came due: pass the block and your one-line summary. " +
          "Call with no arguments to see the next pending compression.",
        input: {
          type: "object",
          properties: {
            block: BLOCK,
            summary: { type: "string", minLength: 1, description: "One line, at most 280 bytes. Keep what lasts; invent nothing." },
          },
          additionalProperties: false,
        },
        options: { codemode: false },
        execute: async (input, context) => {
          const { block, summary } = input as { block?: string; summary?: string }
          if ((block === undefined) !== (summary === undefined)) throw new Error("Pass both block and summary, or neither.")
          return run(block === undefined ? ["nap"] : ["nap", block, summary!], context)
        },
      })
      editor.add({
        name: "memo_recall",
        description: "Search every OptMem memory ever recorded, word for word, with a case-insensitive Python regex.",
        input: {
          type: "object",
          properties: { regex: { type: "string", minLength: 1 } },
          required: ["regex"],
          additionalProperties: false,
        },
        options: { codemode: false },
        execute: async (input, context) => run(["recall", (input as { regex: string }).regex], context),
      })
      editor.add({
        name: "memo_zoom",
        description: "Open one node of the OptMem memory tree (an #a-b line from wake) into its two halves.",
        input: {
          type: "object",
          properties: { block: BLOCK },
          required: ["block"],
          additionalProperties: false,
        },
        options: { codemode: false },
        execute: async (input, context) => run(["zoom", (input as { block: string }).block], context),
      })
      editor.add({
        name: "memo_forget",
        description:
          "Drop a bad OptMem summary and every summary built on it; the next memo_nap rebuilds them. Raw memories are never lost.",
        input: {
          type: "object",
          properties: { block: BLOCK },
          required: ["block"],
          additionalProperties: false,
        },
        options: { codemode: false },
        execute: async (input, context) => run(["forget", (input as { block: string }).block], context),
      })
    })

    await ctx.session.hook("context", async (event) => {
      if (!existsSync(memo) || (await isSubagent(event.sessionID))) {
        for (const name of TOOL_NAMES) delete event.tools[name]
        return
      }
      event.system.push({ type: "text", text: prompt })
    })
  },
})
