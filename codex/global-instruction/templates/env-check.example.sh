#!/usr/bin/env bash
# Generic Codex environment health check template.
# Copy/adapt to your machine; checks are examples, not a complete audit.
# Usage: bash env-check.example.sh
set -u

fails=0
codex_home="${CODEX_HOME:-$HOME/.codex}"

ok() { printf 'OK   %s\n' "$*"; }
warn() { printf 'WARN %s\n' "$*"; }
bad() { printf 'FAIL %s\n' "$*"; fails=$((fails + 1)); }
section() { printf '\n== %s ==\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

section "OS / hardware"
if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  ok "OS: ${PRETTY_NAME:-unknown}"
else
  warn "OS: /etc/os-release not readable"
fi
ok "kernel: $(uname -r) ($(uname -m))"
ok "CPU cores: $(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo '?')"
ok "timezone: $(date +%Z)"
ok "locale: ${LANG:-unset}"
if have free; then ok "memory: $(free -h | awk '/^Mem:/ {print $2}')"; fi
if have df; then ok "disk (cwd): $(df -h . | awk 'NR==2 {print $4" free"}')"; fi

section "Shell"
ok "SHELL: ${SHELL:-unknown}"
for f in "$HOME/.zshenv" "$HOME/.bashrc"; do
  [ -f "$f" ] && ok "$f exists" || warn "$f missing"
done
have git && ok "git: $(git --version)" || bad "git not found"

section "Toolchains"
check_tool() {
  local cmd="$1" label="${2:-$1}"
  if have "$cmd"; then ok "$label: $(command -v "$cmd")"; else warn "$label not found"; fi
}
for cmd in rustc cargo go java mvn node npm pnpm python3 uv just gitleaks shellcheck shfmt rg jq; do
  check_tool "$cmd"
done

section "Codex"
if have codex; then
  ok "codex: $(codex --version 2>/dev/null | head -1)"
else
  bad "codex not found"
fi
if [ -d "$codex_home" ]; then ok "CODEX_HOME: $codex_home"; else bad "CODEX_HOME missing: $codex_home"; fi
for f in "$codex_home/config.toml" "$codex_home/AGENTS.md" "$codex_home/SEDS.md" "$codex_home/machine-profile.md" "$codex_home/skill-routing.md"; do
  [ -s "$f" ] && ok "$f" || warn "$f missing (optional unless you use the full policy package)"
done
for d in "$codex_home/global-instruction" "$codex_home/guides" "$codex_home/templates"; do
  [ -d "$d" ] && ok "$d" || warn "$d missing (optional; required only for full install)"
done
cfg="$codex_home/config.toml"
if [ -f "$cfg" ]; then
  mode=$(stat -c '%a' "$cfg" 2>/dev/null || stat -f '%Lp' "$cfg" 2>/dev/null || echo '?')
  [ "$mode" = "600" ] && ok "config mode: 600" || warn "config mode: $mode (recommended 600)"
  if have python3; then
    if python3 - "$cfg" <<'PY'
import sys
try:
    import tomllib
except ModuleNotFoundError:
    sys.exit(0)
with open(sys.argv[1], "rb") as fh:
    tomllib.load(fh)
PY
    then ok "config.toml parses"; else bad "config.toml invalid"; fi
  fi
fi
if [ -f "$codex_home/models_catalog.json" ] && have python3; then
  python3 -m json.tool "$codex_home/models_catalog.json" >/dev/null 2>&1 \
    && ok "models_catalog.json parses" || bad "models_catalog.json invalid"
  python3 - "$codex_home/models_catalog.json" <<'PYEOF'
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except Exception:
    raise SystemExit(0)
models = data.get("models", data if isinstance(data, list) else [])
missing = [m.get("slug", "?") for m in models if not m.get("include_skills_usage_instructions", False)]
if missing:
    print("WARN include_skills_usage_instructions is not true for: " + ", ".join(missing))
    print("WARN Codex will list skills but omit '### How to use skills'")
else:
    print("OK   all models enable include_skills_usage_instructions")
PYEOF
fi

section "Skills"
for d in "$HOME/.agents/skills" "$codex_home/skills"; do
  if [ -d "$d" ]; then
    ok "$d: $(find -L "$d" -maxdepth 3 -name SKILL.md 2>/dev/null | wc -l) SKILL.md"
  else
    warn "$d missing"
  fi
done

section "MCP / hooks / plugins"
if [ -f "$codex_home/hooks.json" ] && have python3; then
  python3 -m json.tool "$codex_home/hooks.json" >/dev/null 2>&1 \
    && ok "hooks.json parses" || bad "hooks.json invalid"
else
  warn "no hooks.json (optional)"
fi
if [ -f "$cfg" ] && have python3; then
  python3 - "$cfg" <<'PY'
import sys
try:
    import tomllib
except ModuleNotFoundError:
    sys.exit(0)
with open(sys.argv[1], "rb") as fh:
    data = tomllib.load(fh)
print("MCP servers:", len(data.get("mcp_servers", {})))
print("plugins:", len([k for k in data.get("plugins", {}) if k != "_default"]))
print("hooks:", len(data.get("hooks", {})))
PY
fi

section "Memories"
if have codex; then
  codex features list 2>/dev/null | awk '$1=="memories" {print "feature memories:", $2, $3}'
fi

section "Result"
if [ "$fails" -eq 0 ]; then
  echo "PASS: no hard failures"
  exit 0
else
  echo "FAIL: $fails hard failure(s)"
  exit 1
fi
