# Hardening audit

Finds the states and transitions the code can reach but should not, proves
each one, and fixes it with a regression test. The result is one page,
`docs/audits/<topic>.md`, kept current as fixes land.

## 1. Map

List every state machine in scope:

- explicit ones, written as enums;
- implicit ones, held in flags, maps, files, sockets, locks and pending
  promises.

For each, write down its states, its invariants (what must always hold), a
transition table (from, on, to, then), and its files.

## 2. Hunt

For each machine, look for the moves it should never make:

- the peer closing, timing out or answering twice;
- a retry, or a reload in the middle of a request;
- two events at once for the same key: check-then-act across a slow step;
- a file saved halfway, a missing file, a link that loops;
- a limit reached: connections, queue length, file size, folder count;
- formats that change with the value, such as time precision;
- startup and shutdown races, such as a reader opening a file after a writer
  appended to it.

## 3. Confirm

A finding is confirmed when it is reproduced twice:

1. through the real path, such as the release binary or the real harness,
   with a control run that differs only in the fault;
2. as a test that fails on the current code.

Anything not reproduced, or not worth a change now, goes in the page's
"Seen, not fixed" table with how far it was reached and why it stays.

## 4. Prioritize and group

Order findings by what they do to the user: hangs and silent loss of work
first, then wrong output, then cosmetic. Group findings that share a machine
or a cause into one issue each, labelled `bug`, with the severity, what
happens, the evidence and the fix. Write each body to a file and pass
`--body-file`.

## 5. Fix

- One commit per finding, holding its test, its fix and the docs it changes,
  with `Fixes #N` or `Part of #N`.
- Each commit passes on its own. Write all the failing tests first, keep the
  full test file aside, and restore only each finding's tests with its fix.
- Mutation-test the changed files. Tests for the misses go in a separate
  `test(...)` commit; equivalent mutants are excluded with a reason.
- Run the reproduction from step 3 again on the fixed build.

## 6. Document

The page holds, in order:

1. scope, the audited commit, and a table of the checks run with results;
2. findings by severity: machine, what could happen, issue, fixing commit;
3. one section per finding: what happened, the evidence, the fix, its tests;
4. "Seen, not fixed", with reach and reason;
5. the machines, each with a `stateDiagram-v2`, its invariants and its
   transition table, noting which transition each fix removed.

Check that every diagram renders on the built site.

## 7. Close

Close each issue with a comment that names the commits. GitHub closes issues
by itself only from the default branch, so close them by hand when the fixes
land elsewhere. Ship the fixes in the next release candidate.
