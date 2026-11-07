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
# The only transitive pin report_override_policy allows. markdownlint-cli2
# 0.24.0 depends on markdownlint 0.42.0, which depends on re2js 2.8.6
# (GHSA-gg6h-894w-4m9c / CVE-2026-116795, lookbehind denial of service,
# patched in 2.8.7). No markdownlint-cli2 release past 0.24.0 exists, so the
# wrapper cannot be bumped onto a patched tree. markdownlint 0.42.1 does
# depend on re2js 2.9.1, but that release also changes MD042 and MD054 -- the
# regrade this gate exists to stop -- so the rule engine stays at the version
# the wrapper pinned and only re2js moves, to the first patched release.
# regress_override_policy hardcodes this same version in its allow fixture, so
# editing the constant without editing the fixture fails the gate.
ALLOWED_RE2JS_PIN="2.8.7"
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
#
# `dlx`/`exec`/`x`/`bunx` are the same defect as `npx` wearing several more
# names. `pnpm dlx` and `yarn dlx` fetch and run a package from the registry
# when it is not already local, same as `npx`, and both tools are already in
# the shared group -- fine to catch broadly there, since neither tool has any
# other legitimate use of the word "dlx". `npm exec` does the same, but is
# kept to npm specifically rather than joining the shared group: `yarn exec`
# and `pnpm exec` are common, legitimate commands that just run an already-
# installed local binary and fetch nothing, so matching them the way `-g` is
# matched broadly across all four tools would be the "trains people to ignore
# it" failure mode this file already warns about, not the same trade as `-g`
# (where all four tools genuinely share the flag). `npm x` is `npm exec`'s
# documented one-letter alias (`npm help exec` prints `alias: x`), matched
# the same way and for the same reason. `npm` is required to be a complete
# word (an immediate `[[:space:]]` before `[^#]*` starts) rather than merely
# a substring with a boundary before it, so that e.g. a stray mention of
# `.npmrc` earlier on the same line as unrelated prose containing "exec"
# can't complete the alternative the way a too-loose `npm exec` briefly
# matched inside `pnpm exec` during this change's own review; `[^#]*` still
# freely absorbs any flags between `npm` and `exec`/`x`.
#
# `bun x` is documented as another alias of `bunx`, but is deliberately not
# covered: unlike `npm x`, nobody in this change's own review had `bun`
# installed to confirm the alias is real, and every regex shape tried for it
# either failed to match the real `bun x pkg` case or reopened a substring
# collision (`bun` is also the first three letters of `bundle`, and `x` alone
# is too short a suffix to bound safely against an arbitrary trailing token
# like a script named `somex`). `bunx` -- confirmed, documented, and the
# dominant real-world spelling -- is caught below; it is bun's own name for
# its `npx` equivalent, not a flag on `bun` at all, so it joins `npx` in the
# bare-keyword alternative rather than either flag group.
#
# `npm_config_global` is npm's environment-variable spelling of `--global` --
# config keys become `npm_config_<key>` env vars, npm reads either casing,
# and accepts `1`/`true` interchangeably as boolean-truthy the same way it
# does on the command line -- so both value spellings are covered rather than
# just the one written out in #38. `npm_config_location=global` is the same
# env-var treatment of `--location=global`, already covered as a flag above.
# Both are their own alternative, independent of whether an `npm install`
# appears on the same line: the env var can be set once and consumed by a
# completely different line, even a different file sourcing this one.
INSTALL_PATTERN='(npm|pnpm|yarn|bun)[^#]*([[:space:]]-g([[:space:]]|$)|--global|--location[=[:space:]]+global|[[:space:]]global[[:space:]]+(add|upgrade|remove|bin|list|dir)|[[:space:]]dlx([[:space:]]|$))|(^|[^[:alnum:]_./-])npm[[:space:]][^#]*(exec|x)([[:space:]]|$)|(^|[^[:alnum:]_./-])(npx|bunx)[[:space:]]|[Nn][Pp][Mm]_[Cc][Oo][Nn][Ff][Ii][Gg]_[Gg][Ll][Oo][Bb][Aa][Ll]=(true|1)|[Nn][Pp][Mm]_[Cc][Oo][Nn][Ff][Ii][Gg]_[Ll][Oo][Cc][Aa][Tt][Ii][Oo][Nn]=global'

