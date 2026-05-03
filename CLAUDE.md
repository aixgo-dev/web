# CLAUDE.md - AI Assistant Project Guide

**Last Updated**: 2026-05-03
**Target**: AI assistants (Claude Code, GitHub Copilot, Cursor, etc.)
**Scope**: Source for the [aixgo.dev](https://aixgo.dev) marketing and documentation site.

---

## Project Overview

This repository is the Hugo source for [aixgo.dev](https://aixgo.dev), the marketing and documentation site for the [Aixgo](https://github.com/aixgo-dev/aixgo) AI agent framework. It is **not** a code repository — there is no Go code here, no Python, no agent runtime. The artefact this repository produces is a static website.

End users of Aixgo should land on [aixgo.dev](https://aixgo.dev), not on this repo. This repo is for contributors editing the website itself.

**License**: MIT
**Tech**: Hugo (static site generator), Cloudflare Pages (deploy), PostHog (analytics)

## Architecture

```text
config/_default/          # Hugo configuration
content/                  # Markdown content (guides, blog, examples)
layouts/                  # Hugo templates and partials
data/                     # YAML data files (features, milestones, version)
static/                   # Static assets (css, js, images, _headers, CNAME)
archetypes/               # Hugo archetypes for `hugo new`
.markdownlint.json        # Markdown linting config
.htmlhintrc               # HTML linting config
```

### Content vs data

Two kinds of content live here:

- **Markdown** in `content/` — prose for users (guides, blog posts). Edit when writing new docs.
- **YAML data** in `data/` — structured data for templates (feature matrix, roadmap milestones). Edit when updating status, adding features, etc.

Templates in `layouts/` consume both. The convention is: prefer YAML data updates over hardcoded content in templates.

### Deploy reality

Cloudflare Pages with GitHub-app integration. Every push to `main` triggers a build; every PR gets a preview URL.

Build command: `hugo --minify --environment production`
Output dir: `public/`
Required env vars (set in Cloudflare Pages project, not this repo): `HUGO_VERSION`, `HUGO_POSTHOG_KEY`, `HUGO_POSTHOG_HOST`.

## Code Conventions

### Markdown style

- **File naming**: `kebab-case.md` (e.g. `cost-optimization.md`, NOT `cost_optimization.md`).
- **Lists**: use `1.` for every numbered list item — markdownlint enforces and Hugo renders correctly.
- **Code fences**: ALWAYS specify language (`bash`, `go`, `yaml`, `json`, `text`). Markdownlint will flag missing fences.
- **Internal links**: use Hugo's `ref` shortcode so links survive file renames:

  ```markdown
  See the {{</* ref "/guides/quick-start" */>}} guide.
  ```

- **External links**: bare URLs are fine; Hugo auto-renders them.
- **Front matter**: every page needs at minimum `title` and `description`. Guides also need `weight` for ordering.

### Data file conventions

- `data/features.yaml`: each feature has `status: complete | in_progress | roadmap`. The status renders as a badge via the `status-badge` shortcode. Do not hardcode feature info in templates.
- `data/milestones.yaml`: roadmap milestones with `title`, `target`, and `description`. Rendered on the homepage.
- `data/version.yaml`: site-wide tagline/version data.

### Template conventions

- Partials in `layouts/partials/` (head, header, footer, seo, posthog).
- Shortcodes in `layouts/shortcodes/` (feature-card, status-badge, alpha-notice, button, etc.).
- Use `{{ partial "X" . }}` not `{{ template "X" . }}` — partials get the context.

## Key Concepts

### Cache rules

`static/_headers` defines per-path cache-control rules read by Cloudflare Pages. Changes here apply on next deploy.

### CNAME

`static/CNAME` contains `aixgo.dev` — Cloudflare Pages reads this for the custom domain config.

### llms.txt

`static/llms.txt` is an AI-crawler-friendly summary of the site, mirroring [llms-txt.org](https://llmstxt.org/) convention. Update when adding major sections.

### Robots and SEO

Robots policy and sitemap are managed by Hugo's built-in features plus `layouts/partials/seo.html` (OpenGraph, JSON-LD, canonical URLs).

## Common Tasks

### Add a new guide

1. Create `content/guides/my-guide.md`.
2. Add front matter:

   ```yaml
   ---
   title: "My Guide"
   description: "One-line summary; goes into og:description and search results."
   weight: 50
   ---
   ```

3. Write content in Markdown. Use language-tagged code fences. Run `make dev` and verify locally.
4. Run `make lint` to confirm markdownlint passes.
5. Open a PR. Cloudflare Pages will post a preview URL.

### Add a blog post

1. Create `content/blog/2026-mm-dd-slug.md`.
2. Front matter: `title`, `description`, `date` (ISO), `tags` (array).
3. Write content. Open a PR.

### Update the feature matrix

Edit `data/features.yaml`. Status transitions are usually: `roadmap` → `in_progress` → `complete`. The site re-renders automatically on next deploy.

### Update a roadmap milestone

Edit `data/milestones.yaml`. Each entry: `title`, `target` (e.g. "v0.5"), `description`, optionally `status`.

### Add a Hugo shortcode

1. Create `layouts/shortcodes/my-shortcode.html`.
2. Use in Markdown: `{{</* my-shortcode arg="value" */>}}`.
3. If it becomes load-bearing across the site, document its usage in this CLAUDE.md.

### Update site nav

Edit `config/_default/menus.en.toml`. Keep the top nav to ≤4 items (per recent design decision in commit `b8454a1`).

## Quick Reference

### Commands

```bash
make dev               # Hugo dev server at http://localhost:1313
make build             # Production build to public/
make clean             # Remove public/ and resources/
make lint              # markdownlint + htmlhint (after build)
make lint-md           # markdownlint only
make lint-html         # htmlhint only (requires built public/)
make lint-install      # one-time: install markdownlint-cli2 and htmlhint
```

### Files-by-feature

- **Hugo config**: `config/_default/hugo.toml`, `params.toml`, `menus.en.toml`
- **Homepage**: `content/_index.md`, `layouts/index.html`
- **Guides**: `content/guides/*.md`, `layouts/_default/list.html` (index), `layouts/_default/single.html` (per-page)
- **Blog**: `content/blog/*.md`
- **Features page**: `content/features.md` + `data/features.yaml` + shortcodes in `layouts/shortcodes/`
- **SEO/analytics**: `layouts/partials/seo.html`, `layouts/partials/posthog.html`
- **Cache rules**: `static/_headers`
- **Custom domain**: `static/CNAME`

### Environment

For local production builds with analytics:

```bash
cp .env.example .env
# Fill in HUGO_POSTHOG_KEY, HUGO_POSTHOG_HOST
make build
```

For Cloudflare Pages deploys, env vars are set in the Pages project settings (not committed).

### Resources

- Live site: <https://aixgo.dev>
- Framework repo: <https://github.com/aixgo-dev/aixgo>
- Sandbox companion: <https://github.com/aixgo-dev/aixgate>
- Hugo docs: <https://gohugo.io/documentation/>
- Cloudflare Pages docs: <https://developers.cloudflare.com/pages/>

> aixgo.dev builds agents. Aixgate keeps them in their lane.
