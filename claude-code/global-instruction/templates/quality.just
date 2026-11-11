# 全局质量门禁模板 —— 项目 justfile 一行接入
#
# 安装：把本文件复制到项目可访问的位置，在 justfile 加：
#   import "<path-to>/templates/quality.just"
# 然后：
#   just quality
#
# 若项目已有同名 quality recipe，把本文件的 quality 改名为 quality-common，
# 或在项目里合并依赖，避免 just 重复 recipe 报错。
#
# 语义：严格默认——依赖工具缺失即失败，不静默跳过。
# 门禁基于 git 跟踪/暂存：新文件先 git add，否则不会被 secrets/shellcheck 覆盖。
# 门禁被跳过等于门禁不存在；确需临时放宽：QUALITY_LENIENT=1 just quality
#
# 项目自己的测试命令由项目 justfile 定义（通常是 just test）；
# 本模板只覆盖 secrets / shellcheck / git 三项通用检查。

set shell := ["bash", "-c"]

# 全套质量门禁：secrets + shell 脚本 + git 检查
[group('quality')]
quality: secrets shellcheck git-check
    @echo "quality: 全部门禁通过"

# 密钥泄露扫描：只扫暂存区，失败即失败，绝不回退到更弱/更宽的全量扫描。
# 先 git add 再跑门禁；未暂存的改动不在扫描范围。
# 旧版 gitleaks 用 protect，新版用 git --staged；两者都不可用则明确失败。
[group('quality')]
[private]
secrets:
    @set -euo pipefail; \
    if ! git rev-parse --git-dir >/dev/null 2>&1; then echo "(非 git 仓库，跳过 secrets)"; exit 0; fi; \
    if ! command -v gitleaks >/dev/null; then \
        if [ "${QUALITY_LENIENT:-0}" = "1" ]; then echo "WARN: gitleaks 未装，lenient 模式跳过"; exit 0; fi; \
        echo "FAIL: gitleaks 未装——门禁工具缺失即失败（用包管理器安装；临时放宽: QUALITY_LENIENT=1）"; exit 1; \
    fi; \
    if gitleaks protect --help 2>&1 | grep -q -- '--staged'; then \
        gitleaks protect --staged --redact -v; \
    elif gitleaks git --help 2>&1 | grep -q -- '--staged'; then \
        gitleaks git --staged --redact -v; \
    else \
        echo "FAIL: 当前 gitleaks 不支持 staged 扫描，请升级（不回退到全量历史扫描）"; exit 1; \
    fi

# shell 脚本静态检查（git 跟踪的 .sh / .bash；-z + xargs -0 防空格/换行文件名）
[group('quality')]
[private]
shellcheck:
    @set -euo pipefail; \
    if ! command -v shellcheck >/dev/null; then \
        if [ "${QUALITY_LENIENT:-0}" = "1" ]; then echo "WARN: shellcheck 未装，lenient 模式跳过"; exit 0; fi; \
        echo "FAIL: shellcheck 未装——门禁工具缺失即失败（用包管理器安装；临时放宽: QUALITY_LENIENT=1）"; exit 1; \
    fi; \
    if ! git rev-parse --git-dir >/dev/null 2>&1; then echo "(非 git 仓库，跳过 shellcheck)"; exit 0; fi; \
    n=$(git ls-files -- '*.sh' '*.bash' | wc -l); \
    if [ "$n" -gt 0 ]; then \
        git ls-files -z -- '*.sh' '*.bash' | xargs -0 shellcheck && echo "(shellcheck 通过)"; \
    else \
        echo "(无 shell 脚本，跳过)"; \
    fi

# 提交前检查：无 .env 入库、无未解决冲突标记
[group('quality')]
[private]
git-check:
    @set -euo pipefail; \
    if git rev-parse --git-dir >/dev/null 2>&1; then \
        bad_env=$(git ls-files | grep -E '(^|/)\.env($|\.)' | grep -vE '(^|/)\.env\.(example|sample|template)$' || true); \
        if [ -n "$bad_env" ]; then echo "FAIL: .env 已被 git 跟踪:"; printf '%s\n' "$bad_env"; exit 1; fi; \
        if git grep -qE '^(<<<<<<<|>>>>>>>)' -- .; then echo "FAIL: 存在未解决冲突标记"; exit 1; fi; \
    else \
        echo "(非 git 仓库，跳过 git 检查)"; \
    fi

# 格式化 shell 脚本（幂等）。非阻断 formatter，不属门禁——未装只提示
[group('quality')]
format-sh:
    @set -euo pipefail; command -v shfmt >/dev/null || { echo "WARN: shfmt 未安装（formatter 非门禁，跳过）"; exit 0; }; \
    if git rev-parse --git-dir >/dev/null 2>&1; then \
        n=$(git ls-files -- '*.sh' '*.bash' | wc -l); \
        if [ "$n" -gt 0 ]; then git ls-files -z -- '*.sh' '*.bash' | xargs -0 shfmt -i 2 -w; else echo "(无 shell 脚本，跳过)"; fi; \
    else \
        echo "WARN: 非 git 仓库，跳过 format-sh"; \
    fi
