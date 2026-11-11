#!/usr/bin/env bash
# Validate the portable Claude Code global-instruction package.
# Usage: bash validate.sh [--no-integration]
# Exits non-zero on any hard failure. Optional checks are skipped when tools are absent.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
NO_INTEGRATION="${1:-}"
fails=0
checks=0
tmp=""
trap 'if [ -n "$tmp" ]; then rm -rf "$tmp"; fi' EXIT

pass() {
  printf 'PASS %s\n' "$*"
  checks=$((checks + 1))
}
fail() {
  printf 'FAIL %s\n' "$*"
  fails=$((fails + 1))
  checks=$((checks + 1))
}
skip() { printf 'SKIP %s\n' "$*"; }
section() { printf '\n== %s ==\n' "$*"; }

section "required files"
for f in \
  CLAUDE.md SEDS.md validate.sh \
  guides/spec-driven-workflow.md \
  guides/workflow-conventions.md \
  guides/cross-compile-windows-rust.md \
  guides/network-mirrors-cn.md \
  guides/shared-machine-build-policy.md \
  guides/pitfalls-generic.md \
  templates/README.md \
  templates/machine-profile.example.md \
  templates/MEMORY.example.md \
  templates/mcp.example.json \
  templates/hooks.example.json \
  templates/plugins.example.json \
  templates/quality.just \
  templates/env-check.example.sh; do
  if [ -s "$ROOT/$f" ]; then pass "file: $f"; else fail "missing/empty: $f"; fi
done

section "repo-only files"
if [ -d "$ROOT/archive" ]; then
  for f in README.md archive/README.md; do
    if [ -s "$ROOT/$f" ]; then pass "file: $f"; else fail "missing/empty: $f"; fi
  done
else
  skip "archive/ not installed; validating portable subset"
fi

