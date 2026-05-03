# aixgo-dev/web

Source for [aixgo.dev](https://aixgo.dev) — the marketing and documentation site for the [Aixgo](https://github.com/aixgo-dev/aixgo) AI agent framework.

> **Looking to *use* Aixgo?** Visit [aixgo.dev](https://aixgo.dev) or the framework repo at [github.com/aixgo-dev/aixgo](https://github.com/aixgo-dev/aixgo). This repo is for contributors to the website itself.

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](LICENSE)
[![Hugo](https://img.shields.io/badge/built%20with-Hugo-FF4088?style=flat-square&logo=hugo)](https://gohugo.io)
[![Cloudflare Pages](https://img.shields.io/badge/deployed%20on-Cloudflare%20Pages-F38020?style=flat-square&logo=cloudflare)](https://aixgo.dev)
[![Markdownlint](https://img.shields.io/badge/markdownlint-passing-brightgreen?style=flat-square)](https://github.com/DavidAnson/markdownlint)

---

## Quick start

```bash
# One-time
brew install hugo                  # or: see gohugo.io/installation
make lint-install                  # markdownlint-cli2 + htmlhint

# Daily
make dev                           # http://localhost:1313 with live reload
make build                         # production build → public/
make lint                          # markdown + html lint
```

The production Hugo version is set via `HUGO_VERSION` in the Cloudflare Pages project env vars (the canonical pin — not committed to this repo). Copy the value from the Cloudflare Pages dashboard to match locally.

## Repository layout

```text
config/_default/        # Hugo configuration (hugo.toml, params.toml, menus, ...)
content/                # Markdown content
  ├── guides/           # Technical guides
  ├── blog/             # Blog and release announcements
  └── examples/         # YAML configuration examples
layouts/                # Hugo templates
  ├── _default/         # baseof.html, list.html, single.html
  ├── partials/         # Reusable components (head, header, footer, seo, posthog)
  └── shortcodes/       # Markdown components (feature-card, status-badge, ...)
data/                   # YAML data files driving content
  ├── features.yaml     # Feature matrix (status indicators)
  ├── milestones.yaml   # Roadmap milestones
  └── version.yaml      # Site version metadata
static/                 # Assets (css, js, favicon, _headers, CNAME)
archetypes/             # Hugo archetypes (templates for `hugo new`)
.markdownlint.json      # Markdownlint config
.htmlhintrc             # HTMLhint config
```

## How content is structured

The site is a mix of Markdown content and YAML data files. **Most updates are to the YAML data files, not the templates.** Examples:

- Adding a feature to the matrix → edit `data/features.yaml`, no code or template change.
- Updating a roadmap milestone → edit `data/milestones.yaml`.
- Tweaking the homepage tagline → edit `data/version.yaml`.

Anything that's prose for users (guides, blog posts) lives in `content/` as Markdown.

## Common tasks

### Add a new guide

1. Create `content/guides/my-guide.md`.
2. Add front matter:

   ```yaml
   ---
   title: "My Guide"
   description: "What this guide teaches in one line."
   weight: 50
   ---
   ```

3. Write the content in Markdown. Use language tags on every code fence.
4. Run `make lint` to confirm markdownlint passes.
5. Run `make dev` and check the rendered page locally.

### Add a blog post

1. Create `content/blog/2026-mm-dd-slug.md`.
2. Add front matter with `title`, `description`, `date`, and `tags`.
3. Write the content. Open a PR.

### Update the feature matrix

Edit `data/features.yaml`. The `status` field uses `complete` / `in_progress` / `roadmap` and renders as a status badge. **Do not hardcode features into templates** — the YAML is the source of truth.

### Update a milestone

Edit `data/milestones.yaml`. Same pattern — the homepage milestone cards read from this file.

### Add a Hugo shortcode

1. Create `layouts/shortcodes/my-shortcode.html`.
2. Use it in Markdown via `{{</* my-shortcode arg="value" */>}}`.
3. Document it in this README's `## Shortcodes` section if it becomes load-bearing.

## Deployment

The site is deployed to **Cloudflare Pages** with PostHog analytics. Cloudflare's GitHub app watches this repository and rebuilds on every push:

1. Push to `main` → Cloudflare Pages builds with `hugo --minify --environment production` → deploys to [aixgo.dev](https://aixgo.dev).
2. Open a PR → Cloudflare Pages builds a preview at `<branch>.aixgo-web.pages.dev` (URL pattern depends on Cloudflare Pages project settings; the preview link is posted as a check on the PR).

### Required environment variables

These are set in the Cloudflare Pages project settings (not in this repo). For local builds, copy `.env.example` to `.env` and populate.

| Variable | Purpose |
|---|---|
| `HUGO_VERSION` | Hugo version pin (must match local) |
| `HUGO_POSTHOG_KEY` | PostHog Project API Key (`phc_...`); analytics gated on this being set |
| `HUGO_POSTHOG_HOST` | Optional, defaults to `https://us.i.posthog.com` |

### Manual local production build

```bash
HUGO_POSTHOG_KEY=phc_xxx HUGO_POSTHOG_HOST=https://us.i.posthog.com make build
# Output in public/
```

## Style conventions

- **File naming**: `kebab-case.md` (e.g. `provider-integration.md`).
- **Lists**: use `1.` for every numbered list item (markdownlint enforces).
- **Code fences**: always specify language for syntax highlighting (`bash`, `go`, `yaml`, `text`).
- **Internal links**: use Hugo's `ref` shortcode (`{{</* ref "/guides/quick-start" */>}}`) so they survive renames.
- **Data files first**: prefer YAML data updates over hardcoded content in templates.

## Contributing

Open a PR. Cloudflare will build a preview within ~2 minutes; the link is posted as a check. Good first contributions: typo fixes, missing examples, broken links, new guides for under-documented framework features.

For framework documentation (API reference, ADRs), contribute to the [aixgo](https://github.com/aixgo-dev/aixgo) repo instead — the website embeds those rather than duplicating them.

## See also

- [aixgo](https://github.com/aixgo-dev/aixgo) — The Go framework this site documents.
- [aixgate](https://github.com/aixgo-dev/aixgate) — The runtime sandbox companion.

## License

[MIT](LICENSE).

> aixgo.dev builds agents. Aixgate keeps them in their lane.
