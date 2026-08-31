---
name: code-breathing-room
description: MUST use when writing or refactoring functions, or when code feels dense or wall-of-text. Add blank lines inside function bodies and block scopes to separate logical sections (setup, core work, return). Use whenever the user mentions readability, spacing, whitespace, formatting, or grouping statements.
---

# Code Breathing Room

Insert blank lines **inside** scopes to group related statements into visual
sections. A blank line is a paragraph break: it tells the reader "this thought
is done, the next one begins." Dense code with no internal spacing forces
readers to parse every line to find the boundaries.

## Quick start

Group statements that share a purpose; separate groups with one blank line.

Before:
```js
function createUser(input) {
  const name = input.name.trim();
  const email = input.email.toLowerCase();
  if (!email.includes("@")) throw new Error("bad email");
  if (!name) throw new Error("name required");
  const user = { id: uuid(), name, email };
  db.insert(user);
  return user;
}
```

After:
```js
function createUser(input) {
  const name = input.name.trim();
  const email = input.email.toLowerCase();

  if (!email.includes("@")) throw new Error("bad email");
  if (!name) throw new Error("name required");

  const user = { id: uuid(), name, email };
  db.insert(user);

  return user;
}
```

Sections emerge: **normalize inputs → validate → build & persist → return.**

## Where to add a blank line

- Between **logical phases**: input prep, validation, the core operation,
  cleanup, return.
- **Before a `return`** that concludes non-trivial work.
- **Around every braced block** — a braced `if`/`else`, `for`, `while`, or
  `try`/`catch` block always gets one blank line above and below, so it reads
  as its own unit. This holds regardless of what sits next to it — a variable
  declaration, another statement, or a final `return`. The rule is uniform on
  purpose: don't reason about whether the block is "substantial enough" or
  whether it builds the variable above it — if it has braces, give it space.

  ```js
  // Before
  const tokens = [`Usage: ${name}`, ...positional.map(token)];
  if (options.length > 0) {
    tokens.push("[options]");
  }
  return tokens.join(" ");

  // After
  const tokens = [`Usage: ${name}`, ...positional.map(token)];

  if (options.length > 0) {
    tokens.push("[options]");
  }

  return tokens.join(" ");
  ```

  **Exceptions** (these keep this rule from fighting the "where NOT to" rules):
  - **No leading blank** when the block is the first statement in a scope
    (nothing to separate it from above).
  - **No trailing blank** when the block is the last statement in a scope.
  - **Keep consecutive guard clauses grouped** — a run of validation `if`s
    reads as one paragraph; do not put blank lines between adjacent guards:

    ```js
    if (!email.includes("@")) throw new Error("bad email");
    if (!name) throw new Error("name required");
    ```
- Between a group of related declarations and the code that consumes them.
- Before a line introducing a **new subject** (a new variable/concept the
  following lines build on).

## Where NOT to add one

- Between tightly coupled lines (a declaration and its immediate use as a pair).
- At the **very start or very end** of a scope (no leading/trailing blank line
  inside braces).
- **Never two blank lines in a row** inside a scope — one is the unit.
- In trivial 1–3 line functions; they are already a single thought.
- Don't space every single line — that destroys the grouping signal entirely.

## Workflow for refactoring a dense function

1. Read the body and mentally label each phase (what is this line *for*?).
2. Find the seams where the purpose shifts from one phase to the next.
3. Insert exactly one blank line at each seam.
4. Verify: no leading/trailing blank lines, no double blanks, each section is a
   coherent group of 1–6 lines.
5. If a section is too large to read as one idea, split it into smaller blocks
   rather than letting it sprawl.

## More examples

See [EXAMPLES.md](EXAMPLES.md) for before/after cases in Python, Go, and
TypeScript, including error-heavy functions, loop bodies, and an over-spacing
counter-example.

## Principle

The goal is **rhythm, not rules**: 2–6 short paragraphs per function, each a
single idea. If you cannot name what a section does, it may not be a real
section — re-group until each block has a clear purpose.
