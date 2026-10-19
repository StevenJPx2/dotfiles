---
name: code-discipline
description: Enforces Simple, Explicit, Bounded, Vertical, and Proof-driven development. MUST be used whenever writing, modifying, refactoring, reviewing, or debugging Rust, Go, TypeScript, JavaScript, or project architecture; includes language-specific lint, testing, Effect, anti-slop, Fallow, and line-limit rules.
---

# Code Discipline

Build code that is simple, explicit, bounded, vertical, and proven.

## Doctrine

- **Simple:** Make the code's structure mirror the problem.
- **Explicit:** Show state, effects, errors, ownership, dependencies, and lifecycle in APIs and types.
- **Bounded:** Put limits and termination conditions on resources, concurrency, queues, retries, and background work.
- **Vertical:** Deliver the smallest complete behavior through its real boundary. Do not scaffold horizontal layers for hypothetical work.
- **Proof:** Finish with executed evidence that would fail if the behavior broke.

Simple does not mean easy or trivial. Preserve complexity required by the domain; reject complication introduced by the implementation. An abstraction is justified only when it removes concepts from the caller's mental model.

## Load the Active Language Rules

Before changing or reviewing code, read every applicable reference:

- Rust: [references/rust.md](references/rust.md)
- Go: [references/go.md](references/go.md)
- TypeScript or JavaScript: [references/typescript.md](references/typescript.md)

For mixed-language boundaries, read both sides. Repository instructions and configuration remain authoritative for project-specific commands and stricter rules.

## Work

### 1. Understand

Read the affected flow, its callers, tests, and boundary contracts before editing. Identify trusted and untrusted inputs, state transitions, side effects, ownership, termination, and current invariants.

For a bug, reproduce the reported behavior and find the shared cause. Fixing only one caller is incomplete when sibling callers remain exposed.

**Complete when:** every affected path and boundary is accounted for.

### 2. Baseline

Run the smallest existing check that covers the area before a non-trivial change. Record pre-existing failures instead of silently inheriting or suppressing them.

**Complete when:** the starting state is known well enough to distinguish regressions.

### 3. Design

Use this order:

1. Remove the need.
2. Reuse a project primitive.
3. Use the standard library or native platform.
4. Use an installed dependency.
5. Add the minimum new code.

Model first: express the domain's states and transitions in types before writing functions, so invalid states are unrepresentable and the compiler finds every site a model change touches. When behavior needs more nuance, add detail to the model rather than another `if`. Prefer concrete types and direct control flow. Add an abstraction for a present domain or capability boundary, not anticipated reuse. Validate external data once at the boundary, then use precise internal types.

**Complete when:** every new abstraction, dependency, state, and branch corresponds to a current requirement.

### 4. Implement

Keep functions and methods at or below 70 non-blank, non-comment lines. Split by responsibility or invariant. Keep coordinating control flow visible in the parent; never create numbered fragments or meaningless wrappers to satisfy the count.

Handle expected failure explicitly. Use assertions for programmer invariants. Bound every queue, retry, loop, task, and resource lifetime. Keep changes focused; separate behavior changes from unrelated mechanical refactors.

Add the smallest test that proves non-trivial behavior. A bug fix starts with a failing regression check. External processes, protocols, tools, storage, and networks require a real contract test when mocks cannot prove the boundary.

**Complete when:** the behavior and its failure modes are represented in code and executable checks.

### 5. Prove

Run repository formatting, linting, compile or type checks, tests, and health analysis. Warnings fail. Review the final diff for accidental scope, dead compatibility paths, weakened types, and unexplained suppressions.

Exercise user-visible or external behavior through its real runtime. A mock, screenshot, static reading, or expected result is not substitute evidence for a live boundary.

**Complete when:** every required gate passes and the reported symptom or behavior succeeds end to end.

## Hard Guards

- Explain and obtain approval before adding a production dependency.
- Keep suppressions narrow and attach a concrete reason.
- Preserve or raise test and health floors.
- Keep one authoritative representation of each fact.
- Comments explain reasons, invariants, and constraints; code expresses mechanics.
- Update the authoritative architecture or contract document in the same change when its truth changes.
- Remove obsolete APIs and update callers unless compatibility is explicitly required.
- Treat generated code and fixtures as exceptions only where the repository identifies them as such.

Do not weaken a gate to make a change pass. A failing required check means the work remains incomplete; report the command, failure, and blocker precisely.
