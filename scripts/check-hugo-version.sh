#!/usr/bin/env bash
# The gate for the Hugo version pin. Three checks, run by name:
#
#   shape       - .hugo-version is a single bare X.Y.Z line. Cheap, and it
#                 catches the pin that makes actions-hugo fail obscurely
#                 ("v0.164.0", a stray blank line) rather than clearly.
#                 Pre-merge on every PR (lint.yml).
#   binary      - the hugo on PATH is the pinned version. In CI this mostly
#                 restates the setup step, but it is what turns a silent
#                 fallback by that action into a red check. Pre-merge, and
#                 the reason `make check-hugo` is worth running locally.
#   cloudflare  - the Pages project's HUGO_VERSION env var equals the pin, in
#                 BOTH the production and preview environments. This is the
#                 whole point: Pages supports no version file for Hugo, so
#                 that env var is a hand-maintained copy of a committed value
#                 and nothing else notices when the two diverge. Needs a
#                 read-scoped API token, so it runs in hugo-pin.yml, not
#                 pre-merge. Issue #32.
#
# The drift this exists to catch already happened once: production deployed
# 0.156.0 for as long as nobody thought to look, while local and CI built on
# 0.164.0. A pin nothing enforces is a convention, not a gate.
set -euo pipefail

PIN_FILE=".hugo-version"
ACCOUNT="${CLOUDFLARE_ACCOUNT_ID:-}"
PROJECT="${CLOUDFLARE_PROJECT:-aixgo}"
API="https://api.cloudflare.com/client/v4"

fail() { echo "FAIL ${1}: ${2}" >&2; exit 1; }

pin() {
  [ -f "$PIN_FILE" ] || fail hugo-shape "$PIN_FILE does not exist"
  tr -d '[:space:]' < "$PIN_FILE"
}

check_shape() {
  local lines want
  lines=$(wc -l < "$PIN_FILE" | tr -d ' ')
  [ "$lines" = "1" ] || fail hugo-shape "$PIN_FILE must be exactly one line, found ${lines}"
  want=$(pin)
  echo "$want" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' \
    || fail hugo-shape "pin '${want}' is not a bare X.Y.Z (no leading 'v')"
  echo "  ok hugo-shape: pinned to ${want}"
}

check_binary() {
  local want have
  want=$(pin)
  command -v hugo >/dev/null 2>&1 || fail hugo-binary "no hugo on PATH"
  # hugo prints e.g. "hugo v0.164.0-<sha>+extended linux/amd64 ..."
  have=$(hugo version | sed -n 's/^hugo v\([0-9][0-9.]*\).*/\1/p')
  [ -n "$have" ] || fail hugo-binary "could not parse a version out of: $(hugo version)"
  [ "$want" = "$have" ] \
    || fail hugo-binary "${PIN_FILE} pins ${want}; the hugo on PATH is ${have}"
  echo "  ok hugo-binary: hugo ${have} matches the pin"
}

# The fixture exists so the extraction and comparison logic below is testable
# without a Cloudflare token: HUGO_PIN_FIXTURE=<file> swaps the HTTP leg for a
# saved response. It proves the jq paths, not the API call.
fetch_project() {
  if [ -n "${HUGO_PIN_FIXTURE:-}" ]; then
    cat "$HUGO_PIN_FIXTURE"
    return 0
  fi
  [ -n "$ACCOUNT" ] || fail hugo-cloudflare "CLOUDFLARE_ACCOUNT_ID is not set"
  [ -n "${CLOUDFLARE_API_TOKEN:-}" ] || fail hugo-cloudflare \
    "CLOUDFLARE_API_TOKEN is not set; this gate needs an Account -> Cloudflare Pages -> Read token (issue #32)"
  local body code
  body=$(curl -sS -w '\n%{http_code}' \
    -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
    "${API}/accounts/${ACCOUNT}/pages/projects/${PROJECT}") \
    || fail hugo-cloudflare "the Pages API request failed"
  code="${body##*$'\n'}"
  case "$code" in
    200) printf '%s' "${body%$'\n'*}" ;;
    403) fail hugo-cloudflare "the Pages API returned 403; the most likely cause is a token without Cloudflare Pages: Read" ;;
    404) fail hugo-cloudflare "no Pages project '${PROJECT}' in account ${ACCOUNT}" ;;
    *)   fail hugo-cloudflare "the Pages API returned HTTP ${code}" ;;
  esac
}

check_cloudflare() {
  local want json env have image bad=0
  want=$(pin)
  json=$(fetch_project)
  jq -e '.result.deployment_configs' >/dev/null 2>&1 <<<"$json" \
    || fail hugo-cloudflare "the Pages API response has no .result.deployment_configs"

  for env in production preview; do
    have=$(jq -r --arg e "$env" \
      '.result.deployment_configs[$e].env_vars.HUGO_VERSION.value // "unset"' <<<"$json")
    # "unset" and "wrong" are different failures with different fixes, and a
    # gate that blurs them sends you to the wrong screen. An unset preview var
    # does not error the build; it silently falls back to the build image's
    # default Hugo, which is the failure mode hardest to see from outside.
    if [ "$have" = "unset" ]; then
      echo "FAIL hugo-cloudflare: ${env} has no HUGO_VERSION; that environment builds on the image default, not ${want}" >&2
      bad=1
    elif [ "$have" != "$want" ]; then
      echo "FAIL hugo-cloudflare: ${env} HUGO_VERSION is ${have}; ${PIN_FILE} pins ${want}" >&2
      bad=1
    else
      echo "  ok hugo-cloudflare: ${env} HUGO_VERSION is ${have}"
    fi

    # Reported, not gated: which build image is correct is a judgement about
    # the toolchain, not something this gate should decide. Logged so it is
    # never a silent cap -- an image too old to run a modern extended binary
    # fails in a way the version alone cannot explain.
    image=$(jq -r --arg e "$env" \
      '.result.deployment_configs[$e].build_image_major_version // "unknown"' <<<"$json")
    echo "  note hugo-cloudflare: ${env} build image v${image}"
  done

  [ "$bad" = "0" ] || fail hugo-cloudflare "the Pages project does not match ${PIN_FILE}"
}

[ "$#" -gt 0 ] || fail usage "no checks named; use: shape binary cloudflare"
for c in "$@"; do
  case "$c" in
    shape)      check_shape ;;
    binary)     check_binary ;;
    cloudflare) check_cloudflare ;;
    *) fail usage "unknown check '$c'" ;;
  esac
done
