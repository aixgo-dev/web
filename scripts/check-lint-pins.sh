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

  # Comment-only lines are dropped: '#' comments out a line in both Makefiles
  # and YAML, so such a line installs nothing. Without this the gate fires on
  # its own documentation -- lint.yml explains in a comment which global
  # install it replaced, and a check that cannot tell prose from a command
  # trains people to ignore it. A command with a trailing comment still has a
  # non-'#' first character, so it is still caught.
  hits=$(grep -rnE 'npm +(install|i) +(-g|--global)' Makefile .github/workflows scripts 2>/dev/null \
    | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' || true)
  if [ -n "$hits" ]; then
    echo "FAIL lint-shape: a global npm install survives, and no lockfile binds it:" >&2
    echo "$hits" >&2
    bad=1
  else
    echo "  ok lint-shape: no global npm installs in Makefile, .github/workflows or scripts"
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
