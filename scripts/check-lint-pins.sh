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
# .github (not .github/workflows) so a global install hiding in
# .github/actions/ is scanned too -- actions are shell scripts same as
# anything in scripts/, just in a directory the original list skipped.
SCANNED=(Makefile .github scripts)
# The install/npx pattern shared by every scan below. `-g` is bounded on both
# sides (whitespace before, whitespace-or-end-of-line after): the scan now
# reaches every tracked *.sh file in the repo rather than just three known
# paths, so an unbounded `-g` would fire on any ordinary token that merely
# contains "-g" -- not just a package name like `foo-gzip`, but a monorepo
# flag like `--workspace=packages/ui-g` or `--filter=app-g`, neither of which
# is a global install. A gate that goes red on an ordinary flag is the "trains
# people to ignore it" failure mode this file already warns about below.
# `--location` accepts either `=` or a space before its value (npm's arg
# parser treats them the same), so both spellings are one alternative. Yarn's
# global install has no `-g`/`--global` at all -- `global` is a subcommand
# family (`yarn global add|upgrade|remove|bin|list|dir`) -- so it needs its
# own alternative rather than fitting the flag-shaped ones above.
INSTALL_PATTERN='(npm|pnpm|yarn|bun)[^#]*([[:space:]]-g([[:space:]]|$)|--global|--location[=[:space:]]+global|[[:space:]]global[[:space:]]+(add|upgrade|remove|bin|list|dir))|(^|[^[:alnum:]_./-])npx[[:space:]]'

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

  # scan_manifest_scripts assumes .scripts is an object; jq's `to_entries`
  # throws on any other type, and that error would otherwise be swallowed by
  # the scan's own `|| true` (there to tolerate grep's ordinary "no match")
  # indistinguishably from a clean manifest -- a malformed manifest reporting
  # ok is the same false-clear the rest of this file exists to prevent.
  case "$(jq -r '(.scripts // {}) | type' "$MANIFEST")" in
    object) ;;
    *) fail lint-shape "${MANIFEST}'s scripts field is not an object; it cannot be scanned for lifecycle-hook installs" ;;
  esac

  # A path that does not exist must not read as a path with nothing wrong in
  # it. grep is silent on a missing file, so without this the check prints ok
  # about files it never opened -- the same false-clear it exists to prevent.
  for path in "${SCANNED[@]}"; do
    [ -e "$path" ] || fail lint-shape "cannot scan '${path}': it does not exist, so this check would pass without reading anything"
  done

  # scripts/*.sh is walked by scan_scanned_paths (it's in SCANNED) and again
  # by scan_stray_scripts (it's tracked); `sort -u` collapses the duplicate so
  # one real defect doesn't print as two.
  hits=$( { scan_scanned_paths; scan_stray_scripts; scan_manifest_scripts; } | sort -u)
  if [ -n "$hits" ]; then
    echo "FAIL lint-shape: a global install or npx call survives, and no lockfile binds it:" >&2
    echo "$hits" >&2
    bad=1
  else
    echo "  ok lint-shape: no global installs or npx calls in ${SCANNED[*]}, tracked *.sh files, or ${MANIFEST}'s scripts block"
  fi

  [ "$bad" = "0" ] || fail lint-shape "the lint toolchain is not pinned"
}

