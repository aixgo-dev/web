.PHONY: dev serve build clean lint lint-md lint-html lint-llms lint-install check-hugo check-hugo-drift

# Load environment variables from .env if it exists
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

# Development server with fast render disabled for accurate previews
dev:
	hugo server --disableFastRender

# Alias for dev
serve: dev

# Build the site for production
build:
	hugo --minify --environment production

# Clean generated files
clean:
	rm -rf public/ resources/

# =============================================================================
# Linting
# =============================================================================

# Install linting dependencies (run once)
lint-install:
	npm install -g markdownlint-cli2 htmlhint

# Lint all (markdown + HTML and the generated llms.txt pair, if built)
lint: lint-md
	@if [ -d "public" ]; then \
		$(MAKE) lint-html; \
		$(MAKE) lint-llms; \
	else \
		echo "Tip: Run 'make build' first, then 'make lint-html lint-llms' to lint the built site"; \
	fi

# Lint Markdown files in content directory
lint-md:
	@echo "Linting Markdown files..."
	markdownlint-cli2 "content/**/*.md"

# Lint generated HTML (requires build first)
lint-html:
	@echo "Linting HTML files..."
	htmlhint "public/**/*.html" --config .htmlhintrc

# Gate the generated /llms.txt and /llms-full.txt (requires build first).
# Same script CI runs, so a failure here is the failure a PR would get.
lint-llms:
	@echo "Checking the generated llms.txt pair..."
	./scripts/check-llms.sh shape docs links full

# Confirm the local hugo is the pinned one. Worth running after a `brew
# upgrade hugo`, which is how local drifts off the pin without anyone deciding
# to.
check-hugo:
	./scripts/check-hugo-version.sh shape binary

# Exercise the Cloudflare comparison against the saved fixtures -- no token
# needed. The drift fixture MUST fail; that is the check, not a bug.
check-hugo-drift:
	@echo "Matching fixture (expect green):"
	@HUGO_PIN_FIXTURE=scripts/fixtures/pages-project.json ./scripts/check-hugo-version.sh cloudflare
	@echo "Drift fixture (expect red):"
	@HUGO_PIN_FIXTURE=scripts/fixtures/pages-project-drift.json ./scripts/check-hugo-version.sh cloudflare \
		&& { echo "FAIL: the drift fixture passed; the gate is not gating" >&2; exit 1; } || true
