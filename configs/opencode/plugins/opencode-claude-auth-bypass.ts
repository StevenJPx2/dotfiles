import type { Plugin } from "@opencode-ai/plugin";

export const MyPlugin: Plugin = async ({
  project,
  client,
  $,
  directory,
  worktree,
}) => {
  return {
    "experimental.chat.system.transform": async (input, output) => {
      if (input.model.providerID !== "anthropic") return;
      const opencodePromptPart = output.system.findIndex((x) =>
        x?.includes("https://github.com/anomalyco/opencode"),
      );
      // Remove the OpenCode system prompt part if present
      if (opencodePromptPart !== -1) {
        output.system.splice(opencodePromptPart, 1);
      }
    },
  };
};
