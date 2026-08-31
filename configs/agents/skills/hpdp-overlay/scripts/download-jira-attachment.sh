#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  download-jira-attachment.sh ISSUE-KEY
  download-jira-attachment.sh ISSUE-KEY FILENAME [OUTPUT-DIR]
  download-jira-attachment.sh ISSUE-KEY --all [OUTPUT-DIR]

The first form lists attachment filenames and IDs. The other forms download
attachments using jira-cli metadata and the authenticated Jira REST URL.
Required environment:
  JIRA_EMAIL or ATLASSIAN_EMAIL
  JIRA_API_KEY, JIRA_API_TOKEN, or ATLASSIAN_API_KEY
EOF
}

if [[ $# -eq 1 && ("$1" == "-h" || "$1" == "--help") ]]; then
  usage
  exit 0
fi

if [[ $# -lt 1 || $# -gt 3 ]]; then
  usage
  exit 2
fi

command -v jira >/dev/null || { printf 'error: jira-cli is not installed\n' >&2; exit 1; }
command -v jq >/dev/null || { printf 'error: jq is not installed\n' >&2; exit 1; }
command -v curl >/dev/null || { printf 'error: curl is not installed\n' >&2; exit 1; }

issue_key=$1
target=${2:-}
output_dir=${3:-/tmp/jira-attachments/$issue_key}
email=${JIRA_EMAIL:-${ATLASSIAN_EMAIL:-}}
token=${JIRA_API_KEY:-${JIRA_API_TOKEN:-${ATLASSIAN_API_KEY:-}}}

if [[ -z "$email" || -z "$token" ]]; then
  printf 'error: set JIRA_EMAIL/ATLASSIAN_EMAIL and JIRA_API_KEY/JIRA_API_TOKEN/ATLASSIAN_API_KEY\n' >&2
  exit 1
fi

# jira-cli uses JIRA_API_TOKEN; support the shorter local name without printing it.
export JIRA_API_TOKEN="$token"
raw=$(jira issue view "$issue_key" --raw)

if [[ -z "$target" ]]; then
  jq -r '.fields.attachment[]? | [.id, .filename, .size] | @tsv' <<<"$raw"
  exit 0
fi

attachments=$(jq -c '.fields.attachment[]?' <<<"$raw")
if [[ "$target" == "--all" ]]; then
  mkdir -p "$output_dir"
  while IFS= read -r attachment; do
    filename=$(jq -r '.filename' <<<"$attachment")
    url=$(jq -r '.content' <<<"$attachment")
    curl --fail --silent --show-error --location \
      --user "$email:$token" \
      --output "$output_dir/$(basename "$filename")" \
      "$url"
    printf '%s\n' "$output_dir/$(basename "$filename")"
  done <<<"$attachments"
  exit 0
fi

match=$(jq -c --arg filename "$target" 'select(.filename == $filename)' <<<"$attachments" | head -n 1)
if [[ -z "$match" ]]; then
  printf 'error: attachment not found: %s\n' "$target" >&2
  exit 1
fi

mkdir -p "$output_dir"
filename=$(jq -r '.filename' <<<"$match")
url=$(jq -r '.content' <<<"$match")
destination="$output_dir/$(basename "$filename")"
curl --fail --silent --show-error --location \
  --user "$email:$token" \
  --output "$destination" \
  "$url"
printf '%s\n' "$destination"
