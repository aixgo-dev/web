#!/usr/bin/env bash
# The gate for the homepage release fact. Four checks, run by name:
#
#   shape  - data/release.json parses and every field is what the template
#            expects. Runs pre-merge on every PR (lint.yml).
#   scope  - a PR authored by the sync bot may touch nothing except
#            data/release.json. Passes trivially for human PRs. Pre-merge.
#   drift  - the file matches the latest release on the GitHub API. Runs in
#            the daily sync job only — deliberately NOT pre-merge, so a new
#            aixgo release cannot block an unrelated typo-fix PR.
#   live   - the deployed homepage shows the tag. The only check that catches
#            a data-green build that never reached production. Sync job only;
#            LIVE_TRIES + LIVE_SLEEP control the polling window.
#
# Every failure is loud and names the check: a stale section fails a job, it
# never sits quiet on the page.
set -euo pipefail

FILE="data/release.json"
REPO="aixgo-dev/aixgo"
SITE="${SITE_URL:-https://aixgo.dev/}"

fail() { echo "FAIL ${1}: ${2}" >&2; exit 1; }

check_shape() {
  jq -e . "$FILE" >/dev/null 2>&1 || fail release-shape "$FILE is not valid JSON"
  local tag date url extra
  tag=$(jq -r .tag "$FILE"); date=$(jq -r .date "$FILE"); url=$(jq -r .url "$FILE")
  echo "$tag" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$' || fail release-shape "tag '$tag' is not vX.Y.Z"
  echo "$date" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' || fail release-shape "date '$date' is not YYYY-MM-DD"
  [ "$url" = "https://github.com/${REPO}/releases/tag/${tag}" ] || fail release-shape "url '$url' does not match tag '$tag'"
  extra=$(jq -r '[keys[] | select(. != "tag" and . != "date" and . != "url")] | length' "$FILE")
  [ "$extra" = "0" ] || fail release-shape "unexpected keys in $FILE"
  echo "  ok release-shape: ${tag} (${date})"
}

check_scope() {
  local actor="${GITHUB_ACTOR:-}" base bad
  case "$actor" in
    aixgo-code*) ;;
    *) echo "  ok sync-scope: actor '${actor:-local}' is not the sync bot; no constraint"; return 0 ;;
  esac
  base="${GITHUB_BASE_REF:-main}"
  git fetch -q origin "$base"
  bad=$(git diff --name-only "origin/${base}...HEAD" | grep -v '^data/release.json$' || true)
  [ -z "$bad" ] || fail sync-scope "bot PR touches more than data/release.json: ${bad}"
  echo "  ok sync-scope: bot PR touches only data/release.json"
}

check_drift() {
  local want have
  want=$(gh api "repos/${REPO}/releases/latest" --jq .tag_name)
  have=$(jq -r .tag "$FILE")
  [ "$want" = "$have" ] || fail release-drift "$FILE says ${have}; the latest release is ${want}"
  echo "  ok release-drift: ${have} is current"
}

# Cloudflare bot protection 403s bare curl from datacenter runners, which is
# where this check runs. A browser User-Agent usually passes; when the custom
# domain still 403s, the deployment is verified via the Pages origin the
# domain CNAMEs to, and the fallback is logged so it cannot pass silently.
# A page that LOADS without the tag still fails on every path.
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (release-sync gate)"
FALLBACK_SITE="${FALLBACK_SITE:-https://aixgo.pages.dev/}"

fetch_shows() { # $1=url $2=needle; returns 0 shown / 1 not shown / 2 blocked
  local body code
  body=$(curl -sS -A "$UA" -w '\n%{http_code}' "$1" 2>/dev/null) || return 2
  code="${body##*$'\n'}"
  case "$code" in
    200) printf '%s' "$body" | grep -q "$2" && return 0 || return 1 ;;
    403) return 2 ;;
    *)   return 1 ;;
  esac
}

check_live() {
  local tag tries sleep_s i rc
  tag=$(jq -r .tag "$FILE")
  tries="${LIVE_TRIES:-1}"
  sleep_s="${LIVE_SLEEP:-30}"
  i=1
  while [ "$i" -le "$tries" ]; do
    rc=0; fetch_shows "$SITE" "$tag" || rc=$?
    if [ "$rc" = "0" ]; then
      echo "  ok release-live: ${SITE} shows ${tag}"
      return 0
    fi
    if [ "$rc" = "2" ]; then
      echo "  note release-live: ${SITE} blocked this client (403); checking the Pages origin"
      if fetch_shows "$FALLBACK_SITE" "$tag"; then
        echo "  ok release-live: ${FALLBACK_SITE} shows ${tag} (custom-domain edge blocked the runner, deployment verified)"
        return 0
      fi
    fi
    [ "$i" -lt "$tries" ] && sleep "$sleep_s"
    i=$((i + 1))
  done
  fail release-live "neither ${SITE} nor ${FALLBACK_SITE} shows ${tag} after ${tries} tries"
}

[ "$#" -gt 0 ] || fail usage "no checks named; use: shape scope drift live"
for c in "$@"; do
  case "$c" in
    shape) check_shape ;;
    scope) check_scope ;;
    drift) check_drift ;;
    live)  check_live ;;
    *) fail usage "unknown check '$c'" ;;
  esac
done