# Strips a trailing CR and a comment from every physical line, before
# anything decides whether that line continues onto the next one.
#
#   * CRLF: a CRLF-authored file leaves '\r' as the last character before the
#     newline awk splits on, so `buf ~ /\\$/` never matches a continuation
#     that in fact ends `...pkg\` `\r` -- the join this file exists to
#     perform silently stops at the first CRLF line.
#   * Comment: '#' comments out the rest of a line in both Makefiles and
#     YAML, so a comment installs nothing regardless of what it says --
#     stripping it here, before the continuation check, handles both
#     directions of the same hazard. A comment ending in `\` is not a
#     continuation (the comment, backslash included, already ended at the
#     newline), so stripping it first stops the joiner from inventing one and
#     gluing a real command onto it. Symmetrically, a real command ending in
#     `\` followed by an explanatory comment on the next physical line --
#     exactly the shape lint.yml's own comments use -- must not have that
#     comment's prose glued onto the command and mistaken for code merely
#     because it repeats a flag name.
#
# A command with a trailing comment on the same line still keeps its non-'#'
# prefix, so it is still caught: `npm install -g pkg # temporary` strips to
# `npm install -g pkg `, which still matches.
#
# The trade this makes: on `main`, a match could still fire from content
# wholly after a `#` (nothing stopped it once past the character class), so a
# line like `npm install https://example.com/pkg#v1 -g` would match on the
# `-g` after the URL fragment's `#`. Stripping the comment outright closes
# that path along with the comment-swallowing bugs above, but it also means
# nothing after any `#` on a logical line is examined at all -- an install
# hidden after an unrelated `#` earlier on the same line (a git-URL fragment,
# a shell comment used mid-command as a label) is now missed rather than
# risked. Deliberate: the swallowed-command bugs were real and reachable
# false-clears; a `#`-fragment install is a narrower, more contrived shape.
#
# awk, not sed: this file uses awk throughout specifically because BSD awk
# (macOS, where this repo is edited) and the awk CI actually runs under
# (mawk on Ubuntu, confirmed) behave identically for the constructs used
# here, and mixing in a sed call would reopen the same platform question this
# file already resolved once, in the join_continuations comment below.
strip_noise() { awk '{ sub(/\r$/, ""); sub(/#.*/, ""); print }'; }

# Backslash-newline continuations join into one logical line, tagged with the
# line the statement started on, before the pattern ever sees them. grep is
# line-based, so `npm install \` on one line and `  -g pkg` on the next reads
# as two harmless fragments unless something joins them first. Implemented in
# awk rather than GNU sed's `N`/branch idiom because this repo is edited on
# macOS (BSD sed) and gated on Ubuntu CI (GNU sed) -- a join that behaves
# differently in the two places is the exact false-success class this file
# exists to prevent.
#
# The file is read via stdin redirection, not as an awk operand: awk treats a
# bare `var=value` operand as a variable assignment rather than a filename, so
# a tracked file literally named `foo=bar.sh` would have been silently read as
# stdin instead of opened -- an attacker-controlled filename choosing to skip
# its own scan. Piping through strip_noise first means join_continuations
# never sees a raw file operand at all.
join_continuations() {
  strip_noise < "$1" | awk '
    function flush() { if (started) { print start_line ":" buf; started = 0; buf = "" } }
    {
      if (!started) { start_line = NR; buf = $0; started = 1 } else { buf = buf " " $0 }
      if (buf ~ /\\$/) { sub(/\\$/, "", buf); next }
      flush()
    }
    END { flush() }
  '
}

# The flag is matched anywhere after the verb, not just directly after it:
# `npm install <pkg> -g` is as ordinary a spelling as `npm install -g <pkg>`
# and escapes the lockfile identically. npx is caught too -- it silently
# fetches from the registry when the package is not installed locally, which
# is the same defect wearing a different hat, and every path in this repo
# runs its linters through `npm run`.
#
# The trailing `|| true` matters under `set -o pipefail`: grep exits 1 on "no
# match", which is the common case (a clean file), and without it every clean
# scan would trip `set -e` and abort the gate before it ever reported ok.
#
# Tagging uses `awk -v`, not `sed "s#^#${tag}:#"`. A tag built from a tracked
# file's path is attacker-influenced (anyone who can land a commit picks the
# filename), and interpolating it into a sed *program* means a path shaped
# like `x#e#rest` closes the replacement, opens a fresh `s` command, and hands
# it sed's `e` flag -- which GNU sed (the CI runtime; BSD sed merely errors)
# executes via /bin/sh. `awk -v` passes the tag as data, never as program
# text, so there is no analogous escape.
grep_installs() {
  local file="$1" tag="$2"
  join_continuations "$file" \
    | grep -E "$INSTALL_PATTERN" \
    | awk -v tag="$tag" '{ print tag ":" $0 }' \
    || true
}

