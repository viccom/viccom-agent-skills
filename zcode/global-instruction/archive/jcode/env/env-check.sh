#!/usr/bin/env bash
# 环境体检脚本 —— jcode AI Coding 工作环境一键复查
# 用途: 改造后验收 / 环境漂移后复查 / 定期巡检
# 用法: bash ~/.jcode/env/env-check.sh [-v]
#   -v 输出各项明细(默认只输出汇总与异常项)
# 适配: 由 AI-Agent-Reasearch/Claude/linux-bootstrap/assets/env-check.sh 改造(Claude→jcode)
set -u

VERBOSE=0
[ "${1:-}" = "-v" ] && VERBOSE=1

PASS=0; FAIL=0; WARN=0
RED=$'\033[31m'; GREEN=$'\033[32m'; YEL=$'\033[33m'; DIM=$'\033[2m'; OFF=$'\033[0m'

ok()   { PASS=$((PASS+1)); if [ $VERBOSE -eq 1 ]; then printf "%s✅%s %s\n" "$GREEN" "$OFF" "$1"; fi; }
bad()  { FAIL=$((FAIL+1)); printf "%s❌%s %s\n" "$RED" "$OFF" "$1"; }
warn() { WARN=$((WARN+1)); printf "%s⚠️ %s %s\n" "$YEL" "$OFF" "$1"; }
section() { if [ $VERBOSE -eq 1 ]; then printf "\n%s── %s ──%s\n" "$DIM" "$1" "$OFF"; fi; }

# ── 1. 系统资源 ──
section "系统资源"
mem_mb=$(free -m | awk '/^Mem:/{print $2}')
disk_gb=$(df -BG / | awk 'NR==2{gsub("G","");print $4}')
if [ "$mem_mb" -ge 4000 ] 2>/dev/null; then ok "内存 ${mem_mb}MB ≥ 4GB"; else warn "内存 ${mem_mb}MB 偏低(<4GB, agent 并行受限, 本机 1.9G 属预期)"; fi
if [ "$disk_gb" -ge 30 ] 2>/dev/null; then ok "磁盘剩余 ${disk_gb}GB ≥ 30GB"; else warn "磁盘剩余 ${disk_gb}GB 偏低"; fi

# ── 2. 网络通道 ──
section "网络通道"
check_url() {
    local name=$1 url=$2 code
    code=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 4 -m 8 "$url" 2>/dev/null)
    case "$code" in
        200|301|302|403) ok "$name 可达 (HTTP $code)" ;;
        *) warn "$name 不可达 (HTTP ${code:-timeout})" ;;
    esac
}
check_url "github.com"   "https://github.com"
check_url "npm registry" "https://registry.npmjs.org"
check_url "pypi"         "https://pypi.org"
check_url "go proxy"     "https://proxy.golang.org"

# ── 3. CLI 工具链(与安装清单闭环)──
section "CLI 工具链"
# 核心(缺失=硬故障)
for t in git curl jq rg fd fdfind bat shellcheck gitleaks just yq; do
    if command -v "$t" >/dev/null 2>&1; then ok "$t"; else bad "核心工具 $t 缺失"; fi
done
# 增强(缺失=警告)
for t in gh delta eza duf zoxide gron shfmt tree python3 node npm go uv bun tmux; do
    if command -v "$t" >/dev/null 2>&1; then ok "$t"; else warn "可选工具 $t 未装"; fi
done
# 增强2(按项目按需, 缺失仅提示)
for t in actionlint golangci-lint tokei dust sd hadolint lazygit; do
    if command -v "$t" >/dev/null 2>&1; then ok "$t"; else warn "按需工具 $t 未装"; fi
done

# Go 必须是官方最新稳定版(用户硬规则, 2026-10-23)
go_cur=$(go version 2>/dev/null | awk '{print $3}' | sed 's/^go//')
go_latest=""
for api in 'https://go.dev/dl/?mode=json' 'https://golang.google.cn/dl/?mode=json'; do
    go_latest=$(curl -s --connect-timeout 4 -m 10 "$api" 2>/dev/null \
        | jq -r '[.[].version | select(test("^go[0-9]"))][0] // empty' 2>/dev/null | sed 's/^go//')
    [ -n "$go_latest" ] && break
