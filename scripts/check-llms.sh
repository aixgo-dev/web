#!/usr/bin/env bash
# The gate for the generated /llms.txt and /llms-full.txt. Three checks, run by
# name against a built site in public/:
#
#   shape  - llms.txt is in the format proposed at https://llmstxt.org/: one H1,
#            a blockquote, then H2 sections of `- [title](url): description`.
#            Also checks that the sections the template writes are all still
#            there, and that nothing arrived HTML-escaped.
#   docs   - the Documentation section lists every guide in content/guides.
#            This is the check that earns the rewrite: the file it replaced was
#            hand-written and had silently missed a guide, a product and the
#            whole blog. An exact count fails on the first guide that stops
#            reaching the list, including one whose front matter forgets a
#            category.
#   links  - every aixgo.dev URL in either file resolves to something the build
#            actually produced.
#   full   - llms-full.txt carries one copy of every guide, no unrendered
#            template syntax, and stays inside the size a client will fetch.
#
# Runs pre-merge in lint.yml, inside the job that already builds the site, so
# the required check that gates a merge is the one that grades these files.
#
# The external links (github.com, pkg.go.dev, the project board) are not
# resolved here, on purpose. A pre-merge gate has no business failing on a third
# party's uptime, and the failure it would catch is a typo in a line that
# changes about once a year.
set -euo pipefail

PUB="${PUB_DIR:-public}"
INDEX="${PUB}/llms.txt"
FULL="${PUB}/llms-full.txt"
HOST="${SITE_HOST:-https://aixgo.dev}"
GUIDES="content/guides"
MAX_FULL_BYTES="${MAX_FULL_BYTES:-2097152}" # 2MiB

fail() { echo "FAIL ${1}: ${2}" >&2; exit 1; }

# Guides that Hugo will build: every markdown file in the section except the
# section index, minus anything marked a draft (buildDrafts is off).
guide_count() {
  local n=0 f
  for f in "${GUIDES}"/*.md; do
    case "$f" in *_index.md) continue ;; esac
    grep -q '^draft: *true' "$f" && continue
    n=$((n + 1))
  done
  echo "$n"
}

# The lines of one `## Section` of llms.txt, up to the next `## ` or the end.
section() { awk -v want="## $1" '$0 == want {inside=1; next} /^## / {inside=0} inside' "$INDEX"; }

check_shape() {
  [ -f "$INDEX" ] || fail llms-shape "$INDEX was not built; is the llms output format still wired into [outputs] home?"

  [ "$(head -n 1 "$INDEX")" = "# Aixgo" ] || fail llms-shape "first line is not the H1 '# Aixgo'"
  local h1
  h1=$(grep -c '^# ' "$INDEX" || true)
  [ "$h1" = "1" ] || fail llms-shape "the format allows one H1; found ${h1}"
  sed -n '3p' "$INDEX" | grep -q '^> .' || fail llms-shape "no blockquote summary on line 3"

  local want
  for want in "Products" "Documentation" "About the framework" "Blog" \
              "Latest release" "Source and reference" "Optional"; do
    grep -qx "## ${want}" "$INDEX" || fail llms-shape "section '## ${want}' is missing"
  done

  # Every list entry is a markdown link with an absolute URL, optionally
  # followed by ': description'. A description that broke across lines, or a
  # bare title with no link, fails here.
  local bad
  bad=$(grep '^- ' "$INDEX" | grep -vE '^- \[[^]]+\]\(https?://[^ )]+\)(: .+)?$' || true)
  [ -z "$bad" ] || fail llms-shape "malformed list entries:"$'\n'"$bad"

  # Hugo escapes interpolated values whenever one of these templates is parsed
  # as html/template rather than text/template, which turns "RAG & Embeddings"
  # into "RAG &amp; Embeddings". isPlainText in the output format prevents it;
  # this catches the day someone drops that, or moves a line into a partial
  # (partials are parsed as HTML even from a plain-text page).
  #
  # llms.txt only. It carries guide titles and descriptions holding both an
  # ampersand and apostrophes, so it shows the regression on the first line,
  # while llms-full.txt inlines code samples that may one day contain a literal
  # entity of their own.
  local esc
  esc=$(grep -n '&amp;\|&#39;\|&#34;\|&lt;\|&gt;\|&quot;' "$INDEX" || true)
  [ -z "$esc" ] || fail llms-shape "HTML-escaped text in a plain-text file:"$'\n'"$esc"

  echo "  ok llms-shape: $(grep -c '^## ' "$INDEX") sections, $(grep -c '^- ' "$INDEX") links"
}

check_docs() {
  local want have
  want=$(guide_count)
  have=$(section "Documentation" | grep -c '^- \[' || true)
  [ "$want" = "$have" ] || fail llms-docs "Documentation lists ${have} guides; ${GUIDES} holds ${want}"
  [ "$have" -ge 5 ] || fail llms-docs "Documentation lists only ${have} guides"
  echo "  ok llms-docs: all ${have} guides listed"
}

check_links() {
  # -h drops the filename prefix; the trailing-punctuation trim is for the URLs
  # written into prose, where the sentence's full stop lands inside the match.
  # Read from a process substitution rather than a pipe so that a failure exits
  # the script instead of a subshell.
  local url path target n=0
  while read -r url; do
    path="${url#"$HOST"}"
    case "$path" in
      ""|"/")   target="${PUB}/index.html" ;;
      */)       target="${PUB}${path}index.html" ;;
      *.*)      target="${PUB}${path}" ;;
      *)        target="${PUB}${path}/index.html" ;;
    esac
    [ -f "$target" ] || fail llms-links "${url} has nothing behind it (expected ${target})"
    n=$((n + 1))
  done < <(grep -ohE "${HOST}[^ )]*" "$INDEX" "$FULL" | sed 's/[.,;:]*$//' | sort -u)
  [ "$n" -gt 0 ] || fail llms-links "no ${HOST} URLs found; the files cannot both be right and empty"
  echo "  ok llms-links: ${n} site URLs resolve in ${PUB}/"
}

