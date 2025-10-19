#!/usr/bin/env bash
set -euo pipefail

# Defaults (override via env if needed)
AGENTS_PREFIX="${AGENTS_PREFIX:-agents}"
AGENTS_REMOTE="${AGENTS_REMOTE:-agents-upstream}"
AGENTS_BRANCH="${AGENTS_BRANCH:-main}"

# cd to repo root
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "${REPO_ROOT}" ]]; then
  echo "Error: not inside a git repository." >&2
  exit 1
fi
cd "${REPO_ROOT}"

# Safety: ensure clean working tree
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Error: you have uncommitted changes. Commit or stash before pulling." >&2
  exit 1
fi

# Ensure remote exists
if ! git remote get-url "${AGENTS_REMOTE}" >/dev/null 2>&1; then
  echo "Error: remote '${AGENTS_REMOTE}' not found."
  echo "Add it with:"
  echo "  git remote add ${AGENTS_REMOTE} git@github.com:SwiftedMind/agents.git"
  exit 1
fi

echo "Fetching ${AGENTS_REMOTE}..."
git fetch "${AGENTS_REMOTE}"

echo "Pulling subtree '${AGENTS_PREFIX}' from ${AGENTS_REMOTE}/${AGENTS_BRANCH}..."
git subtree pull --prefix="${AGENTS_PREFIX}" "${AGENTS_REMOTE}" "${AGENTS_BRANCH}" --squash

echo "Done."