# This file is excluded because it is the only place in the repo where these
# commands appear as prose -- in the failure messages above. Rewording them
# to dodge the pattern would leave the next person to edit a message with a
# mysteriously red gate. The exclusion is narrow and self-limiting: the file
# is shellcheck-clean, and a global install hidden in the gate that reports
# global installs is not a failure mode a broader regex would have caught
# anyway.
#
# Compares the repo-relative path, not the basename: matching on basename
# alone would exempt *any* tracked file named check-lint-pins.sh, wherever it
# lives -- e.g. a planted .github/actions/setup/check-lint-pins.sh -- which is
# a wider hole now that the scan reaches all of .github and every tracked
# *.sh rather than just this file's own directory.
is_self() { [ "${1#./}" = "${0#./}" ]; }

scan_scanned_paths() {
  local path file
  for path in "${SCANNED[@]}"; do
    if [ -d "$path" ]; then
      while IFS= read -r file; do
        is_self "$file" || grep_installs "$file" "$file"
      done < <(find "$path" -type f)
    else
      is_self "$path" || grep_installs "$path" "$path"
    fi
  done
}

# The repo's npm surface is not limited to the paths above -- any tracked
# shell script anywhere is as real a leak as one in scripts/. `git ls-files`
# rather than `find .`: it is tracked-only, so it walks past node_modules/,
# public/, and resources/ without a hand-maintained exclusion list to keep in
# sync with .gitignore, and it never reaches into content/, where a guide can
# legitimately show `npm install -g` in a fenced code example.
#
# `-z` output with `core.quotepath=false`, read on NUL rather than newline:
# git's default output quotes a non-ASCII path in double quotes (e.g.
# "caf\303\251.sh"), which would be handled as that literal quoted string
# rather than opened as the real file, and a name containing a newline would
# otherwise be split across two `read` iterations.
#
# Piped into the loop, not fed via `< <(...)` process substitution: a process
# substitution's exit status is not the pipeline's, so under `set -e` a
# failing `git ls-files` (no `.git`, a dubious-ownership refusal, or similar)
# would silently read as zero files scanned and this function would report
# nothing wrong -- exactly the false-clear the existence check above already
# guards against for the paths in SCANNED. Piping keeps `set -o pipefail` able
# to see git's exit status; the loop's own status is always 0 (grep_installs
# guarantees it), so pipefail surfaces git's failure, not the loop's success.
scan_stray_scripts() {
  local file
  git -c core.quotepath=false ls-files -z -- '*.sh' | while IFS= read -r -d '' file; do
    is_self "$file" || grep_installs "$file" "$file"
  done || fail lint-shape "git ls-files failed; cannot confirm no install survives in a tracked *.sh file outside ${SCANNED[*]}"
}

# package.json's own `scripts` block (preinstall/postinstall/prepare, etc.) is
# data the manifest holds, not a path in SCANNED, so a global install hiding
# in a lifecycle hook was invisible to every check above it.
scan_manifest_scripts() {
  jq -r '(.scripts // {}) | to_entries[] | "\(.key): \(.value)"' "$MANIFEST" \
    | awk '{ print NR ":" $0 }' \
    | strip_noise \
    | grep -E "$INSTALL_PATTERN" \
    | awk -v tag="${MANIFEST} (scripts)" '{ print tag ":" $0 }' \
    || true
}

[ "$#" -gt 0 ] || fail usage "no checks named; use: shape"
for c in "$@"; do
  case "$c" in
    shape) check_shape ;;
    *) fail usage "unknown check '$c'" ;;
  esac
done
