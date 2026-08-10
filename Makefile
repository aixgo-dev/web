.PHONY: dev serve build clean lint lint-md lint-html lint-llms lint-install check-lint-pins node-modules check-hugo check-hugo-drift

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

# Install the pinned lint toolchain (run once, and again after any pin moves).
# `npm ci` rather than `npm install`: it installs exactly what
# package-lock.json records and refuses to run when package.json disagrees
# with it, so the linter grading content here is the one grading it in CI --
# not whatever npm happened to serve this morning.
lint-install:
	npm ci

# Lint all (markdown + HTML and the generated llms.txt pair, if built)
lint: lint-md
	@if [ -d "public" ]; then \
		$(MAKE) lint-html; \
		$(MAKE) lint-llms; \
	else \
		echo "Tip: Run 'make build' first, then 'make lint-html lint-llms' to lint the built site"; \
	fi

# Both lint targets go through the npm scripts rather than naming the tool
# here, so the glob and the config path are defined once, in package.json, and
# CI runs the identical command. `npm run` resolves node_modules/.bin, so it
# cannot silently fall back to a global or to a registry download the way a
# bare `npx <tool>` can.

# Lint Markdown files in content directory
lint-md: node-modules
	@echo "Linting Markdown files..."
	npm run --silent lint:md

# Lint generated HTML (requires build first)
lint-html: node-modules
	@echo "Linting HTML files..."
	npm run --silent lint:html

# Both linters exit 0 on a glob that matches nothing, so a missing toolchain
# must fail loudly here rather than becoming a lint run that grades zero files
# and reports success.
node-modules:
	@[ -d node_modules ] || { \
		echo "node_modules/ is missing -- run 'make lint-install' first" >&2; \
		exit 1; \
	}

# Confirm the toolchain is still declared as a pin. Cheap, needs no install,
# and it is the check that notices a '^' or a global install creeping back.
check-lint-pins:
	./scripts/check-lint-pins.sh shape

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
