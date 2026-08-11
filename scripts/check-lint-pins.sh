#!/usr/bin/env bash
# The gate that keeps the lint toolchain pinned. One check, run by name:
#
#   shape  - package.json declares markdownlint-cli2 and htmlhint as bare
#            X.Y.Z versions, and nothing in the repo installs an npm package
#            globally. Pre-merge on every PR (lint.yml).
#
# Why shape and not a binary check. Every path that runs these linters goes
# through `npm ci`, which installs exactly what package-lock.json records and
# hard-fails when package.json disagrees with it. So "the linter that ran IS
# the pinned one" is already true by construction; a check restating it would
# assert nothing and pass forever. The claim that can actually stop being true
# is that the declaration is still a pin:
#
#   * one '^' reintroduced by hand or by a careless merge and the lockfile is
#     the only thing holding the version -- a floor a fresh `npm install`
#     walks straight off, in a diff that looks like one character.
#   * one resurrected `npm install -g` and the lockfile is bypassed entirely,
#     which is the defect this file exists to remove: the tool deciding
#     whether content passes becomes whatever npm served that morning.
#
# That is the same class .hugo-version catches -- production graded by a
# version nobody chose. It is not hypothetical here. The orphaned
# markdownlint-cli this repo carried reached 0.49.1, whose headline change was
# "Improve MD029" -- the numbered-list rule the `1.`-for-every-item convention
# in CLAUDE.md rests on. Had that package been the one grading content, a
# routine dependency bump would have regraded every guide with no diff
# anywhere in content/.
#
# The global-install check is deliberately broad rather than scoped to the two
# linters: this repo's entire npm surface is the lint toolchain, so any global
# install here is a package escaping the lockfile, and naming only the tools
# we know about today would miss the third one someone adds tomorrow.
set -euo pipefail

MANIFEST="package.json"
TOOLS=(markdownlint-cli2 htmlhint)
SCANNED=(Makefile .github/workflows scripts)

fail() { echo "FAIL ${1}: ${2}" >&2; exit 1; }

check_shape() {
  local tool want hits bad=0
  [ -f "$MANIFEST" ] || fail lint-shape "$MANIFEST does not exist"
  command -v jq >/dev/null 2>&1 || fail lint-shape "no jq on PATH"
  jq -e . >/dev/null 2>&1 < "$MANIFEST" || fail lint-shape "$MANIFEST is not valid JSON"

  for tool in "${TOOLS[@]}"; do
    want=$(jq -r --arg t "$tool" '.devDependencies[$t] // "absent"' "$MANIFEST")
    # "absent" and "a range" are different failures with different fixes. An
    # absent tool means a lint job is about to install nothing and lint
    # nothing; a range means it installs something nobody chose.
    if [ "$want" = "absent" ]; then
      echo "FAIL lint-shape: ${MANIFEST} does not declare ${tool} in devDependencies" >&2
      bad=1
    elif ! echo "$want" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
      echo "FAIL lint-shape: ${tool} is '${want}', not a bare X.Y.Z; a range leaves package-lock.json as the only pin" >&2
      bad=1
    else
      echo "  ok lint-shape: ${tool} pinned to ${want}"
    fi
  done

  # An override moves a transitive dependency without touching the version this
  # gate reads. That is not a corner case here: markdownlint-cli2 is a wrapper,
  # and the rule engine it bundles -- markdownlint, where MD029 lives -- is
  # exactly the kind of thing an override retargets. Pinning the wrapper to
  # X.Y.Z while the engine floats would leave this check printing ok about a
  # toolchain that regrades content. The repo's whole npm surface is these two
  # linters, so any override at all is a version nobody chose.
  for field in overrides resolutions; do
    if [ "$(jq -r --arg f "$field" '(.[$f] // {}) | length' "$MANIFEST")" != "0" ]; then
      echo "FAIL lint-shape: ${MANIFEST} has a non-empty '${field}' block; it can move the rule engine underneath a pinned wrapper" >&2
      bad=1
    fi
  done

  # A path that does not exist must not read as a path with nothing wrong in
  # it. grep is silent on a missing file, so without this the check prints ok
  # about files it never opened -- the same false-clear it exists to prevent.
  for path in "${SCANNED[@]}"; do
    [ -e "$path" ] || fail lint-shape "cannot scan '${path}': it does not exist, so this check would pass without reading anything"
  done

  # Comment-only lines are dropped: '#' comments out a line in both Makefiles
  # and YAML, so such a line installs nothing. Without this the gate fires on
  # its own documentation -- lint.yml explains in a comment which global
  # install it replaced, and a check that cannot tell prose from a command
  # trains people to ignore it. A command with a trailing comment still has a
  # non-'#' first character, so it is still caught.
  #
  # The flag is matched anywhere after the verb, not just directly after it:
  # `npm install <pkg> -g` is as ordinary a spelling as `npm install -g <pkg>`
  # and escapes the lockfile identically. npx is caught too -- it silently
  # fetches from the registry when the package is not installed locally, which
  # is the same defect wearing a different hat, and every path in this repo
  # runs its linters through `npm run`.
  # This file is excluded because it is the only place in the repo where these
  # commands appear as prose -- in the failure messages below. Rewording them
  # to dodge the pattern would leave the next person to edit a message with a
  # mysteriously red gate. The exclusion is narrow and self-limiting: the file
  # is shellcheck-clean, and a global install hidden in the gate that reports
  # global installs is not a failure mode a broader regex would have caught
  # anyway.
  hits=$(grep -rnE '(npm|pnpm|yarn|bun)[^#]*(-g|--global|--location=global)|(^|[^[:alnum:]_./-])npx[[:space:]]' \
    "${SCANNED[@]}" --exclude="$(basename "$0")" 2>/dev/null \
    | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' || true)
  if [ -n "$hits" ]; then
    echo "FAIL lint-shape: a global install or npx call survives, and no lockfile binds it:" >&2
    echo "$hits" >&2
    bad=1
  else
    echo "  ok lint-shape: no global installs or npx calls in ${SCANNED[*]}"
  fi

  [ "$bad" = "0" ] || fail lint-shape "the lint toolchain is not pinned"
}

[ "$#" -gt 0 ] || fail usage "no checks named; use: shape"
for c in "$@"; do
  case "$c" in
    shape) check_shape ;;
    *) fail usage "unknown check '$c'" ;;
  esac
done
