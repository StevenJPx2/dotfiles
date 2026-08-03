import { spawnSync } from "node:child_process"

function sh(args: string[]): { code: number; out: string } {
  const p = spawnSync("gh", args, { encoding: "utf8" })
  return { code: p.status ?? -1, out: (p.stdout ?? "") + (p.stderr ?? "") }
}

export interface GithubEvent {
  kind: "review" | "comment" | "ci" | "conflict" | "merged"
  repo: string
  prNumber: number
  at: string
  summary: string
  body?: string
  actionable: boolean
}

interface GithubCursor {
  reviewIds: string[]
  commentIds: string[]
  ciState: string
  mergeable: string
  prState: string
}

function emptyCursor(): GithubCursor {
  return { reviewIds: [], commentIds: [], ciState: "", mergeable: "", prState: "" }
}

/** Fetch a PR's statusCheckRollup and return only checks whose CURRENT conclusion is failing. */
function confirmStillFailing(repo: string, prNumber: number, failed: any[]): any[] {
  const res = sh(["pr", "view", String(prNumber), "--repo", repo, "--json", "statusCheckRollup"])
  if (res.code !== 0) return failed
  let rollup: any[] = []
  try {
    rollup = JSON.parse(res.out).statusCheckRollup ?? []
  } catch {
    return failed
  }
  const current = new Map<string, string>()
  for (const x of rollup) current.set(x.name ?? x.context ?? "check", (x.conclusion ?? x.state ?? "PENDING").toUpperCase())
  return failed.filter((c) => {
    const name = c.name ?? c.context ?? "check"
    const now = current.get(name)
    return now !== undefined && /FAIL|ERROR|CANCEL/i.test(now)
  })
}

/**
 * Poll a GitHub PR for NEW events: reviews, PR + line-level comments, CI check changes
 * (debounced against transients), mergeable conflict, and merge/close. Returns events;
 * mutates `cursor` so the next call only yields events after this one.
 */
export function pollGithub(repo: string, prNumber: number, cursorRaw: unknown): { events: GithubEvent[]; cursor: GithubCursor } {
  const cursor: GithubCursor = cursorRaw ? (cursorRaw as GithubCursor) : emptyCursor()
  const events: GithubEvent[] = []
  const ref = `#${prNumber}`

  const res = sh(["pr", "view", String(prNumber), "--repo", repo, "--json", "comments,statusCheckRollup,reviewDecision,reviews,mergeable,mergeStateStatus,state"])
  if (res.code !== 0) return { events, cursor } // PR deleted / no access — stay quiet
  let data: any
  try {
    data = JSON.parse(res.out)
  } catch {
    return { events, cursor }
  }

  // Reviews — ANY state, incl. bot COMMENTED.
  for (const r of data.reviews ?? []) {
    const id = "rev:" + String(r.id ?? `${r.author?.login}-${r.submittedAt}`)
    if (cursor.reviewIds.includes(id)) continue
    cursor.reviewIds.push(id)
    if (r.state === "PENDING") continue
    const hasBody = !!(r.body && r.body.trim())
    events.push({
      kind: "review",
      repo,
      prNumber,
      at: r.submittedAt ?? new Date().toISOString(),
      summary: `Review by ${r.author?.login ?? "someone"} [${r.state}] on ${ref}`,
      body: r.body,
      actionable: r.state === "CHANGES_REQUESTED" || (r.state === "COMMENTED" && hasBody),
    })
  }

  // PR-level + line-level comments.
  const commentsRes = sh(["api", `repos/${repo}/pulls/${prNumber}/comments`, "--paginate"])
  if (commentsRes.code === 0) {
    let comments: any[] = []
    try {
      comments = JSON.parse(commentsRes.out)
    } catch {
      comments = []
    }
    for (const c of comments) {
      const id = "c:" + String(c.id)
      if (cursor.commentIds.includes(id)) continue
      cursor.commentIds.push(id)
      events.push({
        kind: "comment",
        repo,
        prNumber,
        at: c.created_at ?? new Date().toISOString(),
        summary: `Comment by ${c.user?.login ?? "someone"} on ${c.path ?? ref}`,
        body: `${c.path}${c.line ? `:${c.line}` : ""} — ${c.body}`,
        actionable: !!(c.body && c.body.trim()),
      })
    }
  }

  // CI rollup change.
  const rollup = data.statusCheckRollup ?? []
  const ciState = rollup.map((x: any) => x.conclusion ?? x.state ?? "PENDING").sort().join(",")
  if (ciState && ciState !== cursor.ciState) {
    const prev = cursor.ciState
    cursor.ciState = ciState
    if (prev !== undefined) {
      let failed = rollup.filter((x: any) => /FAIL|ERROR|CANCEL/i.test(x.conclusion ?? ""))
      failed = confirmStillFailing(repo, prNumber, failed)
      if (failed.length > 0) {
        const names = failed.map((x: any) => x.name ?? x.context ?? "check").join(", ")
        events.push({
          kind: "ci",
          repo,
          prNumber,
          at: new Date().toISOString(),
          summary: `CI failed on ${ref}: ${names}`,
          body: ciFailureDetail(repo, failed),
          actionable: true,
        })
      } else {
        events.push({
          kind: "ci",
          repo,
          prNumber,
          at: new Date().toISOString(),
          summary: `CI changed on ${ref}: all passing`,
          actionable: false,
        })
      }
    }
  }

  // Mergeable conflict.
  const mergeable = data.mergeable ?? data.mergeStateStatus ?? "UNKNOWN"
  if (mergeable !== cursor.mergeable) {
    const prev = cursor.mergeable
    cursor.mergeable = mergeable
    if (prev !== undefined && (mergeable === "CONFLICTING" || mergeable === "DIRTY")) {
      events.push({
        kind: "conflict",
        repo,
        prNumber,
        at: new Date().toISOString(),
        summary: `PR ${ref} now has merge conflicts with its base (${mergeable})`,
        actionable: true,
      })
    }
  }

  // Merge / close.
  const prState = data.state ?? "OPEN"
  if (prState !== cursor.prState) {
    const prev = cursor.prState
    cursor.prState = prState
    if (prev !== undefined && (prState === "MERGED" || prState === "CLOSED")) {
      events.push({
        kind: "merged",
        repo,
        prNumber,
        at: new Date().toISOString(),
        summary: prState === "MERGED" ? `PR ${ref} was MERGED` : `PR ${ref} was CLOSED without merging`,
        actionable: prState === "MERGED",
      })
    }
  }

  return { events, cursor }
}

function ciFailureDetail(repo: string, failed: any[]): string {
  const lines: string[] = []
  const runIds = new Set<string>()
  for (const c of failed) {
    lines.push(`- ${c.name ?? c.context ?? "check"}: ${c.conclusion ?? c.state ?? "FAILURE"}`)
    const runId = String(c.detailsUrl ?? c.targetUrl ?? "").match(/\/actions\/runs\/(\d+)/)?.[1]
    if (runId) runIds.add(runId)
  }
  for (const runId of [...runIds].slice(0, 3)) {
    const log = sh(["run", "view", runId, "--repo", repo, "--log-failed"])
    if (log.code === 0 && log.out.trim()) {
      const tail = log.out.trim().split("\n").slice(-40).join("\n")
      lines.push(`\n### Failing log (run ${runId})\n\`\`\`\n${tail}\n\`\`\``)
    }
  }
  return lines.join("\n")
}