section "JSON"
if command -v python3 >/dev/null 2>&1; then
  shopt -s nullglob
  jsons=("$ROOT"/templates/*.json)
  shopt -u nullglob
  if [ "${#jsons[@]}" -eq 0 ]; then
    fail "no JSON templates found"
  else
    for f in "${jsons[@]}"; do
      if python3 -m json.tool "$f" >/dev/null 2>&1; then
        pass "json: ${f#"$ROOT"/}"
      else
        fail "json: ${f#"$ROOT"/}"
      fi
    done
  fi
else
  skip "python3 not found; JSON checks skipped"
fi

section "shell syntax"
for f in "$ROOT"/*.sh "$ROOT"/templates/*.sh; do
  [ -e "$f" ] || continue
  if bash -n "$f"; then pass "bash -n: ${f#"$ROOT"/}"; else fail "bash -n: ${f#"$ROOT"/}"; fi
done

section "justfile"
if command -v just >/dev/null 2>&1; then
  if just --justfile "$ROOT/templates/quality.just" --list >/dev/null 2>&1; then
    pass "just --list: templates/quality.just"
  else
    fail "just --list: templates/quality.just"
  fi
else
  skip "just not found; justfile check skipped"
fi

section "portable policy"
if [ -s "$ROOT/CLAUDE.md" ]; then
  bytes=$(wc -c <"$ROOT/CLAUDE.md")
  if [ "$bytes" -le 14000 ]; then pass "CLAUDE.md size: ${bytes}B <= 14000B"; else fail "CLAUDE.md size: ${bytes}B > 14000B"; fi
  lines=$(wc -l <"$ROOT/CLAUDE.md")
  if [ "$lines" -le 200 ]; then pass "CLAUDE.md lines: ${lines} <= 200"; else fail "CLAUDE.md lines: ${lines} > 200"; fi
fi
if grep -n '^@' "$ROOT/CLAUDE.md" >/dev/null 2>&1; then
  fail "CLAUDE.md contains ^@ import lines (must stay backticked references; imports are machine-local)"
else
  pass "no ^@ import lines in CLAUDE.md"
fi
if grep -n 'ai-memory' "$ROOT/CLAUDE.md" "$ROOT"/guides/*.md "$ROOT"/templates/*.md >/dev/null 2>&1; then
  fail "portable policy/guides/templates mention ai-memory"
else
  pass "no ai-memory dependency in policy/guides/templates"
fi
if grep -RInE '\.zcode|只加载最近一个' "$ROOT/CLAUDE.md" "$ROOT/SEDS.md" "$ROOT"/guides/*.md >/dev/null 2>&1; then
  fail "wrong-host reference or nearest-only discovery claim found"
else
  pass "no wrong-host references or nearest-only discovery claims"
fi
if [ -e "$ROOT/machine-profile.md" ]; then
  fail "machine-profile.md must not be committed"
else
  pass "no real machine-profile.md in package"
fi

section "machine-specific data"
scan_paths=("$ROOT/CLAUDE.md" "$ROOT/SEDS.md" "$ROOT/guides" "$ROOT/templates")
if [ -f "$ROOT/README.md" ]; then
  scan_paths+=("$ROOT/README.md")
fi
if grep -RInE '(/home/|/Users/|/opt/|192\.168\.|(^|[^0-9])10\.[0-9]+\.[0-9]+\.[0-9]+|172\.(1[6-9]|2[0-9]|3[01])\.)' \
  "${scan_paths[@]}" >/dev/null 2>&1; then
  fail "machine-specific path/IP found in portable files"
else
  pass "no machine-specific path/IP in portable files"
fi

section "secrets"
if grep -RInE '(AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{20,})' \
  "${scan_paths[@]}" >/dev/null 2>&1; then
  fail "secret-like string found in portable files"
else
  pass "no secret-like strings in portable files"
fi

section "archive secrets"
if [ -d "$ROOT/archive" ]; then
  if grep -RInE '(AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{20,})' \
    "$ROOT/archive" >/dev/null 2>&1; then
    fail "secret-like string found in archive"
  else
    pass "no secret-like strings in archive"
  fi
else
  skip "archive/ not installed"
fi

section "markdown links"
if command -v python3 >/dev/null 2>&1; then
  if python3 - "$ROOT" <<'PY'
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
broken = 0
for md in sorted(root.rglob("*.md")):
    if "archive" in md.parts:
        continue
    text = md.read_text(encoding="utf-8", errors="replace")
    in_fence = False
    for lineno, line in enumerate(text.splitlines(), 1):
        stripped = line.lstrip()
        if stripped.startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        line = re.sub(r"`[^`]*`", "", line)
        for match in re.finditer(r"\[[^\]]*\]\(([^)]+)\)", line):
            target = match.group(1).strip()
            if not target or target.startswith(("http://", "https://", "mailto:", "tel:", "#", "<")):
                continue
            if "<" in target or ">" in target:
                continue
            target = target.split("#", 1)[0].split("?", 1)[0].strip()
            if not target:
                continue
            path = (md.parent / target).resolve()
            if not path.exists():
                print(f"BROKEN {md.relative_to(root)}:{lineno} -> {target}")
                broken += 1
sys.exit(1 if broken else 0)
PY
  then
    pass "relative Markdown links resolve"
  else
    fail "broken relative Markdown links"
  fi
else
  skip "python3 not found; link checks skipped"
fi

section "quality gate regression"
if [ "$NO_INTEGRATION" = "--no-integration" ]; then
  skip "integration test disabled by --no-integration"
elif command -v just >/dev/null 2>&1 && command -v gitleaks >/dev/null 2>&1; then
  tmp=$(mktemp -d)
  if (
    cd "$tmp"
    git init -q
    git config user.email validator@example.invalid
    git config user.name validator
    cp "$ROOT/templates/quality.just" justfile
    printf 'api_key = "1234567890abcdef1234567890abcdef"\n' >leak.txt
    git add leak.txt
    if just quality >leak.log 2>&1; then
      echo "staged secret was not rejected"
      cat leak.log
      exit 1
    fi
    rm -f leak.txt
    printf 'FOO=bar\n' >.env
    git add -A -f
    if just quality >env.log 2>&1; then
      echo "tracked .env was not rejected"
      cat env.log
      exit 1
    fi
    rm -f .env
    git add -A -f
    if just quality >clean.log 2>&1; then
      exit 0
    fi
    echo "clean repository was rejected"
    cat clean.log
    exit 1
  ); then
    pass "quality gate rejects staged secret/tracked .env and passes clean repo"
  else
    fail "quality gate regression"
  fi
  rm -rf "$tmp"
  tmp=""
else
  skip "just/gitleaks not found; integration check skipped"
fi

section "result"
if [ "$fails" -eq 0 ]; then
  printf 'PASS: %s checks, 0 failures\n' "$checks"
  exit 0
else
  printf 'FAIL: %s checks, %s failure(s)\n' "$checks" "$fails"
  exit 1
fi