check_full() {
  [ -f "$FULL" ] || fail llms-full "$FULL was not built; is the llmsfull output format still wired into [outputs] home?"

  # A surviving shortcode delimiter means a guide used a shortcode the template
  # does not handle, and the file would ship Hugo syntax where a table cell
  # should be. Whoever adds that shortcode sees this instead.
  #
  # Shortcode delimiters only, not `{{ }}` generally: guides quote Prometheus
  # alert templates, GitHub Actions expressions and Hugo templates inside fenced
  # code blocks, and those belong in the output exactly as written.
  local raw
  raw=$(grep -n '{{<\|{{%' "$FULL" | head -n 5 || true)
  [ -z "$raw" ] || fail llms-full "unrendered template syntax in the output:"$'\n'"$raw"

  local want have bytes
  want=$(guide_count)
  have=$(grep -c "^Source: ${HOST}/guides/" "$FULL" || true)
  [ "$want" = "$have" ] || fail llms-full "inlines ${have} guides; ${GUIDES} holds ${want}"

  bytes=$(wc -c < "$FULL" | tr -d ' ')
  [ "$bytes" -le "$MAX_FULL_BYTES" ] || fail llms-full "${bytes} bytes exceeds the ${MAX_FULL_BYTES} byte ceiling"
  [ "$bytes" -gt 50000 ] || fail llms-full "${bytes} bytes is too small to hold ${want} guides"
  echo "  ok llms-full: ${have} guides inlined, ${bytes} bytes"
}

[ "$#" -gt 0 ] || fail usage "no checks named; use: shape docs links full"
for c in "$@"; do
  case "$c" in
    shape) check_shape ;;
    docs)  check_docs ;;
    links) check_links ;;
    full)  check_full ;;
    *) fail usage "unknown check '$c'" ;;
  esac
done
