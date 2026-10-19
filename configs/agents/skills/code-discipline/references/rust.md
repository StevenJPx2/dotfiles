# Rust Discipline

Apply these rules when creating, changing, reviewing, or debugging Rust.

## Model First

Start a feature with the model, not with functions: write the structs and enums that describe the domain, compile, and iterate. Compile error? Improve the code. Compiles? Improve the model. Break work into atomic, compilable chunks and never stay red for long.

- Make invalid states unrepresentable. Two interacting booleans (`alive`, `hungry`) are a product type that admits a hungry corpse; `enum Cat { Alive { hungry: bool }, Dead }` cannot express it.
- Model lifecycles as state machines: an enum of states, an enum of transitions, one exhaustive `match (state, transition)` that owns every rule.
- Need more nuance? Do not add an `if`; add detail to the model and let exhaustive `match` find every site that must change.
- Normalize data as you would tables: split repeating groups into their own structs, link by key, keep each fact once. Reach for composition, not inheritance hierarchies.
- Wrap primitives in newtypes at the point they gain meaning (`struct Image(String)`), so a function that needs an image cannot be handed any string.
- Parse at the boundary with `?`, then work with fully typed values; never carry `Option`, `Result`, or `serde_json::Value` deeper than the edge that produced it.

## Design

- Borrow before cloning. Prefer a small justified clone over complicated lifetime machinery.
- Accept `&str` and `&[T]` when ownership is unnecessary.
- Use `Result` for expected failure and assertions for programmer invariants.
- Match locally owned enums exhaustively; wildcard arms must not hide new states.
- Begin internal APIs with the narrowest useful visibility.
- Prefer concrete types. Add traits at real consumer, polymorphic, or capability boundaries.
- Prefer functions and generics over macros; use a macro only when ordinary language constructs cannot express the job.
- Keep protocol crates limited to serializable contracts and invariants.
- Keep runtime code independent of concrete provider implementations; assemble providers at a composition root.

## Concurrency

Async is not the default; it is a tool for I/O-bound services. Keep domain logic synchronous and runtime-free so it can be reasoned about one function at a time and tested without an executor.

- Need parallelism in a synchronous program? Use `std::thread::scope` or `rayon`; scoped threads keep borrowing intact because every thread joins before the scope returns.
- Building a network service or daemon? `tokio` is fine. Confine it to the I/O edge and pass owned data into tasks; do not let `'static` propagate into domain code.
- Scope async tighter than "the whole program". A function that does not perform I/O should not be `async`.
- Never hold a synchronous or asynchronous lock across `.await`.
- Use bounded channels and explicit backpressure.
- Give every spawned task or thread an owner, cancellation path, and observable result.
- Put deadlines on external operations and limits on retries.
- Use `spawn_blocking` (or a dedicated thread) for blocking or CPU-heavy work inside async systems.

## Errors and Observability

- Preserve error sources and add operation context at boundaries.
- Use typed library errors; application entry points may aggregate errors.
- Keep error messages lowercase and without trailing punctuation when they are composed into larger messages.
- Log structured fields, redact secrets, preserve the error chain, and log each failure once.
- Never `unwrap`. `unwrap` and `expect` are syntactic TODOs: fine while prototyping, never committed to production paths. Replace them with `?`, `unwrap_or_default`, `map_or`, `ok_or`, and the other `Result`/`Option` combinators; a pipeline of `map`/`and_then`/`map_err` is both safer and clearer than branching on `is_ok()`.
- Implicit panics count: indexing (`v[i]`), string slicing, unchecked arithmetic, and `as` casts are denied by the lint set below. Use `get`, `checked_*`/`saturating_*`, and `TryFrom`.
- Tests may `unwrap`, `expect`, `panic`, and index; the `clippy.toml` below allows it there and nowhere else.

## Default Crates

These are pre-approved: reach for them without a dependency discussion. Anything outside this list still needs the justification in the skill's Hard Guards. Prefer boring, widely used crates over clever ones; check that the pick is still maintained before pinning.

| Need | Default | Note |
|---|---|---|
| Async runtime | `tokio` | Services only; see Concurrency. Libraries stay runtime-agnostic where practical |
| Serialization | `serde`, `serde_json` | Derive on wire types; keep `serde_json::Value` at the edge |
| Library errors | `thiserror` | Typed enums callers can match on |
| Binary errors | `color-eyre` (or `anyhow`) | Aggregate at `main`; install the report handler once |
| Logging | `tracing`, `tracing-subscriber` | Structured fields, spans, never `println!` for diagnostics |
| CLI | `clap` (derive) | Types are the argument spec |
| HTTP client | `reqwest` | Async by default; set timeouts explicitly |
| SQL | `sqlx` | Compile-checked queries; commit the offline schema so CI needs no database |
| Data parallelism | `rayon` | `par_iter` for CPU-bound collections; not a substitute for async I/O |
| Time | `jiff` | Timezone-aware, hard to misuse; `chrono` only when a dependency forces it |
| Property tests | `proptest` | Invariants over generated inputs |
| Iterators | `itertools` | Adaptors the std iterator lacks; keep pipelines declarative |
| Fuzzing | `cargo-fuzz` | Parsers and protocol surfaces |
| Benchmarks | `criterion` | Statistics-driven; numbers, not vibes |
| Test runner | `cargo-nextest` | Parallel, retries, slow-test detection; run `cargo test --doc` separately for doctests |
| Dev loop | `bacon`, `watchexec` | Rerun clippy/test/run on save; fix the first error in compiler output, not the first in the file |
| Supply chain | `cargo-deny`, `cargo-audit`, `cargo-shear` | Licenses, bans, advisories, unused dependencies |

