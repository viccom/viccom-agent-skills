# 全局质量门禁 —— 项目 justfile 一行接入（just ≥1.44 支持 import 的 ~ 展开，已在 1.57 实测）:
#   import "~/.claude/quality/quality.just"
# 之后 `just quality` 即全套检查。
#
# 语义: 严格默认——依赖工具缺失即失败，不静默跳过。
# 门禁被跳过等于门禁不存在；确需临时放宽: QUALITY_LENIENT=1 just quality

set shell := ["bash", "-c"]

# 全套质量门禁：secrets + shell 脚本 + git 检查
[group('quality')]
quality: secrets shellcheck git-check
    @echo "✅ quality: 全部门禁通过"

# 密钥泄露扫描（暂存区优先，回退全量）
[group('quality')]
[private]
secrets:
    @if ! git rev-parse --git-dir >/dev/null 2>&1; then echo "(非 git 仓库，跳过 secrets)"; exit 0; fi; \
    if ! command -v gitleaks >/dev/null; then \
        if [ "${QUALITY_LENIENT:-0}" = "1" ]; then echo "⚠️  gitleaks 未装，lenient 模式跳过"; exit 0; fi; \
        echo "❌ gitleaks 未装——门禁工具缺失即失败（安装: linux-bootstrap/setup.sh；临时放宽: QUALITY_LENIENT=1）"; exit 1; \
    fi; \
    gitleaks protect --staged --redact -v 2>/dev/null || gitleaks detect --redact -v

# shell 脚本静态检查（git 跟踪的 .sh / .bash，-z+xargs-0 防空格文件名）
[group('quality')]
[private]
shellcheck:
    @if ! command -v shellcheck >/dev/null; then \
        if [ "${QUALITY_LENIENT:-0}" = "1" ]; then echo "⚠️  shellcheck 未装，lenient 模式跳过"; exit 0; fi; \
        echo "❌ shellcheck 未装——门禁工具缺失即失败（安装: apt install shellcheck；临时放宽: QUALITY_LENIENT=1）"; exit 1; \
    fi; \
    if ! git rev-parse --git-dir >/dev/null 2>&1; then echo "(非 git 仓库，跳过 shellcheck)"; exit 0; fi; \
    n=$(git ls-files -- '*.sh' '*.bash' 2>/dev/null | wc -l); \
    if [ "$n" -gt 0 ]; then git ls-files -z -- '*.sh' '*.bash' | xargs -0 -r shellcheck && echo "(shellcheck 通过)"; else echo "(无 shell 脚本，跳过)"; fi

# 提交前检查：无 .env 入库、无未解决冲突标记
[group('quality')]
[private]
git-check:
    @if git rev-parse --git-dir >/dev/null 2>&1; then \
        if git ls-files | grep -qE '(^|/)\.env$'; then echo "❌ .env 已被 git 跟踪"; exit 1; fi; \
        if git grep -qE '^(<<<<<<<|>>>>>>>)' -- .; then echo "❌ 存在未解决冲突标记"; exit 1; fi; \
    else echo "(非 git 仓库，跳过 git 检查)"; fi

# 格式化 shell 脚本（幂等）。非阻断的 formatter，不属门禁——未装只提示
[group('quality')]
format-sh:
    @command -v shfmt >/dev/null || { echo "⚠️  shfmt 未安装（formatter 非门禁，跳过）"; exit 0; }
    @shfmt -w -l .
