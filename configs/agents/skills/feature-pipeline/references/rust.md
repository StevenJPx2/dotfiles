# Rust projects

What slice 0 sets up in a Rust project, and the Rust form of each stage's
checks. The toolchain pin, lint table, `clippy.toml` and approved crates are
in `code-discipline`'s `references/rust.md`; this adds the project's shape and
the pipeline's tooling.

## Slice 0: setup

Slice 0 is itself a slice. Its plan is approved and it ends with green CI, a
docs site and a release pipeline that has published one candidate.

```text
Cargo.toml             workspace: one version, lints, shared dependencies
rust-toolchain.toml    dated nightly, components, extra targets
clippy.toml            70-line functions, test allowances
deny.toml              licenses, sources, pinned git dependencies
bacon.toml             watch jobs
.cargo/mutants.toml    mutation testing
crates/
  core/                the domain model: no I/O, no dependencies
  protocol/            wire contracts and their validation
  runtime/             behavior, given its providers
  daemon/              the I/O edge: socket, files, audit log
  cli/                 clap and color-eyre; main assembles everything
adapters/<harness>/    a native plugin for each harness, in its language
distribution/          shipped data, installed to share/<name>/
scripts/               package, smoke, formula, bench, with their tests
docs/                  plans/, plans/slices/, cli/, audits/, media/
site/                  the docs site over every Markdown file
playground/            a wasm page, one tab per feature
.github/workflows/     check.yml, release.yml, docs.yml
```

- **Dependencies point inward:** `cli` → `daemon` → `runtime` → `protocol`
  → `core`. Core and protocol do no I/O, so they build for wasm and the
  playground uses them as they are.
- **One version.** `[workspace.package] version`, inherited with
  `version.workspace = true`. The release tag must equal it.
- **Lints** from `code-discipline`, inherited with `[lints] workspace = true`
  in every crate. Declare custom cfgs such as `kani` under
  `unexpected_cfgs`.
- **Production dependencies** are approved one by one and listed in the plan.
  A git dependency is pinned to a commit with `rev` and allowed by name in
  `deny.toml`.

`.cargo/mutants.toml`:

```toml
# A mutant counts as caught by any test in the workspace, since daemon tests
# exercise core through its real callers.
test_workspace = true
test_tool = "nextest"
exclude_globs = ["**/proofs.rs"]
# Each entry: why the mutant is equivalent, or why it is never built.
exclude_re = []
```

### Workflows

- **`check.yml`** on each push and pull request. Rust: format, Clippy with
  `-D warnings` for each feature set and target that exists, tests, and each
  benchmark once. Adapters: their own check. Package, on Linux and macOS: the
  script tests, a release build, the tarball, and the smoke test on it.
- **`release.yml`** on `v*-rc.*` tags. One build per target, each
  smoke-tested on its own runner, after checking that the tag equals the
  workspace version. Then a GitHub prerelease with `SHA256SUMS`. Then the
  publishing job, in a protected `release` environment that waits for
  approval, with a deploy key that can write to the tap and nothing else.
- **`docs.yml`** on each push: format check, build, deploy.

In every workflow, pin actions by commit SHA with the version as a comment,
grant `permissions: contents: read` unless a job needs more, check out with
`persist-credentials: false`, and cancel superseded runs with
`concurrency`.

### Coexisting with a stable release

The binary's name chooses its socket, configuration, state and `share/`
folders. The candidate ships as `<name>-next`, so it runs beside the stable
`<name>`, and the smoke test runs the tarball under both names.

## Gates

```sh
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --all-features --locked -- -D warnings
cargo nextest run --workspace --locked
cargo test --doc --workspace --locked
cargo build --release --locked -p <cli>
node scripts/package.mjs tarball … && node scripts/smoke.mjs dist/*.tar.gz
cargo deny check
```

Add Clippy for `--no-default-features` and for the wasm target where the
workspace has them, and the adapter's own check.

### Mutation testing

Run it over the files the slice changed, not the whole workspace:

```sh
cargo mutants -p <crate> -f crates/<crate>/src/<file>.rs -f …
```

- `TIMEOUT` counts as caught: a test hung on the mutant.
- Read `mutants.out/missed.txt`. For each miss, add the test that catches
  it, or, when the mutant cannot change behavior, exclude it in
  `exclude_re` with a comment saying why.
- Commit tests added this way on their own, as `test(<scope>): …`.

## Tests

- **Through the real boundary.** Start the daemon on a socket in a private
  temp folder, send real JSON-RPC lines, and assert on the reply and on the
  audit log.
- **Stand-ins on loopback.** An external service is replaced by a
  `TcpListener::bind("127.0.0.1:0")` that speaks the wire format captured
  from the live API, with a delay for timing cases.
- **Concurrency.** Spawn every thread before joining any, and assert on what
  the log counted as well as on the replies.
- **Waiting.** Poll for a state with a bound, such as 5 seconds; never use a
  fixed sleep to decide correctness.
- **Flaky tests.** Loop `cargo nextest run -E 'test(<name>)'` 30 to 60 times,
  then the same loop with the change stashed, to tell new from old.

## Proofs

- **Kani** for small pure functions whose every input can be enumerated, in a
  `proofs.rs` beside the module under `#[cfg(kani)]`.
- **proptest** for invariants over larger inputs.
- The slice page shows each proof as pseudocode, with what it covers.

## Benchmarks

One harness, pinned, run as `cargo bench --workspace --bench '*'`. CI runs
each benchmark once. Compare locally with a script that builds the base commit
and this tree and runs `benchstat` over 10 runs of each. An optimization keeps
its output byte for byte, and a test proves it.

## Releasing a candidate

```sh
# Cargo.toml: [workspace.package] version = "1.0.0-rc.4"
cargo build --workspace --offline && cargo build --workspace --locked
git commit -am "chore(release): 1.0.0-rc.4" && git push
# wait for Check to pass on this commit
git tag v1.0.0-rc.4 && git push origin v1.0.0-rc.4
# watch Release; the user approves the tap job
brew upgrade <name>-next && <name>-next --version
```

## Module layout

A module holding more than one concept becomes `module/`, with `mod.rs`, one
file per concept, and a `README.md` saying what each file holds, with one
example of its use. The split is a refactor commit of its own, before or after
the behavior change, never inside it.
