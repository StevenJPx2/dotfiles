# TypeScript Discipline

Apply these rules when creating, changing, reviewing, or debugging TypeScript or JavaScript.

## Types

Enable TypeScript strictness and, unless the runtime proves an incompatibility:

```json
{
  "strict": true,
  "noUncheckedIndexedAccess": true,
  "exactOptionalPropertyTypes": true,
  "noImplicitOverride": true,
  "noFallthroughCasesInSwitch": true
}
```

- Decode external input at the boundary, then use precise internal types.
- Avoid `any`, broad dictionaries, interacting booleans, and stringly typed states.
- Use tagged unions and exhaustive handling for mutually exclusive states.
- Do not fabricate evidence with chained assertions or widening followed by narrowing assertions.
- A necessary type assertion has the narrowest scope and a safety comment explaining the external fact that proves it.

## Effect

Use Effect for fallible operations, async work, I/O, configuration, logging, time, randomness, resources, retries, concurrency, and services. Keep pure, total transformations as ordinary functions.

- Decode trust-boundary data with Effect Schema.
- Represent expected failures as typed tagged errors; reserve defects for programmer errors.
- Model real external dependencies as services.
- Assemble implementations with Layers at composition roots.
- Acquire and release resources through Scope.
- Model retries with Schedule and give fibers explicit ownership and interruption.
- Execute effects only at application entry points.
- Keep raw promises and platform APIs inside narrow adapters.
- Do not wrap pure helpers in Effects, services, or Layers.
- Follow the installed Effect major's official documentation; never mix v3 and v4 APIs.

Enable Effect Language Service diagnostics in the editor and CI. Promote correctness diagnostics to errors and enable checks for floating Effects, missing error or context channels, raw async functions and Promises, platform fetch/timers/environment/time/random/logging, unsafe Effect assertions, nested execution, try/catch in generators, global `Error` channels, leaked requirements, and Layer provision outside composition roots.

The package depends on the TypeScript major. TypeScript 7 (the native compiler) uses `@effect/tsgo`; earlier majors use `@effect/language-service`. Both read the plugin entry named `@effect/language-service` in `tsconfig.json`; set severities in its `diagnosticSeverity` map:

```jsonc
"plugins": [{ "name": "@effect/language-service", "diagnosticSeverity": {
  "floatingEffect": "error", "floatingEffectInVitest": "error", "missingEffectError": "error",
  "missingEffectContext": "error", "missingLayerContext": "error", "asyncFunction": "error",
  "newPromise": "error", "globalFetch": "error", "globalTimers": "error", "processEnv": "error",
  "globalDate": "error", "globalRandom": "error", "globalConsole": "error",
  "unsafeEffectTypeAssertion": "error", "runEffectInsideEffect": "error",
  "tryCatchInEffectGen": "error", "globalErrorInEffectFailure": "error",
  "leakingRequirements": "error", "strictEffectProvide": "error"
  // plus each rule's `…InEffect` variant and the remaining correctness rules
}}]
```

Run the standalone diagnostics command in CI. It needs no patched compiler; prefer it to setup flows that patch packages in `node_modules`:

```sh
effect-tsgo diagnostics --project tsconfig.json --strict            # TypeScript 7
effect-language-service diagnostics --project tsconfig.json         # earlier majors
```

Narrow platform exceptions for adapter files with the plugin's `overrides` entries, never by lowering a rule globally.

## Oxlint Anti-Slop

Vendor and review `dmmulroy/anti-slop`; it is project policy rather than an opaque npm dependency. Keep Oxlint and `@oxlint/plugins` on the same exact version; Vite+ pins both.

Enable the five Effect rules:

- `no-manual-effect-error-tag`
- `no-manual-tag-comparison`
- `no-manual-tagged-construction`
- `no-service-constructor-imports`
- `prefer-effect-match`

Enable generic evidence and architecture rules for chained assertions, widen-then-assert flows, assertion safety comments, unsafe dictionaries, known-value widening, module mocking, reflection, conditional omission semantics, accumulating spread, reducer accumulator copies, and readable spacing.

Start strict with the remaining vendored rules. Change boundary exceptions in the vendored implementation when Effect Schema supplies equivalent evidence. Keep every disabled rule or local suppression narrow and reasoned.

Configure Oxlint's `max-lines-per-function` with `max: 70`, `skipBlankLines: true`, and `skipComments: true`. Generated code and fixture data may be excluded explicitly. Deny warnings (`options.denyWarnings: true` or `--deny-warnings`).

