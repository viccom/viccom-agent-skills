#!/usr/bin/env bash
# Validate the portable Codex global-instruction package.
# Usage: bash validate.sh [--no-integration]
# Exits non-zero on any hard failure. Optional checks are skipped when tools are absent.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
NO_INTEGRATION="${1:-}"
IS_LIVE=0
if [ "$(basename -- "$ROOT")" = ".codex" ] || { [ -n "${CODEX_HOME:-}" ] && [ "$(cd -- "${CODEX_HOME:-/nonexistent}" 2>/dev/null && pwd)" = "$ROOT" ]; }; then
  IS_LIVE=1
fi
fails=0
checks=0
tmp=""
trap 'if [ -n "$tmp" ]; then rm -rf "$tmp"; fi' EXIT

pass() { printf 'PASS %s\n' "$*"; checks=$((checks + 1)); }
fail() { printf 'FAIL %s\n' "$*"; fails=$((fails + 1)); checks=$((checks + 1)); }
skip() { printf 'SKIP %s\n' "$*"; }
section() { printf '\n== %s ==\n' "$*"; }

section "required files"
for f in \
  AGENTS.md SEDS.md README.md validate.sh \
  guides/spec-driven-workflow.md \
  guides/workflow-conventions.md \
  guides/cross-compile-windows-rust.md \
  guides/network-mirrors-cn.md \
  guides/shared-machine-build-policy.md \
  guides/pitfalls-generic.md \
  guides/codex-harness-inspection.md \
  templates/README.md \
  templates/machine-profile.example.md \
  templates/MEMORY.example.md \
  templates/mcp.example.toml \
  templates/hooks.example.json \
  templates/plugins.example.toml \
  templates/skill-routing.example.md \
  templates/skill-install.example.sh \
  templates/quality.just \
  templates/env-check.example.sh; do
  if [ -s "$ROOT/$f" ]; then pass "file: $f"; else fail "missing/empty: $f"; fi
done

section "repo-only files"
if [ -d "$ROOT/archive" ]; then
  archive_md_count=0
  while IFS= read -r f; do
    archive_md_count=$((archive_md_count + 1))
  done < <(find "$ROOT/archive" -type f -name '*.md' -print)
  if [ "$archive_md_count" -eq 0 ]; then
    fail "archive/ contains no Markdown snapshot files"
  else
    pass "archive/ contains $archive_md_count Markdown snapshot file(s)"
  fi
  for f in archive/README.md; do
    if [ -s "$ROOT/$f" ]; then pass "file: $f"; else fail "missing/empty: $f"; fi
  done
else
  skip "archive/ not installed; validating portable subset"
fi

section "JSON"
if command -v python3 >/dev/null 2>&1; then
  if python3 -m json.tool "$ROOT/templates/hooks.example.json" >/dev/null 2>&1; then
    pass "json: templates/hooks.example.json"
  else
    fail "json: templates/hooks.example.json"
  fi
else
  skip "python3 not found; JSON checks skipped"
fi

section "TOML"
if command -v python3 >/dev/null 2>&1; then
  if python3 - "$ROOT" <<'PY'
import pathlib
import sys
try:
    import tomllib
except ModuleNotFoundError:
    sys.exit(0)
root = pathlib.Path(sys.argv[1])
for name in ("mcp.example.toml", "plugins.example.toml"):
    with (root / "templates" / name).open("rb") as fh:
        tomllib.load(fh)
PY
  then
    pass "toml: templates/mcp.example.toml, templates/plugins.example.toml"
  else
    fail "toml templates parse"
  fi
else
  skip "python3 not found; TOML checks skipped"
fi