fail() { echo "FAIL ${1}: ${2}" >&2; exit 1; }

# ok | resolutions | overrides. resolutions is reported first when both are
# wrong, so a yarn resolutions block cannot hide behind an allowed-looking
# overrides object. jq object equality ignores key order, so the allowlist is
# the object itself, not its formatting. A non-object (a string, an array) is
# not empty and is not the allowlist.
override_policy_verdict() {
  local manifest="$1"
  jq -r --arg pin "$ALLOWED_RE2JS_PIN" '
    def obj: type == "object";
    def resolutions_bad:
      has("resolutions")
      and (
        (.resolutions | obj | not)
        or (.resolutions | length) != 0
      );
    def overrides_ok:
      (.overrides == null)
      or (
        (.overrides | obj)
        and (
          (.overrides | length) == 0
          or .overrides == {"markdownlint": {"re2js": $pin}}
        )
      );
    if resolutions_bad then "resolutions"
    elif overrides_ok then "ok"
    else "overrides"
    end
  ' "$manifest"
}

report_override_policy() {
  local manifest="$1" verdict
  verdict=$(override_policy_verdict "$manifest") || fail lint-shape "cannot read overrides in ${manifest}"
  case "$verdict" in
    ok)
      if jq -e --arg pin "$ALLOWED_RE2JS_PIN" \
        '.overrides == {"markdownlint": {"re2js": $pin}}' "$manifest" >/dev/null; then
        echo "  ok lint-shape: the only override pins markdownlint's re2js to ${ALLOWED_RE2JS_PIN}"
      else
        echo "  ok lint-shape: no overrides or resolutions"
      fi
      ;;
    resolutions)
      echo "FAIL lint-shape: ${manifest} has a non-empty 'resolutions' block; it can move the rule engine underneath a pinned wrapper" >&2
      return 1
      ;;
    overrides)
      echo "FAIL lint-shape: ${manifest} overrides are not the single allowed pin (markdownlint -> re2js ${ALLOWED_RE2JS_PIN}). Any other override can move the rule engine underneath a pinned wrapper" >&2
      return 1
      ;;
    *)
      echo "FAIL lint-shape: unexpected override verdict '${verdict}' for ${manifest}" >&2
      return 1
      ;;
  esac
}

# Silent on success. Returns 1 when the verdict is not the one the case claims,
# so a later edit that makes the allowlist match a range, a different re2js, or
# a retargeted markdownlint goes red here even if the live manifest is still
# the one allowed object.
expect_override_verdict() {
  local file="$1" expect="$2" label="$3" got
  got=$(override_policy_verdict "$file") || {
    echo "FAIL lint-shape: override regression could not read ${label}" >&2
    return 1
  }
  if [ "$got" = "$expect" ]; then
    echo "  ok lint-shape: override regression ${label} -> ${expect}"
    return 0
  fi
  echo "FAIL lint-shape: override regression ${label}: expected ${expect}, got ${got}" >&2
  return 1
}

