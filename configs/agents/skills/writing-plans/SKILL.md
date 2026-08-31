---
name: writing-plans
description: Use whenever you author or rewrite a plan, spec, or design doc — including visual plans and plan blocks (callouts, tables, captions). Enforces clean, from-scratch authoring: a plan states the current design, never its own edit history. Rewrites must strip corrections, references to previous versions/mistakes, and backward-pointing "X not Y / X instead of Y" framing. Also favors concise prose and short code examples that show usage (call sites), not definitions (signatures).
---

# Writing & rewriting plans

A plan describes the **current state of the design, as if authored from scratch.** It is
not a changelog, a diff, or a record of how the thinking evolved. A reader should never be
able to tell what an earlier draft said.

## The rule

When writing — and especially when **rewriting** — a plan, remove:

- **Corrections & self-reference.** "actually", "to clarify", "on second thought",
  "corrected", "(corrected)", "my earlier … was wrong", "this was a mistake".
- **History & version references.** "previously", "earlier", "originally", "we used to",
  "no longer applies", "as mentioned above/before", "this supersedes", "addendum",
  changelog-style prose, dates of changes.
- **Backward-pointing contrast.** "this is X, not Y", "X instead of Y", "rather than Y",
  "X over the old Y" — **when Y is something previously stated or a prior approach.**
  State X as present-tense fact.
- **Document meta.** "this section now…", "updated to…", "renamed from…".

State decisions declaratively, in the present tense. Describe the design as it is.

## The one exception

Keep a contrast when **Y is a genuine alternative the plan is actively deciding between** —
not a reference to your own prior version — and the comparison is the point. Legitimate:

- "Firecracker over Docker: one microVM per workload gives stronger isolation."
- "Postgres, not SQLite — concurrent writers are required."

The test: would the sentence still make sense to a reader who never saw an earlier draft
or the conversation? If yes, keep it. If it only makes sense as a reaction to something
previously said, cut it.

## Concision

Every sentence and example earns its place.

- **Lead with the decision; cut the wind-up.** Drop "it's worth noting", "in order to",
  "as we can see".
- **One example, not three.** Show the representative case; let the reader generalize.
- **Don't restate.** If the prose says it, the code needn't repeat it, and vice versa —
  keep whichever is clearer.
- **Elide noise.** Use `…` / `/* … */` for irrelevant bodies, imports, and error plumbing.
- **Don't over-explain.** If the design already implies something (a config is declarative,
tests aren't the product), stating it explicitly is redundant. Don't say "X never Y" when
X's nature already makes that self-evident.
- **State a decision once, across the whole artifact.** Don't repeat the same point in
different sections or blocks. Restating doesn't reinforce — it dilutes. One canonical
mention; the rest of the document should let the design speak.

## Show usage, not definitions

When you reference an API — a function, method, or endpoint — show **how it's called**,
not how it's declared. A call site conveys the shape in fewer tokens and tells the reader
exactly what to write. Cut signatures, generics, `where` clauses, trait/interface bodies,
and route declarations; show the invocation with real arguments and the result inline.

```rust
// avoid — definition
pub fn define_tool<A, F, Fut>(meta: ToolMeta, handler: F) -> Arc<dyn Tool>
where A: DeserializeOwned + JsonSchema, F: Fn(A, Ctx) -> Fut, Fut: Future<Output = ToolResult> { … }

// prefer — usage
let search = define_tool(meta, |a: SearchArgs, ctx| async move { ctx.index.query(&a.q).await });
```

```bash
# endpoint: show the call + response, not the route or schema declaration
curl -s $API/runs -d '{"prompt":"…","max_turns":3}'   # → { "id": "run_42", "status": "queued" }
```

**The one carve-out:** show a definition only when the *shape itself is the design* — a
new enum's variants, a data model, a wire/JSON contract — and then only its smallest
illustrative form. Something you *call* is never that case; show the call.

The test: could the reader paste the line and run it? If they would first have to invert a
signature into a call in their head, write the call.

## Rewrite procedure

1. Make the substantive changes.
2. **Scrub pass** — search the whole artifact for backward-pointing markers and
   rephrase/remove each:
   `actually · corrected · earlier · previously · originally · no longer · used to ·
   instead of · rather than · not just · was wrong · supersede(s) · addendum · to clarify`
3. **Tighten** — collapse any API signature/definition to a call site; delete examples
   that only restate prose; cut filler words.
4. Apply to **every surface**: prose, headings, callouts, table cells, captions, code
   comments — and across both a plan doc and its visual-plan blocks.
5. Re-read top to bottom. It should read as the first and only draft.

## General plan hygiene

- **One source of truth.** Edit in place; never append a "v2" section beside the old one.
- **Scannable.** Headings, tables, callouts; lead with the decision, then the rationale.
- **Decisions explicit.** State what is chosen; collect unresolved choices in one
  questions/open block instead of scattering hedges through the text.
- **Self-contained.** A new reader with no chat history understands it fully.

> Scope: this governs the **artifact**. In chat you may still explain what changed and
> why — the plan itself stays clean.
