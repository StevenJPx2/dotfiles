// Entry point for the Qwen-MM-Plugins OpenCode integration.
// MUST export only the plugin function: opencode's legacy loader iterates
// every export of this module and drops the plugin on any non-function.
export { default } from "./qwen-mm-plugins/config.ts"