# Fixtures are hardcoded, including the allowed "2.8.7", rather than generated
# from ALLOWED_RE2JS_PIN. The live manifest is checked against the constant;
# these fixtures are checked against the verdict function. If the constant
# moves and the allow fixture does not, the allow case stops returning ok.
regress_override_policy() {
  local tmp rc=0
  tmp=$(mktemp -d) || fail lint-shape "mktemp failed; cannot regression-test the override allowlist"

  cat > "${tmp}/absent.json" <<'EOF'
{}
EOF
  cat > "${tmp}/empty-overrides.json" <<'EOF'
{"overrides":{}}
EOF
  cat > "${tmp}/empty-resolutions.json" <<'EOF'
{"resolutions":{}}
EOF
  cat > "${tmp}/allowed.json" <<'EOF'
{"overrides":{"markdownlint":{"re2js":"2.8.7"}}}
EOF
  cat > "${tmp}/allowed-key-order.json" <<'EOF'
{"overrides":{"markdownlint":{"re2js":"2.8.7"}},"private":true}
EOF
  cat > "${tmp}/resolutions.json" <<'EOF'
{"resolutions":{"re2js":"2.8.7"}}
EOF
  cat > "${tmp}/both.json" <<'EOF'
{"overrides":{"markdownlint":{"re2js":"2.8.7"}},"resolutions":{"re2js":"2.8.7"}}
EOF
  cat > "${tmp}/other-package.json" <<'EOF'
{"overrides":{"htmlhint":"1.9.3"}}
EOF
  cat > "${tmp}/retarget-engine.json" <<'EOF'
{"overrides":{"markdownlint":"0.42.1"}}
EOF
  cat > "${tmp}/range.json" <<'EOF'
{"overrides":{"markdownlint":{"re2js":"^2.8.7"}}}
EOF
  cat > "${tmp}/vulnerable.json" <<'EOF'
{"overrides":{"markdownlint":{"re2js":"2.8.6"}}}
EOF
  cat > "${tmp}/later-re2js.json" <<'EOF'
{"overrides":{"markdownlint":{"re2js":"2.9.1"}}}
EOF
  cat > "${tmp}/unscoped.json" <<'EOF'
{"overrides":{"re2js":"2.8.7"}}
EOF
  cat > "${tmp}/extra-nested.json" <<'EOF'
{"overrides":{"markdownlint":{"re2js":"2.8.7","left-pad":"1.0.0"}}}
EOF
  cat > "${tmp}/extra-top.json" <<'EOF'
{"overrides":{"markdownlint":{"re2js":"2.8.7"},"htmlhint":"1.9.2"}}
EOF
  cat > "${tmp}/overrides-array.json" <<'EOF'
{"overrides":[]}
EOF
  cat > "${tmp}/null-overrides.json" <<'EOF'
{"overrides":null}
EOF

  expect_override_verdict "${tmp}/absent.json" ok "absent" || rc=1
  expect_override_verdict "${tmp}/empty-overrides.json" ok "empty overrides" || rc=1
  expect_override_verdict "${tmp}/empty-resolutions.json" ok "empty resolutions" || rc=1
  expect_override_verdict "${tmp}/allowed.json" ok "allowed re2js 2.8.7 pin" || rc=1
  expect_override_verdict "${tmp}/allowed-key-order.json" ok "allowed pin beside other manifest keys" || rc=1
  expect_override_verdict "${tmp}/resolutions.json" resolutions "resolutions block" || rc=1
  expect_override_verdict "${tmp}/both.json" resolutions "resolutions plus the allowed override" || rc=1
  expect_override_verdict "${tmp}/other-package.json" overrides "override of a different package" || rc=1
  expect_override_verdict "${tmp}/retarget-engine.json" overrides "markdownlint retarget" || rc=1
  expect_override_verdict "${tmp}/range.json" overrides "re2js range" || rc=1
  expect_override_verdict "${tmp}/vulnerable.json" overrides "vulnerable re2js" || rc=1
  expect_override_verdict "${tmp}/later-re2js.json" overrides "re2js newer than the allowlist" || rc=1
  expect_override_verdict "${tmp}/unscoped.json" overrides "top-level re2js override" || rc=1
  expect_override_verdict "${tmp}/extra-nested.json" overrides "extra package under markdownlint" || rc=1
  expect_override_verdict "${tmp}/extra-top.json" overrides "second top-level override" || rc=1
  expect_override_verdict "${tmp}/overrides-array.json" overrides "overrides array" || rc=1
  expect_override_verdict "${tmp}/null-overrides.json" ok "null overrides" || rc=1

  rm -rf "$tmp"
  [ "$rc" -eq 0 ]
}

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
  # gate reads. markdownlint-cli2 is a wrapper, and the rule engine it bundles
  # -- markdownlint, where MD029 lives -- is exactly the kind of thing an
  # override retargets. Pinning the wrapper to X.Y.Z while the engine floats
  # would leave this check printing ok about a toolchain that regrades content.
  #
  # The one allowed object is {"markdownlint":{"re2js": ALLOWED_RE2JS_PIN}}.
  # It does not retarget markdownlint. It replaces the vulnerable re2js that
  # markdownlint 0.42.0 declares, because that is the smallest patched release
  # and no wrapper release contains it. resolutions stay empty: this repo
  # installs with npm, and a second override mechanism is another way to move
  # the engine. A range, a different re2js, a top-level re2js pin, an engine
  # retarget, or any other key fails. regress_override_policy, run below on
  # every shape check, is what keeps a later edit from widening that exception
  # while this branch of the case statement still prints ok.
  report_override_policy "$MANIFEST" || bad=1
  regress_override_policy || bad=1

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
  #
  # $hits can hold either an install/npx hit or a scan_one "cannot read"
  # line -- the header names both, since after the diagnostics fix above a
  # failure here is no longer always the former.
  hits=$( { scan_scanned_paths; scan_stray_scripts; scan_manifest_scripts; } | sort -u)
  if [ -n "$hits" ]; then
    echo "FAIL lint-shape: a global install, an npx call, or an unscannable file survives:" >&2
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
# Reads stdin, not a file argument: awk treats a bare `var=value` operand as
# a variable assignment rather than a filename, so a tracked file literally
# named `foo=bar.sh` would have been silently read as stdin instead of opened
# -- an attacker-controlled filename choosing to skip its own scan. Taking
# stdin here sidesteps that entirely, and lets the same function join
# continuations in package.json's scripts values (piped in from jq, not a
# file at all) the same way it does for a real file's content.
join_continuations() {
  strip_noise | awk '
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
# Tagging avoids `sed "s#^#${tag}:#"`. A tag built from a tracked file's path
# is attacker-influenced (anyone who can land a commit picks the filename),
# and interpolating it into a sed *program* means a path shaped like
# `x#e#rest` closes the replacement, opens a fresh `s` command, and hands it
# sed's `e` flag -- which GNU sed (the CI runtime; BSD sed merely errors)
# executes via /bin/sh.
#
# The tag is passed via the environment (`tag=... awk '... ENVIRON["tag"]'`),
# not `awk -v tag="$tag"`, and that distinction is load-bearing, not
# stylistic: POSIX requires `-v` assignments to go through the same escape
# processing as a string literal in the awk program text, so a tracked
# filename containing the two characters `\` `n` becomes a real newline in
# the tag once `-v` unescapes it, forging extra lines into this gate's own
# FAIL output. An `ENVIRON` lookup reads the value verbatim; nothing above
# `grep_installs`/`scan_manifest_scripts` ever puts the tag in program text,
# so there is still no path to the `sed` RCE this replaced, and now no
# escape-driven output forgery either.
grep_installs() {
  local file="$1" tag="$2"
  join_continuations < "$file" \
    | grep -E "$INSTALL_PATTERN" \
    | tag="$tag" awk '{ print ENVIRON["tag"] ":" $0 }' \
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
# `-ef` (same device and inode), not a path-string comparison: an earlier
# version compared `${1#./}` to `${0#./}`, which only recognized itself when
# both the scanned path and $0 used the same relative form. Both current
# callers invoke this script as `./scripts/check-lint-pins.sh`, so that had
# no live effect, but it also matched *any* tracked file named
# check-lint-pins.sh, wherever it lives -- e.g. a planted
# .github/actions/setup/check-lint-pins.sh -- which is a wider hole now that
# the scan reaches all of .github and every tracked *.sh rather than just
# this file's own directory. `-ef` identifies the file itself regardless of
# which path string reached it, so it stays correct if a future CI refactor
# invokes this script by an absolute path.
is_self() { [ "$1" -ef "$0" ]; }

# A broken symlink (its target missing or removed) fails to open; without
# this, that failure lands inside grep_installs's `<` redirection, whose
# surrounding `|| true` -- there to tolerate grep's ordinary "no match" --
# would swallow it identically and the file would scan as silently clean.
#
# `-f` as well as `-r`: `-r` alone passes for a tracked symlink pointing at a
# directory or a device file, neither of which `-r` distinguishes from a
# plain readable file. A dir-symlink then fails inside `join_continuations`'s
# `<` redirection with an I/O error that lands in the exact `|| true` this
# guard exists to route around -- silently clean again, the failure mode
# moved rather than closed. A device-symlink (e.g. to `/dev/zero`) is worse:
# `awk` blocks reading it, hanging the gate rather than failing it. `-f`
# rejects both before either is attempted.
#
# Reports into the hits stream rather than hard-failing via `fail`: an
# earlier version called `fail` (which exits) directly on an unreadable file,
# which correctly failed the gate but also killed the rest of the pipeline
# mid-scan -- a real `npm install -g` hit already found in an earlier stage
# of the same run never got printed, leaving only the unreadable-file
# message to explain a failure it did not fully cause. Emitting a line here
# instead lets every stage finish and every real defect still get named,
# while `[ -n "$hits" ]` in check_shape still fails the gate on this line
# alone if nothing else is wrong.
scan_one() {
  local file="$1" tag="$2"
  if { [ -f "$file" ] && [ -r "$file" ]; }; then
    grep_installs "$file" "$tag"
  else
    # printf, not `echo "${tag}: ..."`: bash's builtin echo does not expand
    # backslash escapes without `-e`, so this is not the same escape-driven
    # forgery `awk -v` had -- but a tracked file's path is still
    # attacker-influenced data, and `%s` substitution is the form that stays
    # correct regardless of which `echo` a future edit ends up calling.
    printf '%s: cannot read (missing, not a regular file, or a permissions problem)\n' "$tag"
  fi
}

scan_scanned_paths() {
  local path file
  for path in "${SCANNED[@]}"; do
    if [ -d "$path" ]; then
      # -print0 / -d '': a filename containing a literal newline -- unusual,
      # but git and the filesystem both allow it -- would otherwise split
      # across two `read` iterations into two bogus, nonexistent paths, both
      # silently unscanned rather than the one real file being scanned.
      while IFS= read -r -d '' file; do
        is_self "$file" || scan_one "$file" "$file"
      done < <(find "$path" -type f -print0)
    else
      is_self "$path" || scan_one "$path" "$path"
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
    is_self "$file" || scan_one "$file" "$file"
  done || fail lint-shape "git ls-files failed; cannot confirm no install survives in a tracked *.sh file outside ${SCANNED[*]}"
}

# package.json's own `scripts` block (preinstall/postinstall/prepare, etc.) is
# data the manifest holds, not a path in SCANNED, so a global install hiding
# in a lifecycle hook was invisible to every check above it.
#
# Routed through join_continuations, the same as a real file's content: a
# JSON string can carry a literal backslash followed by a real embedded
# newline (`"preinstall": "npm install \\\n  -g pkg"`), and jq -r prints that
# escape decoded, so it reaches this scan as two physical lines shaped
# exactly like a shell script's own line continuation. Scanning those lines
# independently, as this used to, would see "-g" on its own line with no
# tool name on the same line to anchor the match -- missed entirely.
scan_manifest_scripts() {
  jq -r '(.scripts // {}) | to_entries[] | "\(.key): \(.value)"' "$MANIFEST" \
    | join_continuations \
    | grep -E "$INSTALL_PATTERN" \
    | tag="${MANIFEST} (scripts)" awk '{ print ENVIRON["tag"] ":" $0 }' \
    || true
}

[ "$#" -gt 0 ] || fail usage "no checks named; use: shape"
for c in "$@"; do
  case "$c" in
    shape) check_shape ;;
    *) fail usage "unknown check '$c'" ;;
  esac
done