Vendoring:

- Copy upstream `src/` and its licence. Beside it, keep an `UPSTREAM.md` with the source commit and a table of every local change and its reason, so a later update can merge upstream fixes.
- Run the vendored rule tests in the project's test runner. Oxlint's `RuleTester` reports through assignable hooks; bind them once in a setup file rather than editing each test:

  ```ts
  RuleTester.describe = describe;
  RuleTester.it = it;
  ```

- Exclude vendored code from the formatter and from Fallow analysis, so it keeps upstream formatting and is not counted as project code. Keep it type-checked under the project's strictness. Fix strictness gaps locally and record them in `UPSTREAM.md`; never weaken compiler options for its directory.

## Toolchain: Vite+

Prefer Vite+ (`vp`) when its pinned Oxlint, oxfmt, and Vitest match the policy. It provides `vp check` (oxfmt, Oxlint, and type checks through tsgolint), `vp test`, and cached `vp run` tasks configured in `vite.config.ts`. Read the current Vite+ migration guide and rules before migrating.

- Run `vp migrate --no-interactive` from the workspace root with `--no-hooks --no-agent --no-editor` unless the user asked for those setups.
- Add vendored paths to `fmt.ignorePatterns` before migrating. Migration formats every file it rewrites, so an unprotected vendored directory is reformatted wholesale.
- Migration may not merge standalone `oxlint.config.ts`, `oxfmt.config.ts`, or `vitest.config.ts`. Move their settings into the `lint`, `fmt`, and `test` blocks by hand, then delete them.
- Migration rewrites vendored plugin imports to `vite-plus/lint/plugins`, `vite-plus/lint/plugins-dev`, and `vite-plus/test`. Check that the vendored diff contains only import lines, and record the rewrite in `UPSTREAM.md`.
- Enable `lint.options.typeAware` and `typeCheck`. Oxlint marks `typeCheck` experimental.
- `vp check` type-checks only the files it lints. Paths in `lint.ignorePatterns` are not type-checked, so keep a full `tsc -b --force` task when any are ignored.
- Vite Task's automatic file tracking can miss new files for Go-based tools such as `tsc` 7 and `effect-tsgo`, replaying a stale pass. Give such tasks explicit `cache.input` globs. Set `cache: false` for tasks whose result depends on Git state or the network, such as `fallow audit` and dependency audits.
- `tsc -b`'s up-to-date check compares modification times and skips a new file with an older mtime. Gates run `tsc -b --force` and leave skipping to the task cache.
- Fallow does not read `vite.config.ts` tasks. Declare tools invoked only there in `ignoreDependencies` with a reason.
- In CI, pin `voidzero-dev/setup-vp` to an exact release; the `v1` tag is frozen. Its path inputs, such as `node-version-file`, resolve relative to `working-directory`.

## Fallow

Fallow supplements rather than replaces the compiler and Oxlint.

- Run `fallow audit` on every pull request.
- Run full dead-code, cycle, duplication, and health analysis on the main branch.
- Use type-aware evidence before deleting exports or changing public architecture.
- Configure boundary rules when package layers exist.
- Ratchet health and coverage floors.
- Attach concrete reasons to suppressions.
- Preserve machine-readable findings as the authoritative CI artifact.

## Tests

- A bug fix begins with a failing regression test.
- Test pure logic directly and Effect services through test Layers.
- Do not use module mocking; expose a real dependency seam.
- Use contract tests for processes, protocols, storage, tools, and external providers.
- Use live end-to-end verification for behavior that only exists in a real runtime.
- Treat coverage as a ratcheted signal, not a substitute for behavioral assertions.

## Gate

Use the package manager selected by the repository lockfile and prefer its single check script. A complete gate covers:

1. Formatting
2. Oxlint with zero warnings
3. TypeScript compilation or type checking
4. Effect diagnostics
5. Vitest or the repository test runner
6. Fallow audit or full analysis as appropriate
7. Dependency and security checks

Frozen dependency installation and pinned tool versions are part of the gate. A compiler, Oxlint, Effect, or Fallow suppression is a policy change, not an implementation shortcut.

Prove a new or changed gate before trusting it. For each gate, add a deliberate violation and confirm a non-zero exit: an unformatted file, an explicit `any`, a type error (including one inside every excluded path), a failing test, an unused file, and a floating Effect. For cached tasks, also confirm that adding a new failing file, with an older modification time, invalidates the cache. A gate that passes without this evidence may be checking nothing.
