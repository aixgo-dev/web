#!/usr/bin/env bash
# The act step of the release-sync loop: read the latest aixgo release from
# the GitHub API and write it as the homepage release fact. Deliberately dumb —
# no free text from the release notes reaches the page, only the tag, the
# publish date, and the release URL, each of which scripts/check-release.sh
# validates. Run with --write to update data/release.json; without it, the
# fetched fact prints to stdout and nothing changes.
set -euo pipefail

REPO="aixgo-dev/aixgo"
OUT="data/release.json"

latest=$(gh api "repos/${REPO}/releases/latest" \
  --jq '{tag: .tag_name, date: (.published_at[0:10]), url: .html_url}')

if [ "${1:-}" = "--write" ]; then
  printf '%s\n' "$latest" | jq . > "$OUT"
  echo "wrote ${OUT}: $(jq -c . "$OUT")" >&2
else
  printf '%s\n' "$latest" | jq .
fi
