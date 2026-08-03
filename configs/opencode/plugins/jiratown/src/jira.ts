import { JIRATOWN_COMMENT_MARKER } from "./marker.ts"

const JIRA_BASE = process.env.JIRATOWN_JIRA_BASE_URL ?? "https://adeptmind.atlassian.net"

function auth(): string {
  const email = process.env.ATLASSIAN_EMAIL
  const key = process.env.ATLASSIAN_API_KEY
  if (!email || !key) throw new Error("ATLASSIAN_EMAIL / ATLASSIAN_API_KEY not set")
  return "Basic " + Buffer.from(`${email}:${key}`).toString("base64")
}

async function jiraFetch(path: string): Promise<any> {
  const res = await fetch(`${JIRA_BASE}/rest/api/3${path}`, {
    headers: { Authorization: auth(), Accept: "application/json" },
  })
  if (!res.ok) throw new Error(`Jira ${res.status} for ${path}`)
  return res.json()
}

/** Walk an ADF (document) node tree to plain text. */
export function adfText(node: any): string {
  if (!node || typeof node !== "object") return ""
  if (typeof node.text === "string") return node.text
  if (Array.isArray(node.content)) return node.content.map(adfText).join("")
  return ""
}

export interface JiraEvent {
  kind: "comment" | "description" | "changelog"
  issueKey: string
  at: string
  summary: string
  body?: string
  author?: string
  actionable: boolean
}

interface JiraCursor {
  commentIds: number[]
  descriptionVersion: string | undefined
  changelogCount: number
}

function emptyCursor(): JiraCursor {
  return { commentIds: [], descriptionVersion: undefined, changelogCount: 0 }
}

/**
 * Poll a Jira issue for NEW events: comments, description updates, and changelog (status /
 * assignee / priority / labels / description history). Returns events; mutates `cursor` so the
 * next call only yields events that arrived after this one.
 */
export async function pollJira(issueKey: string, cursorRaw: unknown): Promise<{ events: JiraEvent[]; cursor: JiraCursor }> {
  const cursor: JiraCursor = cursorRaw ? (cursorRaw as JiraCursor) : emptyCursor()
  const events: JiraEvent[] = []

  // Comments (newest-first) — skip jiratown's own posts (marker) and already-seen ids.
  const comments = await jiraFetch(`/issue/${issueKey}/comment?maxResults=50&orderBy=-created`)
  const freshComments: any[] = []
  for (const c of comments.comments ?? []) {
    const id = Number(c.id)
    if (cursor.commentIds.includes(id)) continue
    freshComments.push(c)
  }
  // First poll: treat pre-existing comments as history, only remember them.
  if (cursor.commentIds.length === 0) {
    cursor.commentIds = freshComments.map((c) => Number(c.id))
  } else {
    for (const c of freshComments) {
      const body = adfText(c.body)
      const actionable = !body.includes(JIRATOWN_COMMENT_MARKER)
      events.push({
        kind: "comment",
        issueKey,
        at: c.created ?? new Date().toISOString(),
        summary: `Jira ${issueKey} comment by ${c.author?.displayName ?? "someone"}`,
        body,
        author: c.author?.displayName,
        actionable,
      })
      cursor.commentIds.push(Number(c.id))
    }
  }

  // Issue fields: description version + changelog.
  const issue = await jiraFetch(`/issue/${issueKey}?expand=changelog&fields=description`)
  const desc = issue.fields?.description
  const descVersion = desc ? JSON.stringify(desc).slice(0, 40) : "none"
  if (cursor.descriptionVersion !== undefined && descVersion !== cursor.descriptionVersion) {
    events.push({
      kind: "description",
      issueKey,
      at: new Date().toISOString(),
      summary: `Jira ${issueKey} description updated`,
      body: adfText(desc),
      actionable: true,
    })
  }
  cursor.descriptionVersion = descVersion

  // Changelog (history): each entry = a field change (status, assignee, priority, labels…).
  const changelog = issue.changelog?.histories ?? []
  const total = changelog.length
  if (cursor.changelogCount !== 0 && total > cursor.changelogCount) {
    for (const h of changelog.slice(cursor.changelogCount)) {
      const items = (h.items ?? []).map((i: any) => `${i.field}: ${i.fromString ?? "none"} → ${i.toString ?? "none"}`).join("; ")
      events.push({
        kind: "changelog",
        issueKey,
        at: h.created ?? new Date().toISOString(),
        summary: `Jira ${issueKey} ${items || "changed"}`,
        body: items,
        author: h.author?.displayName,
        actionable: true,
      })
    }
  }
  cursor.changelogCount = total

  return { events, cursor }
}
