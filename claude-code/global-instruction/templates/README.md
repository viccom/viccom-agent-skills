# templates/ — 模板说明

| 文件 | 用途 | 复制/合并去向 |
|---|---|---|
| `machine-profile.example.md` | 机器事实模板（硬件/shell/工具链/镜像/浏览器/技能根/MCP/hooks） | `~/.claude/machine-profile.md`，填入本机事实；**不要提交含主机名/凭据的版本** |
| `MEMORY.example.md` | Claude Code auto memory 结构与写入纪律说明（默认已开启，供人工审计参考） | 仅参考，不安装 |
| `mcp.example.json` | MCP 配置结构示例（项目 `.mcp.json` / 用户级 `claude mcp add`） | 结构参考；真实配置填占位符后落地，`0600`/不进库 |
| `hooks.example.json` | settings.json `hooks` 键的**合并片段**示例 | 合并进 `settings.json`，不是独立文件 |
| `plugins.example.json` | settings.json `enabledPlugins` 键的**合并片段**示例 | 合并进 `settings.json`，不是独立文件 |
| `quality.just` | 质量门禁（secrets/shellcheck/git 检查，严格模式） | 项目 `justfile` 加 `import "<path>/quality.just"`；或复制到 `~/.claude/quality/` |
| `env-check.example.sh` | 环境体检脚本模板 | 复制为 `~/.claude/knowledge/env-check.sh` 按本机增删检查项 |

## 使用规则

- 所有 `*.example.*` 都是模板：必须替换 `<...>` 占位符后才能用。
- token/API key 只放 `settings.json` 的 `env` 块或独立凭据文件（`0600`），不写进任何会提交的文件。
- `hooks.example.json` / `plugins.example.json` 是 settings.json 的合并片段——直接当独立配置放进去不会生效。
- hook 是本地命令执行：从任何来源安装 hooks 前先审查命令与参数；项目级 settings 的 hooks 需目录信任后才生效。
- 项目级 MCP 声明（`.mcp.json`）同样需要目录信任；不要因为 clone 了仓库就自动信任。
- `quality.just`：staged-only 密钥扫描、严格模式（缺工具即失败）；`QUALITY_LENIENT=1` 临时放宽。目标目录已有同名文件时先备份再改名合并。
- `machine-profile.md` 的解析顺序：与 `CLAUDE.md` 同目录 → `~/.claude/machine-profile.md`。

## 验证

```bash
bash -n env-check.example.sh        # shell 语法
python3 -m json.tool mcp.example.json >/dev/null && echo OK
python3 -m json.tool hooks.example.json >/dev/null && echo OK
python3 -m json.tool plugins.example.json >/dev/null && echo OK
just --justfile quality.just --list
```
