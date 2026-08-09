---
title: 'Aixgate'
layout: "product"
data: "aixgate"
description: 'A deny-by-default sandbox for AI coding agents. Stop Claude Code, Cursor, Aider and Codex reading your credentials at the OS syscall boundary. One Go binary, MIT.'
keywords: ['claude code sandbox', 'cursor sandbox', 'aider sandbox', 'ai coding agent security', 'sandbox-exec', 'landlock', 'prompt injection defense']
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

## Why Aixgate

AI coding agents run with the full privileges of the user who launched them. That means your `.env` files, `~/.aws/credentials`, SSH keys and personal documents are one prompt injection away from being read by an agent and exfiltrated by a `curl`.

Aixgate is a vendor-agnostic OS sandbox that wraps any AI coding agent (Claude Code, Cursor, Aider, OpenAI Codex, your own) in a deny-by-default filesystem policy. Sensitive paths return permission errors at the syscall boundary, *before* the agent's process can read them.

### Syscall-level enforcement

The kernel says no, not the prompt. `sandbox-exec` on macOS today; Landlock, seccomp and Go-FUSE on Linux in v0.2. A prompt injection that tries to read a protected path gets a permission error before the agent's process can act on it.

### One binary. No Docker. No daemon.

Pure Go. No kernel extension, no virtual machine, no background process to babysit. Install it with Homebrew or `go install`, wrap your agent with `aixgate run -- claude`, and that is the setup.

### Wraps any AI coding agent

Vendor-agnostic by design. The same sandbox works for Claude Code, Cursor, Aider, OpenAI Codex, or anything else that runs as a process on behalf of an LLM, including agents you wrote yourself.

## Install

### macOS: Homebrew

```bash
brew install aixgo-dev/tap/aixgate
```

### Any platform: `go install`

```bash
go install github.com/aixgo-dev/aixgate/cmd/aixgate@latest
```

### Pre-built binaries

Cross-platform tarballs (macOS arm64/amd64, Linux arm64/amd64) are published on every [GitHub Release](https://github.com/aixgo-dev/aixgate/releases/latest). SHA-256 checksums and an SBOM are included.

> **v0.1 platform support.** macOS only. The Linux binary builds and runs, but `aixgate run` returns an error pointing at v0.2 for the FUSE backend.

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

The policy in v0.1 is fixed: no YAML, no profiles, no flags. The paths it covers are listed below, and configurable policy lands in v0.2.

## How it works

On **macOS** (v0.1), Aixgate generates a [`sandbox-exec`](https://www.unix.com/man-page/osx/1/sandbox-exec/) profile from the hardcoded policy and launches the child process inside it with `sandbox-exec -f profile.sb -- CMD`. The kernel enforces the policy on every file read, and subprocess containment comes for free because `sandbox-exec` applies to the whole process tree.

On **Linux** (v0.2), Aixgate will compose [Landlock](https://landlock.io/) for the filesystem ABI, [seccomp-bpf](https://www.kernel.org/doc/html/latest/userspace-api/seccomp_filter.html) for syscall filtering, and [Go-FUSE](https://github.com/hanwen/go-fuse) for mount-time path hiding, which is what gives `ENOENT`-strength hiding rather than a permission error.

### One caveat worth stating plainly

Until v0.2 ships YAML policy and the audit log, do not rely on Aixgate as your only control. Treat it as defence in depth next to the precautions you already take: keep secrets out of the chat, keep credentials out of commits, and keep your `.gitignore` honest.
