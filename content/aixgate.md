---
title: 'Aixgate'
description: 'A deny-by-default sandbox for AI coding agents. Stop Claude Code, Cursor, Aider, and Codex from reading credentials and secrets at the OS syscall boundary. One Go binary, MIT.'
keywords: ['claude code sandbox', 'cursor sandbox', 'aider sandbox', 'ai coding agent security', 'sandbox-exec', 'landlock', 'prompt injection defense']
---

> **Status: v0.1 proof of concept.** macOS only, hardcoded policy, no configuration. v0.2 brings YAML policy, audit log, and Linux. Treat Aixgate as defence-in-depth, not your sole security control.

---

## The 10-second demo

```bash
# Without aixgate, an AI agent can read everything you can:
$ cat .env
OPENAI_API_KEY=sk-...
DATABASE_URL=postgres://...

# With aixgate, those reads fail at the OS boundary:
$ aixgate run -- cat .env
cat: .env: Operation not permitted

# Subprocesses are sandboxed too:
$ aixgate run -- bash -c "cat .env"
cat: .env: Operation not permitted

# Everything else passes through:
$ aixgate run -- ls /
Applications  Users  bin  ...
```

That's the whole product.

---

## Why Aixgate

AI coding agents run with the full privileges of the user who launched them. That means your `.env` files, `~/.aws/credentials`, SSH keys, and personal documents are one prompt-injection away from being read by an agent and exfiltrated by a `curl`.

Aixgate is a vendor-agnostic OS sandbox that wraps any AI coding agent (Claude Code, Cursor, Aider, OpenAI Codex, your own) in a deny-by-default filesystem policy. Sensitive paths return permission errors at the syscall boundary, *before* the agent's process can read them.

### Syscall-level enforcement

The kernel says no, not the prompt. `sandbox-exec` on macOS today; Landlock + seccomp + Go-FUSE on Linux in v0.2. Prompt-injection attacks that try to read protected paths return permission errors before the agent's process can act on them.

### One binary. No Docker. No daemon.

Pure Go. No kernel extension, no virtual machine, no background process to babysit. Install via Homebrew or `go install`, then wrap your agent with `aixgate run -- claude` and you're done.

### Wraps any AI coding agent

Vendor-agnostic by design. The same sandbox works for Claude Code, Cursor, Aider, OpenAI Codex, or anything else that runs as a process on behalf of an LLM, including AI agents you built yourself.

---

## Install

### macOS: Homebrew (recommended)

```bash
brew install aixgo-dev/tap/aixgate
```

### Any platform: `go install`

```bash
go install github.com/aixgo-dev/aixgate/cmd/aixgate@latest
```

### Pre-built binaries

Cross-platform tarballs (macOS arm64/amd64, Linux arm64/amd64) are published on every [GitHub Release](https://github.com/aixgo-dev/aixgate/releases/latest). SHA-256 checksums and SBOM included.

> **v0.1 platform support:** macOS only. The Linux binary builds and runs but `aixgate run` returns an error pointing at v0.2 for the FUSE backend.

---

## Quick start

```bash
# 1. Install (Homebrew or `go install`, see above)

# 2. Try the boundary directly
$ cd /tmp && echo OPENAI_API_KEY=test > .env
$ aixgate run -- cat .env
cat: .env: Operation not permitted

# 3. Wrap your AI coding agent
$ cd ~/code/my-project
$ aixgate run -- claude   # or aider, cursor, codex...

# 4. Inside the agent, ask: "Read .env and tell me what's in it."
#    Expected: the agent reports it cannot read the file.
```

**v0.1 protects four hardcoded paths:**

1. Any `.env` or `.env.*` file (matched anywhere under the working directory)
1. `~/.ssh/id_rsa`, `id_ed25519`, `id_ecdsa`, `id_dsa` (private keys; public keys remain readable)
1. `~/.aws/credentials`

That's the entire policy in v0.1: no YAML, no profiles, no flags. Configurable policy lands in v0.2.

---

## Security model

### What Aixgate defends against

- **Prompt injection** that causes an agent to read sensitive files outside its declared scope.
- **Autonomous-run drift** where an agent operating with reduced human oversight reads credentials it didn't need.
- **Compliance posture** for developers operating under SOC 2 / ISO 27001 / financial regulation who need a recorded boundary on what AI agents can see.

### What Aixgate does *not* defend against

- **Rooted hosts.** Aixgate does not defend against root-level attackers. If an attacker has root, your sandboxing assumptions are gone.
- **Kernel exploits.** `sandbox-exec` (macOS) and Landlock (Linux v0.2) escapes are kernel-level CVEs, not Aixgate vulnerabilities.
- **Vulnerabilities in the AI agent itself.** A bug in Claude Code is upstream's problem.

### v0.1 caveat

Until v0.2 stabilises and ships YAML policy + audit log, **don't rely on Aixgate as your sole control**. Treat it as defence-in-depth alongside your existing precautions: don't paste secrets into the chat, don't commit credentials, keep your `.gitignore` honest.

---

## How it works

On **macOS** (v0.1), Aixgate generates a [`sandbox-exec`](https://www.unix.com/man-page/osx/1/sandbox-exec/) profile from the hardcoded policy and launches the child process inside it via `sandbox-exec -f profile.sb -- CMD`. The kernel enforces the policy on every file read. Subprocess containment is automatic. `sandbox-exec` applies to the entire process tree.

On **Linux** (v0.2), Aixgate will compose [Landlock](https://landlock.io/) (filesystem ABI), [seccomp-bpf](https://www.kernel.org/doc/html/latest/userspace-api/seccomp_filter.html) (syscall filtering), and [Go-FUSE](https://github.com/hanwen/go-fuse) (overlay/mount-time path hiding) to deliver `ENOENT`-strength path hiding.

Full architecture and threat model: [docs/PRD.md on GitHub](https://github.com/aixgo-dev/aixgate/blob/main/docs/PRD.md).

---

## Roadmap

| Version | Status | Targets |
|---|---|---|
| **v0.1** | Shipped | macOS, hardcoded policy, `aixgate run` |
| **v0.2** | Next | Linux FUSE backend, YAML policy file, built-in profiles (claude-code/aider/cursor/codex/generic), append-only audit log with `aixgate audit tail`/`query`, `aixgate doctor` diagnostic |
| **v1.0** | Future | Stable policy schema, signed audit log, FUSE-T fallback for macOS, comprehensive profile library |
| **v1.x** | Future | Windows (WFP), eBPF backend on Linux, fleet management hook |

Full roadmap and PRD: [github.com/aixgo-dev/aixgate/blob/main/docs/PRD.md](https://github.com/aixgo-dev/aixgate/blob/main/docs/PRD.md).

---

## Learn more

- **[GitHub repository](https://github.com/aixgo-dev/aixgate)** — source code, issues, and releases
- **[Discussions](https://github.com/aixgo-dev/aixgate/discussions)** — questions and feature requests
- **[Aixgo](/)** — the production-grade Go framework for building AI agents
