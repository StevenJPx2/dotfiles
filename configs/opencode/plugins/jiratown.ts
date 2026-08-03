// Top-level entry so opencode auto-loads jiratown. opencode only auto-loads *.ts files
// directly in .opencode/plugins/ — NOT subdirectory index.ts files — so this thin
// re-export makes the multi-file plugin under ./jiratown/ discoverable.
export { Jiratown } from "./jiratown/index.ts"
