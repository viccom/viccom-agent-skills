#!/usr/bin/env bash
# Install a curated programming-skill set from viccom-agent-skills into Codex.
# Usage: bash skill-install.example.sh [--repo DIR] [--dest DIR] [--dry-run]
# Defaults: repo=current repo, dest=$HOME/.agents/skills.
set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
dest="${HOME}/.agents/skills"
dry=0

while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo="$2"; shift 2 ;;
    --dest) dest="$2"; shift 2 ;;
    --dry-run) dry=1; shift ;;
    -h|--help) sed -n '1,20p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

skills=(
  systematic-debugging test-driven-development verification-before-completion
  writing-plans executing-plans requesting-code-review receiving-code-review
  using-git-worktrees finishing-a-development-branch dispatching-parallel-agents
  code-reviewer software-architecture-design
  golang-code-style golang-testing golang-error-handling golang-concurrency
  golang-context golang-lint
  rust-router rust-best-practices rust-skills m01-ownership m06-error-handling
  modern-python ruff
  node typescript-magician vue pinia vitest vite unocss
  spring-boot-patterns spring-security-jwt spring-data-jpa jpa-patterns
  java-code-review rest-api-conventions api-versioning problem-details-rfc9457
  configuration-properties logging-patterns test-quality testing-pyramid
  resilience-retry transactional-patterns
)

if [ "$dry" -eq 0 ]; then mkdir -p "$dest"; fi
missing=0
for name in "${skills[@]}"; do
  src="$repo/skills/$name"
  if [ ! -s "$src/SKILL.md" ]; then
    echo "MISSING $name ($src/SKILL.md)" >&2
    missing=$((missing + 1))
    continue
  fi
  target="$dest/$name"
  if [ -L "$target" ] || [ -e "$target" ]; then
    current=$(readlink -f "$target" 2>/dev/null || true)
    if [ "$current" != "$(readlink -f "$src")" ]; then
      echo "CONFLICT $target -> $current" >&2
      missing=$((missing + 1))
      continue
    fi
    echo "keep $name"
  elif [ "$dry" -eq 1 ]; then
    echo "would link $name -> $src"
  else
    ln -s "$src" "$target"
    echo "link $name -> $src"
  fi
done

if [ "$missing" -ne 0 ]; then
  echo "FAIL: $missing problem(s)" >&2
  exit 1
fi
echo "OK: ${#skills[@]} curated skills"
