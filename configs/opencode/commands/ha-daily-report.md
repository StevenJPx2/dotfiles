---
description: Produces evidence-backed Hanna Andersson daily experiment reports covering performance, release status, completed work, and prioritized daily actions. Use when asked for an HA or Hanna daily report, yesterday's experiment performance, rollout status, completed todos, current priorities, or a management readout based on GA4 and Slack.
---

# Hanna Andersson Daily Report

Use the canonical framework at:

`~/Documents/Adeptmind/Projects/ga4-querinator/daily-report-plan.md`

Read it before gathering data. It defines the comparisons, queries,
calculations, evidence hierarchy, report template, status rules, and
publication gate.

## Source Rules

- Use the installed `ga4` CLI for extraction.
- Apply the CLI settlement gate before calculating or publishing: rerun every
  exact query with the same segments, metrics, filters, and dates until the
  complete JSON arm snapshots are identical in two consecutive runs. Browser
  checks are optional spot checks, not the freshness gate.
- Use `slackcli` for work and release evidence in `#hpdp-engineering`,
  `#hpdp-hanna-andersson`, and `#hpdp-releases`. Read relevant threads fully.
- Use `gh` to verify linked PR merges and workflow runs.
- Use the live Hanna site and production bundles to prove deployed behavior.

## Workflow

1. Resolve the report date, previous complete PT day, rolling-seven-day range,
   and current-configuration boundary.
2. Run the framework's primary-rollout, experimentation-bundle, and secondary
   volume-health queries for all required windows.
3. For every query, save the first JSON result, wait, and rerun the exact same
   command. Require two consecutive identical complete snapshots, including
   sessions, purchases, revenue, and requested diagnostics. If a snapshot
   changes, reset the count and continue waiting; if it never stabilizes, do
   not publish the report.
4. Save the final stable JSON result and run `just report-calc <file> <control> <treatment>
   <comparison> <period> <start> <end> [format]` from
   `~/Documents/Adeptmind/Projects/ga4-querinator`. Use its output for CVR,
   RPV, AOV, uplift, p-values, and confidence intervals.
5. Optionally compare the stable result with the live GA4 exploration using
   chrome-use. If doing so, use the all-device step, exact date range, exact
   segment pair, and no unintended filters.
6. Reconcile every prior todo through Slack, GitHub, deployment, and live
   evidence.
7. Explain whether movement came from control, treatment, order value, funnel
   behavior, or noise.
8. Create today's todos from live failures, unresolved prior work, measurement
   gaps, and observed regressions.
9. Apply the publication gate, then publish one structured management artifact
   containing all findings and one concise summary.

## Delivery State

Use only these evidence-backed states:

`Planned → In progress → Merged → Deployed → Live-verified`

Use `Failed or blocked` when live behavior or a workflow disproves completion.
A merge or release announcement alone does not mean done.

## Guardrails

- Do not generate current report data when the user asks only for the framework.
- Use deduplicated GA4 API sessions; hourly session sums are diagnostic only.
- Do not publish RPV, AOV, revenue, or duration p-values without session-level
  variance data.
- Do not let single-day performance alone produce a decision-grade red status.
- Do not infer an owner, causal explanation, deployment, or live success.
- Never calculate or publish from the first GA4 response for a recent complete
  day; GA4 can revise that response after the query returns.
- Stop publication if the settlement gate cannot produce two identical
  snapshots. A browser mismatch after stable snapshots is a query-definition
  problem to investigate, not a reason to silently choose one source.
- Do not hand-calculate values covered by `scripts/reportcalc`.