section "shell syntax"
for f in "$ROOT"/*.sh "$ROOT"/templates/*.sh; do
  [ -e "$f" ] || continue
  if bash -n "$f"; then pass "bash -n: ${f#"$ROOT"/}"; else fail "bash -n: ${f#"$ROOT"/}"; fi
done

section "curated skill installer"
if [ -x "$ROOT/templates/skill-install.example.sh" ]; then
  skill_repo="${VICCOM_SKILLS_REPO:-$ROOT/../..}"
  if [ ! -d "$skill_repo/skills" ]; then
    skip "skill repository not found at $skill_repo; installer dry-run skipped"
  elif bash "$ROOT/templates/skill-install.example.sh" --repo "$skill_repo" --dry-run >/dev/null 2>&1; then
    pass "skill-install.example.sh dry-run"
  else
    fail "skill-install.example.sh dry-run"
  fi
else
  fail "skill-install.example.sh is not executable"
fi

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
if [ -s "$ROOT/AGENTS.md" ]; then
  bytes=$(wc -c <"$ROOT/AGENTS.md")
  if [ "$bytes" -le 20000 ]; then pass "AGENTS.md size: ${bytes}B <= 20000B"; else fail "AGENTS.md size: ${bytes}B > 20000B"; fi
  lines=$(wc -l <"$ROOT/AGENTS.md")
  if [ "$lines" -le 240 ]; then pass "AGENTS.md lines: ${lines} <= 240"; else fail "AGENTS.md lines: ${lines} > 240"; fi
fi
for marker in '## 0.' '## 1.' '## 7.' '## 10.'; do
  if grep -qF "$marker" "$ROOT/AGENTS.md"; then pass "AGENTS.md section: $marker"; else fail "AGENTS.md missing section: $marker"; fi
done
if grep -qF 'AGENTS.override.md' "$ROOT/AGENTS.md" && grep -qF 'project_doc_max_bytes' "$ROOT/AGENTS.md"; then
  pass "AGENTS.md documents Codex discovery"
else
  fail "AGENTS.md missing Codex discovery details"
fi
if grep -n '^@' "$ROOT/AGENTS.md" "$ROOT/SEDS.md" >/dev/null 2>&1; then
  fail "AGENTS.md/SEDS.md contains ^@ import lines (Codex does not support imports)"
else
  pass "no ^@ import lines in policy/SEDS"
fi
if grep -RIn 'ai-memory' "$ROOT/AGENTS.md" "$ROOT/SEDS.md" "$ROOT"/guides/*.md "$ROOT"/templates/*.md >/dev/null 2>&1; then
  fail "portable policy/guides/templates mention ai-memory"
else
  pass "no ai-memory dependency in policy/guides/templates"
fi
if grep -RInE 'ZCode|zcode|最近一个|只加载最近' "$ROOT/AGENTS.md" "$ROOT/SEDS.md" "$ROOT"/guides/*.md >/dev/null 2>&1; then
  fail "wrong-host reference or nearest-only discovery claim found"
else
  pass "no wrong-host references or nearest-only discovery claims"
fi
if grep -RIn 'CLAUDE\.md' "$ROOT"/guides/*.md >/dev/null 2>&1; then
  fail "guides still target CLAUDE.md"
else
  pass "guides do not target CLAUDE.md"
fi
if [ -e "$ROOT/machine-profile.md" ] && [ "$IS_LIVE" -eq 0 ]; then
  fail "machine-profile.md must not be committed"
elif [ -e "$ROOT/machine-profile.md" ]; then
  pass "machine-profile.md allowed in live install"
else
  pass "no real machine-profile.md in package"
fi
if grep -qF 'codex debug prompt-input' "$ROOT/README.md" && grep -qF 'AGENTS.override.md' "$ROOT/README.md"; then
  pass "README documents Codex self-check"
else
  fail "README missing Codex self-check details"
fi

section "machine-specific data"
scan_paths=("$ROOT/AGENTS.md" "$ROOT/SEDS.md" "$ROOT/guides" "$ROOT/templates")
if [ -f "$ROOT/README.md" ]; then scan_paths+=("$ROOT/README.md"); fi
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
candidates = [root / "AGENTS.md", root / "SEDS.md", root / "README.md"]
for sub in ("guides", "templates", "archive"):
    candidates.extend(sorted((root / sub).rglob("*.md")))
for md in sorted({p for p in candidates if p.is_file()}):
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
