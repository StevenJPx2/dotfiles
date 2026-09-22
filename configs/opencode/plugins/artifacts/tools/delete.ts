import { deleteRecord, isValidId } from "../host.ts"

export const deleteTool = {
  name: "artifact_delete",
  description: "Delete an existing artifact immediately.",
  input: {
    type: "object",
    properties: { id: { type: "string" } },
    required: ["id"],
    additionalProperties: false,
  },
  async execute(raw: unknown) {
    const { id } = raw as { id: string }
    if (!isValidId(id)) throw new Error("invalid artifact id")
    return { content: JSON.stringify({ id, deleted: deleteRecord(id) }) }
  },
} as const
