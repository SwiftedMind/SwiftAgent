# agents — Shared Agent Instructions

Centralized, versioned Markdown for developer agents (Codecs CLI, Claude Code, etc.).
This repo is meant to be **vendored into each project at `./agents`** via **`git subtree`** so tools that can only read the working directory can access the files directly.

---

## Goals

- **Single source of truth** for agent rules, prompts, and guidelines
- **Real files in each project** (no symlinks, no cross-repo paths)
- **Simple updates**: pull from upstream or push improvements back

---

## Using This Repo with `git subtree`

### One‑time add to a consumer project

Run from the consumer repo **root**:

```bash
# Add the upstream once (SSH shown; HTTPS also works)
git remote add agents-upstream git@github.com:SwiftedMind/agents.git

# Vendor into ./agents (squash keeps consumer history tidy)
git subtree add --prefix=agents agents-upstream main --squash
```

### Pull upstream updates into the consumer

```bash
git fetch agents-upstream
git subtree pull --prefix=agents agents-upstream main --squash
```

### Push local edits in the consumer back upstream

(Requires write access to `SwiftedMind/agents`.)

```bash
git subtree push --prefix=agents agents-upstream main
```

> Tip: You can replace `main` with any tag/branch (e.g., `v1.2.3`) to pin versions.

---

## Helper Scripts (auto‑vendored)

From the consumer repo **root** you can run:

```bash
bash agents/pull.sh   # Pull from upstream into ./agents
bash agents/push.sh   # Push local ./agents changes back upstream
```

Environment overrides (optional):

- `AGENTS_PREFIX` (default: `agents`)
- `AGENTS_REMOTE` (default: `agents-upstream`)
- `AGENTS_BRANCH` (default: `main`)

Make sure the scripts are executable in this repo so perms carry over:

```bash
chmod +x agents/pull.sh agents/push.sh
```

---

## Project‑specific Additions

For repo‑local content that shouldn’t be upstreamed, use a sibling folder in the consumer repo:

```
agents.local/
  project-specific-guideline.md
  # any project‑specific rules or prompts
```