done
if [ -z "$go_cur" ]; then
    bad "go 未安装(装最新稳定版: 官方 tarball → ~/.local/go)"
elif [ -z "$go_latest" ]; then
    warn "查不到 go.dev 最新稳定版(网络受限), 本机 go $go_cur 未校验"
elif [ "$go_cur" = "$go_latest" ]; then
    ok "go $go_cur = 官方最新稳定版"
else
    bad "go $go_cur 落后于官方最新稳定版 $go_latest(升级步骤见 ~/.zcode/AGENTS.md 工作环境段; 换主版本前先跑 Go 版本敏感的仓库测试)"
fi

# Rust 必须是官方最新稳定版(用户硬规则, 2026-10-23)
# 用 rustup run stable 取默认 toolchain 的版本, 避免被项目的 rust-toolchain.toml 覆盖后误报
rust_cur=$(rustup run stable rustc --version 2>/dev/null | awk '{print $2}')
rust_latest=""
for chan in 'https://mirrors.tuna.tsinghua.edu.cn/rustup/dist/channel-rust-stable.toml' \
            'https://static.rust-lang.org/dist/channel-rust-stable.toml'; do
    rust_latest=$(curl -s --connect-timeout 4 -m 10 "$chan" 2>/dev/null | awk '
        /^\[pkg\.rust\]/{f=1;next} /^\[/{f=0} f&&/^version/{gsub(/"/,"",$3); split($3,v," "); print v[1]; exit}')
    [ -n "$rust_latest" ] && break
done
if [ -z "$rust_cur" ]; then
    warn "未装 rustc(装最新稳定版: rustup update stable, 走 TUNA 镜像)"
elif [ -z "$rust_latest" ]; then
    warn "查不到 Rust 最新稳定版(网络受限), 本机 rustc $rust_cur 未校验"
elif [ "$rust_cur" = "$rust_latest" ]; then
    ok "rustc $rust_cur = 官方最新稳定版"
else
    bad "rustc $rust_cur 落后于官方最新稳定版 $rust_latest(升级: rustup update stable, 走 TUNA 镜像)"
fi

# openssl-sys 构建可发现性(2026-10-27 已装 libssl-dev 走 pkg-config 系统发现;
# 历史:当日上午曾依赖 ~/.local/toolchain-root + OPENSSL_* 注入,装包后按约定移除。
# 注意:OPENSSL_* 环境变量会遮蔽系统发现,残留时提示清理)
if pkg-config --exists openssl 2>/dev/null; then
    if [ -n "${OPENSSL_LIB_DIR:-}" ]; then
        warn "系统 libssl-dev $(pkg-config --modversion openssl) 已可用,但 OPENSSL_LIB_DIR=$OPENSSL_LIB_DIR 仍残留(遮蔽系统发现,头文件不随 apt 升级;清理 ~/.zshenv 与 ~/.profile 注入段)"
    else
        ok "openssl-sys 构建走系统发现: libssl-dev $(pkg-config --modversion openssl) (pkg-config)"
    fi
else
    bad "pkg-config 找不到 openssl——拉 openssl-sys 的 Rust 构建(reqwest 默认 native-tls、cargo install 源码编译)会失败。修复: sudo apt install libssl-dev(2026-10-27 曾装);或临时恢复 ~/.local/toolchain-root 注入(见 ~/.jcode/env/pitfalls.md 2026-10-27 条目)"
fi

# ── 4. LSP(本机内存受限, 按需; jcode 不依赖 LSP 插件, 缺失不硬失败)──
section "LSP 服务器"
for l in gopls pyright-langserver typescript-language-server rust-analyzer clangd; do
    if command -v "$l" >/dev/null 2>&1; then ok "$l"; else warn "LSP $l 未装(按需。老 Claude 环境的 LSP 插件已禁用, 无静默失败)"; fi
done

# ── 5. git 接线 ──
section "git 接线"
if [ "$(git config --global core.pager)" = "delta" ]; then ok "core.pager=delta"; else bad "delta 未接 git pager(装了等于没装)"; fi
if git config --global interactive.diffFilter >/dev/null 2>&1; then ok "diffFilter 已配置"; else warn "interactive.diffFilter 未配置"; fi
if [ "$(git config --global merge.conflictStyle)" = "zdiff3" ]; then ok "conflictStyle=zdiff3"; else warn "conflictStyle 未设为 zdiff3"; fi
if git config --global user.name >/dev/null 2>&1; then ok "git 身份已配置"; else warn "git user.name 未配置(提交前: git config --global user.name/user.email)"; fi
if [ -f "$(git config --global core.excludesfile 2>/dev/null)" ]; then ok "全局 gitignore 已配置"; else warn "全局 gitignore 未配置"; fi

# ── 6. 资产文件(规范/模板/门禁的引用完整性)──
section "资产文件"
for f in $HOME/AGENTS.md \
         $HOME/.jcode/env/SEDS.md \
         $HOME/.jcode/env/spec-driven-workflow.md \
         $HOME/.jcode/env/quality.just \
         $HOME/.jcode/env/pitfalls.md; do
    if [ -f "$f" ]; then ok "$f"; else bad "资产缺失: $f"; fi
done

# ── 7. jcode 环境健康 ──
section "jcode 环境"
if pgrep -f "jcode.*serve" >/dev/null 2>&1; then ok "jcode serve 运行中"; else warn "jcode serve 未运行(jcode serve 启动)"; fi
if [ -d "$HOME/.jcode/logs/memory" ] || [ -n "$(ls $HOME/.jcode/logs/memory-*.jsonl 2>/dev/null | head -1)" ]; then ok "jcode 记忆系统在写"; else warn "jcode 记忆目录未发现"; fi
# 老 Claude 环境失联 LSP 插件(历史病灶, 检测而非修复)
# 检测规则: 启用了插件 + 对应 language server 二进制缺失 → 死插件(静默失败)
if [ -f "$HOME/.claude/settings.json" ]; then
    dead_lsp=0
    for pair in "gopls-lsp:gopls" "pyright-lsp:pyright-langserver" "typescript-lsp:typescript-language-server" "clangd-lsp:clangd"; do
        plugin="${pair%:*}"; bin="${pair#*:}"
        if jq -e --arg p "$plugin" '.enabledPlugins[$p] // false' "$HOME/.claude/settings.json" >/dev/null 2>&1 \
           && [ "$(jq -r --arg p "$plugin" '.enabledPlugins[$p] // false' "$HOME/.claude/settings.json" 2>/dev/null)" = "true" ] \
           && ! command -v "$bin" >/dev/null 2>&1; then
            dead_lsp=$((dead_lsp + 1))
        fi
    done
    if [ "$dead_lsp" -gt 0 ] 2>/dev/null; then warn "老 ~/.claude 仍启用 $dead_lsp 个死 LSP 插件(gopls/pyright/typescript/clangd 中: 二进制缺失即静默失败; 处置见 ~/.jcode/env/pitfalls.md)"; else ok "老 ~/.claude 无死 LSP 插件"; fi
else
    ok "无老 Claude 环境"
fi

# ── 7.5 ai-memory 集成健康(2026-08-26 新增)──
section "ai-memory"
AIMEM_BIN="${AI_MEMORY_BIN:-$HOME/.local/bin/ai-memory}"
AIMEM_DATA="${AI_MEMORY_DATA_DIR:-$HOME/.local/share/ai-memory}"
if [ -x "$AIMEM_BIN" ]; then
    ver=$("$AIMEM_BIN" --version 2>/dev/null | head -1)
    ok "ai-memory 二进制($ver)"
else
    bad "ai-memory 二进制缺失(安装到 $AIMEM_BIN)"
fi
if [ -f "$AIMEM_DATA/config.toml" ]; then ok "ai-memory 数据目录配置存在"; else bad "ai-memory 数据目录未初始化(跑 ai-memory init)"; fi
if [ -f "$HOME/.jcode/mcp.json" ] && jq -e '.mcpServers["ai-memory"]' "$HOME/.jcode/mcp.json" >/dev/null 2>&1; then
    ok "ai-memory 已注册为 jcode MCP server"
else
    warn "ai-memory 未注册到 ~/.jcode/mcp.json(详见 notes/auto-record-engineering-gotchas.md)"
fi
if [ -x "$HOME/.local/bin/jcode-gotcha-reminder" ]; then ok "gotcha-reminder 钩子脚本就绪"; else bad "gotcha-reminder 钩子脚本缺失"; fi
if grep -q "jcode-gotcha-reminder" "$HOME/.jcode/config.toml" 2>/dev/null; then
    ok "turn_end 钩子已挂载到 jcode"
else
    warn "turn_end 钩子未挂载(模板 2 漏报率从 30% 降到 ~10% 的关键)"
fi
if grep -q "工程经验自动沉淀" "$HOME/AGENTS.md" 2>/dev/null; then
    ok "AGENTS.md 含 ai-memory 软提示段(模板 1)"
else
    warn "AGENTS.md 缺 ai-memory 软提示段(模板 1, 漏报率约 30%)"
fi
if [ -x "$HOME/.local/bin/ai-memory-stdio.sh" ]; then ok "stdio wrapper 就绪(密钥不入 mcp.json)"; else warn "stdio wrapper 缺失"; fi

# 模板 3 L3(2026-08-26 追加):fire-and-forget 写 auto-draft 页到 ai-memory HTTP
GOTCHA_HTTP="${GOTCHA_HTTP_ENDPOINT:-${JCODE_GOTCHA_HTTP_ENDPOINT:-http://127.0.0.1:49374/mcp}}"
if [ -f "$HOME/.jcode/state/gotcha-seen.sha" ] || [ -f "$HOME/.local/bin/jcode-gotcha-reminder" ]; then
    if grep -q 'memory_write_page' "$HOME/.local/bin/jcode-gotcha-reminder" 2>/dev/null && grep -q 'tools/call' "$HOME/.local/bin/jcode-gotcha-reminder" 2>/dev/null; then
        ok "gotcha-reminder 包含 L3 write_page 分支(模板 3 jcode 适配)"
    else
        warn "gotcha-reminder 缺 L3 write_page 分支(模板 2 only, 漏报率 ~10%)"
    fi
fi
# HTTP endpoint 不强求常驻, 给出"未启"提示而非警告(warn), 毕竟 observer fire-and-forget 会自动退避
# 用最小 POST + Content-Type(ai-memory HTTP 拒绝 415 if 缺)探活
http_code=$(curl -s --connect-timeout 2 -m 3 -o /dev/null -w '%{http_code}' "$GOTCHA_HTTP" \
  -H 'Accept: application/json, text/event-stream' \
  -H 'Content-Type: application/json' \
  -X POST -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"env-check","version":"0.0.1"}}}' 2>/dev/null)
if printf '%s' "$http_code" | grep -qE '200|202'; then
    ok "ai-memory HTTP server 在线 ($GOTCHA_HTTP, L3 可达)"
else
    warn "ai-memory HTTP server 未启于 $GOTCHA_HTTP(http=$http_code, L3 会静默退避; 启动: nohup ai-memory-stdio.sh serve --transport http --bind 127.0.0.1:49374 &)"
fi

# ── 8. 门禁冒烟测试(quality.just 真能跑)──
section "门禁冒烟"
if command -v just >/dev/null 2>&1; then
    if [ -f "$HOME/.jcode/env/quality.just" ]; then
        ok "quality.just 存在(项目 justfile import 后 just quality 可用)"
    else
        bad "quality.just 缺失"
    fi
else
    warn "just 未装, 门禁无法冒烟"
fi

# ── 汇总 ──
printf "\n%s════════ 体检汇总(共 %d 项)════════%s\n" "$DIM" "$((PASS+FAIL+WARN))" "$OFF"
printf "通过 %s%d%s  失败 %s%d%s  警告 %s%d%s\n" \
    "$GREEN" "$PASS" "$OFF" "$RED" "$FAIL" "$OFF" "$YEL" "$WARN" "$OFF"
if [ $FAIL -gt 0 ]; then
    printf "%s结论: 存在硬故障, 按上方 ❌ 项修复后再开始工作%s\n" "$RED" "$OFF"
    exit 1
elif [ $WARN -gt 0 ]; then
    printf "%s结论: 可正常工作, %d 个警告项酌情处理%s\n" "$YEL" "$WARN" "$OFF"
    exit 0
else
    printf "%s结论: 环境全绿%s\n" "$GREEN" "$OFF"
    exit 0
fi