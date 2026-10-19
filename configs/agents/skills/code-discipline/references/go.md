# Go Discipline

Apply these rules when creating, changing, reviewing, or debugging Go.

## Design

- Keep the normal path direct and handle errors early.
- Define small interfaces in the package that consumes them.
- Return concrete implementations. Do not add interfaces solely for mocking.
- Prefer synchronous APIs; callers can add concurrency more easily than remove it.
- Pass values unless mutation, identity, size, or copying semantics require pointers.
- Keep package state immutable. Make mutable dependencies explicit.
- Avoid hidden `init` behavior.
- Name packages for their domain. Do not create catch-all `util`, `common`, `misc`, `types`, or `interfaces` packages.
- Accept interfaces and return structs where that produces the smallest useful contract.

## Errors and Context

- Check every returned error. Never discard one with `_` without a documented reason.
- Wrap errors with useful operation context and `%w`.
- Use panic only for impossible programmer states.
- Keep error strings lowercase and without trailing punctuation.
- Pass `context.Context` as the first parameter for request-scoped work.
- Do not store a context in a struct or create custom context types.

## Concurrency and Resources

- Every goroutine has a clear owner and exit condition.
- Propagate cancellation and errors.
- Use bounded concurrency and explicit backpressure.
- Put deadlines on network and process operations.
- Do not start background work from a library without exposing its lifecycle.
- Keep concurrent code simple enough that shutdown can be understood locally.

## Tests

- A bug fix begins with a failing regression test.
- Test failures include the input, actual result, and expected result.
- Use table-driven tests only when cases share one behavior and remain easy to diagnose.
- Test public behavior with real implementations at important boundaries.
- Run the race detector for concurrent code.
- Fuzz parsers and hostile-input boundaries; retain discovered failures as regression corpus entries.

## Lints and Gate

Use a pinned, curated `golangci-lint` configuration rather than enabling every linter. Include formatting, `govet`, Staticcheck, error checking, ineffective-assignment detection, and `funlen`.

Configure `funlen` with `lines: 70`, `statements: 40`, and `ignore-comments: true`. Generated code and fixture data may be excluded explicitly.

Prefer the repository's single check command. If none exists, the baseline gate is:

```sh
# Fail when gofmt reports a file; use gofmt -w locally.
gofmt -l .
go vet ./...
staticcheck ./...
go test ./...
go test -race ./...
govulncheck ./...
go mod verify
```

CI also verifies that `go mod tidy` leaves tracked files unchanged. Pin tool versions; do not install `@latest` during a supposedly reproducible gate.
