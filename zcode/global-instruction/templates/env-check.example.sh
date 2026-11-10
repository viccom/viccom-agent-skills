#!/usr/bin/env bash
# Generic environment health check template.
# Copy/adapt to your machine; checks are examples, not a complete audit.
# Usage: bash env-check.example.sh
set -u

fails=0

ok() { printf 'OK   %s\n' "$*"; }
warn() { printf 'WARN %s\n' "$*"; }
bad() {
  printf 'FAIL %s\n' "$*"
  fails=$((fails + 1))
}
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
cores=$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo '?')
ok "CPU cores: $cores"
if command -v timedatectl >/dev/null 2>&1; then
  ok "timezone: $(timedatectl show -p Timezone --value 2>/dev/null || echo unknown)"
else
  ok "timezone: $(date +%Z)"
fi
ok "locale: ${LANG:-unset}"
if command -v free >/dev/null 2>&1; then
  ok "memory: $(free -h | awk '/^Mem:/ {print $2}')"
else
  warn "memory: free not found"
fi
if command -v df >/dev/null 2>&1; then
  ok "disk (cwd): $(df -h . | awk 'NR==2 {print $4" free"}')"
fi

section "Shell"
ok "SHELL: ${SHELL:-unknown}"
if [ -f "$HOME/.zshenv" ]; then
  ok "$HOME/.zshenv exists"
else
  warn "$HOME/.zshenv missing (zsh non-interactive shells read it)"
fi
if [ -f "$HOME/.bashrc" ]; then
  ok "$HOME/.bashrc exists"
else
  warn "$HOME/.bashrc missing (bash interactive shells read it)"
fi
if have git; then
  ok "git: $(git --version)"
else
  bad "git not found"
fi

section "Toolchains"
check_tool() {
  local cmd="$1" label="${2:-$1}"
  if have "$cmd"; then
    ok "$label: $(command -v "$cmd")"
  else
    warn "$label not found"
  fi
}
check_tool rustc
check_tool cargo
check_tool go
check_tool java
check_tool mvn
check_tool node
check_tool npm
check_tool pnpm
check_tool python3
check_tool uv
check_tool ruff
check_tool just
check_tool gitleaks
check_tool shellcheck
check_tool shfmt

section "OpenSSL / native builds"
if have openssl; then
  ok "openssl: $(openssl version 2>/dev/null | cut -d' ' -f1-2)"
else
  warn "openssl not found"
fi
if have pkg-config; then
  if pkg-config --exists openssl; then
    ok "pkg-config openssl: $(pkg-config --modversion openssl)"
  else
    warn "pkg-config cannot find openssl (Rust openssl-sys may fail)"
  fi
else
  warn "pkg-config not found"
fi
for v in OPENSSL_DIR OPENSSL_LIB_DIR OPENSSL_INCLUDE_DIR; do
  if [ -n "${!v:-}" ]; then
    warn "$v is set; it may shadow system OpenSSL discovery"
  fi
done

section "Browser"
if [ -n "${CHROME_PATH:-}" ]; then
  if [ -x "$CHROME_PATH" ]; then
    ok "CHROME_PATH: $CHROME_PATH"
  else
    bad "CHROME_PATH is set but not executable: $CHROME_PATH"
  fi
else
  warn "CHROME_PATH not set (headless browser checks may not work)"
fi

section "Fonts"
if have fc-list; then
  n=$(fc-list :lang=zh 2>/dev/null | wc -l)
  if [ "$n" -gt 0 ]; then
    ok "Chinese fonts: $n"
  else
    warn "no Chinese font found; Web UI may fall back to a poor glyph set"
  fi
else
  warn "fontconfig (fc-list) not found"
fi

section "Skill roots"
for d in "$HOME/.zcode/skills" "$HOME/.agents/skills"; do
  if [ -d "$d" ]; then
    ok "$d: $(find "$d" -maxdepth 2 -name SKILL.md 2>/dev/null | wc -l) SKILL.md"
  else
    warn "$d missing"
  fi
done

section "ZCode global instruction"
for f in "$HOME/.zcode/AGENTS.md" "$HOME/.zcode/SEDS.md" "$HOME/.zcode/machine-profile.md" "$HOME/.zcode/validate.sh"; do
  if [ -s "$f" ]; then
    ok "$f"
  else
    warn "$f missing (optional unless you use the portable policy package)"
  fi
done
for d in "$HOME/.zcode/guides" "$HOME/.zcode/templates"; do
  if [ -d "$d" ]; then
    ok "$d"
  else
    warn "$d missing (optional; required only for full install)"
  fi
done

section "ZCode config"
cfg="$HOME/.zcode/cli/config.json"
if [ -f "$cfg" ]; then
  ok "config: $cfg"
  mode=$(stat -c '%a' "$cfg" 2>/dev/null || stat -f '%Lp' "$cfg" 2>/dev/null || echo '?')
  if [ "$mode" = "600" ]; then
    ok "config mode: 600"
  else
    warn "config mode: $mode (recommended 600)"
  fi
  if have python3; then
    if python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$cfg" >/dev/null 2>&1; then
      ok "config JSON parses"
    else
      bad "config JSON invalid"
    fi
  fi
else
  warn "config not found: $cfg"
fi

section "Result"
if [ "$fails" -eq 0 ]; then
  echo "PASS: no hard failures"
  exit 0
else
  echo "FAIL: $fails hard failure(s)"
  exit 1
fi