GUI and web frontends (`leptos`, `dioxus`, `egui`, `tauri`) are out of scope for this list; decide per project.

## Toolchain

Develop on nightly, pinned by date so every machine and CI compile with the same rustc and clippy:

```toml
# rust-toolchain.toml
[toolchain]
channel = "nightly-2026-05-20"
components = ["rustfmt", "clippy", "rust-analyzer", "rust-src"]
```

- Bump the date deliberately, in its own commit, like any dependency; that commit owns any new lint findings.
- Published crates must also build on stable at the declared `rust-version`; CI runs the gate on the pinned nightly and `cargo check --locked` on that stable MSRV. No nightly-only features in a crate others depend on.
- If a nightly is broken, move the pin to the previous good date rather than switching channels.

## Lints

Use workspace lint inheritance so every crate gets the same set. Deny compiler warnings and give Clippy teeth; the goal is a program with no execution path that can panic at runtime. Allow a false positive only at the narrowest scope with `reason = "..."`.

```toml
[workspace.lints.rust]
unsafe_code = "forbid"

[workspace.lints.clippy]
all = { level = "deny", priority = -1 }
pedantic = { level = "deny", priority = -1 }
nursery = { level = "deny", priority = -1 }   # a false positive gets a scoped allow with a reason, not a group downgrade
# Deny explicit panics
unwrap_used = "deny"
expect_used = "deny"
panic = "deny"
panic_in_result_fn = "deny"
unreachable = "deny"
unimplemented = "deny"
todo = "deny"
exit = "deny"
dbg_macro = "deny"
# Deny implicit panics
indexing_slicing = "deny"
string_slice = "deny"
arithmetic_side_effects = "deny"
unchecked_time_subtraction = "deny"
as_conversions = "deny"
# Size
too_many_lines = "deny"
```

Never enable all of `clippy::restriction`; its lints contradict each other. Cherry-pick as above.

`clippy.toml` at the workspace root (`too_many_lines` counts only lines containing code, so blank and comment-only lines are free):

```toml
too-many-lines-threshold = 70
allow-unwrap-in-tests = true
allow-expect-in-tests = true
allow-panic-in-tests = true
allow-indexing-slicing-in-tests = true
```

For code that must be proven panic-free (allocators, signal handlers, hot loops), `no-panic` fails the link if any path can reach the panic handler; it is strict and can false-positive, so apply it per function.

Forbid unsafe code by default. If a project explicitly permits unsafe code, every unsafe operation needs a local `SAFETY` argument, unsafe APIs need a `# Safety` contract, and Miri or an equivalent targeted check must exercise it.

## Tests

Climb only as far as the risk requires: Clippy → assertions → doctests → examples → black-box tests → white-box tests → property tests → fuzzing. The compiler already proves exhaustiveness, thread safety, and the model, so spend runtime tests on behavior the type system cannot encode.

- Prefer doctests for the lightest-touch proof; they keep public API documentation honest and executable.
- Put focused unit tests beside private logic (`#[cfg(test)] mod tests`) and public integration tests under `tests/`.
- A bug fix begins with a test that fails on the original behavior.
- Test invalid transitions and malformed input, not only happy paths.
- Use property tests (`proptest`) when an invariant should hold for all inputs of a type.
- Use contract tests and test doubles at real boundaries (wire formats, processes, filesystems, sockets, providers); do not burn the house down to test the smoke alarm.
- Fuzz parsers and hostile protocol surfaces; retain discovered failures as regression inputs.
- Use concurrency testing or sanitizers when ordinary tests cannot establish the invariant.

## Gate

Prefer the repository's single check command. If none exists, the baseline gate is:

```sh
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --all-features --locked -- -D warnings
cargo nextest run --workspace --all-targets --all-features --locked
cargo test --workspace --doc --all-features --locked
RUSTDOCFLAGS="-D warnings" cargo doc --workspace --all-features --no-deps --locked
cargo deny check
```

CI runs this on the pinned nightly plus a stable MSRV check job. Run advisory checks periodically because the advisory database changes independently of source code. Add API compatibility checks when the project promises a stable public API.
