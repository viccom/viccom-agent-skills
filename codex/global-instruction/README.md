# Codex 全局指令与模板

本目录是一套**可移植**的 Codex 全局指令包：策略、模板与指南分开，复制到其他电脑时只取需要的部分。

- 基线：Codex CLI 0.167.1；升级大版本后复核指令发现规则、模型 base instructions 与预算。
- 不依赖 MCP、Memories 或插件服务；没有它们也能工作。
- 不含 token、API key、密码。
- `$CODEX_HOME` 默认是 `~/.codex`；Windows 通常为 `%USERPROFILE%\.codex`。
- 安装命令以 Linux/macOS（或 WSL/Git Bash）为例；`validate.sh`、`templates/env-check.example.sh`、`templates/quality.just` 依赖 Bash/just。
- 预算：`AGENTS.md` 目标 ≤ 20,000 字节、≤ 240 行；由 `validate.sh` 强制。
- 与 ZCode / Claude Code 包同源异构：§0-§10 行为策略一致；发现规则、记忆、MCP/hooks/plugins 模板按 Codex 机制适配。差异集中在：`AGENTS.override.md`/`AGENTS.md` 全局优先级、root→cwd 项目链、32 KiB 项目预算、TOML 配置、Memories 默认关闭、Skill 目录预算。

> ⚠️ 覆盖前确认：`$CODEX_HOME/AGENTS.md` 若已做本机适配（记忆服务路由、机器路径、技能目录等），**不要**用本包的 `AGENTS.md` 直接覆盖它。本包给的是可移植策略；本机适配请自行合并，或把本包放在独立目录只作参考。

## 目录

```text
global-instruction/
├── AGENTS.md                 # 可移植全局策略（装到 $CODEX_HOME/AGENTS.md）
├── SEDS.md                   # 项目级 AGENTS.md 十四段式模板
├── README.md                 # 本文件
├── validate.sh               # 包自检：JSON/TOML/shell/链接/密钥/预算/门禁回归
├── guides/                   # 可移植流程、排查与 Codex harness 观测指南
│   ├── spec-driven-workflow.md
│   ├── workflow-conventions.md
│   ├── anti-rationalizations.md
│   ├── skill-authoring.md
│   ├── cross-compile-windows-rust.md
│   ├── network-mirrors-cn.md
│   ├── shared-machine-build-policy.md
│   ├── pitfalls-generic.md
│   └── codex-harness-inspection.md
├── templates/                # 可复制/可填写的模板
│   ├── machine-profile.example.md
│   ├── MEMORY.example.md
│   ├── mcp.example.toml
│   ├── hooks.example.json
│   ├── plugins.example.toml
│   ├── skill-routing.example.md
│   ├── skill-install.example.sh
│   ├── quality.just
│   └── env-check.example.sh
└── archive/                  # 仓库内的历史说明；安装时可省略
```

## 安装到另一台电脑

### 最小安装（只要行为约束）

```bash
mkdir -p "$CODEX_HOME"   # 默认 ~/.codex
cp AGENTS.md "$CODEX_HOME/AGENTS.md"
cp SEDS.md "$CODEX_HOME/SEDS.md"          # 可选；项目级模板
```

`AGENTS.md` 不依赖 `SEDS.md` 也能工作；`SEDS.md` 只在生成项目级 `AGENTS.md` 时参考。

### 完整安装（策略 + 模板 + 指南）

```bash
mkdir -p "$CODEX_HOME/global-instruction"
cp -r AGENTS.md SEDS.md README.md validate.sh guides templates archive "$CODEX_HOME/global-instruction/"
cp AGENTS.md "$CODEX_HOME/AGENTS.md"
ln -sfn "$CODEX_HOME/global-instruction/SEDS.md" "$CODEX_HOME/SEDS.md"
ln -sfn "$CODEX_HOME/global-instruction/README.md" "$CODEX_HOME/README.md"
ln -sfn "$CODEX_HOME/global-instruction/guides" "$CODEX_HOME/guides"
ln -sfn "$CODEX_HOME/global-instruction/templates" "$CODEX_HOME/templates"
ln -sfn "$CODEX_HOME/global-instruction/validate.sh" "$CODEX_HOME/validate.sh"
```

> `AGENTS.md` 用普通文件而不是软链，便于本机只读审计；如果希望跟随仓库更新，可改为软链，但要接受仓库改动直接影响 live 策略。
> Codex 不会自动加载 `guides/`、`templates/`；它们只在 `AGENTS.md` 指示时按需读取。
> 目标目录已有同名文件会被覆盖，先备份。

然后：

1. 复制 `templates/machine-profile.example.md` 为 `$CODEX_HOME/machine-profile.md`，填入本机事实；**不要提交含主机名/凭据的版本**。
2. 复制 `templates/skill-routing.example.md` 为 `$CODEX_HOME/skill-routing.md`，按本机技能填写；运行时 Skills 元数据优先。
3. 按需运行 `bash templates/skill-install.example.sh --repo <viccom-agent-skills> --dry-run` 预览精选编程技能，再去掉 `--dry-run` 软链到 `~/.agents/skills`。
4. 按需把 `templates/quality.just` 复制到项目可访问的位置，在项目 `justfile` 里 `import`。
5. 按需把 `templates/mcp.example.toml` / `hooks.example.json` / `plugins.example.toml` 的结构合并进 `$CODEX_HOME/config.toml` 或 `$CODEX_HOME/hooks.json`；替换占位符，配置文件 `chmod 600`。
6. 运行 `bash "$CODEX_HOME/templates/env-check.example.sh"` 做一次环境体检。

## 规则放哪里

Codex 的发现规则（0.167.1）：

- 全局：`$CODEX_HOME/AGENTS.override.md` → `$CODEX_HOME/AGENTS.md`，只取第一个非空文件。
- 项目：从项目根（默认 `.git` 等 marker）到 cwd 的每个目录，检查 `AGENTS.override.md` → `AGENTS.md` → `project_doc_fallback_filenames`；每个目录最多一个文件，root→cwd 顺序拼接。
- 预算：项目链总预算 `project_doc_max_bytes` 默认 32 KiB；超过后截断。
- Codex 的提示词发现不读 `CLAUDE.md`，不支持 `@import`，子目录规则不会懒加载。

| 规则类型 | 放置位置 | 是否自动进入上下文 |
|---|---|---|
| 跨项目行为底线 | `$CODEX_HOME/AGENTS.md` | 是，所有项目 |
| 项目构建/测试/架构 | 仓库根 `AGENTS.md` | 是，root→cwd 链 |
| 子目录模块规则 | 子目录 `AGENTS.md` 或同目录 `AGENTS.override.md` | 是，按 root→cwd 链 |
| 临时全局覆盖 | `$CODEX_HOME/AGENTS.override.md` | 是，优先于全局 `AGENTS.md` |
| 机器事实 | `$CODEX_HOME/machine-profile.md` | 由 `AGENTS.md` 指示按需读取 |
| 技能路由 | `$CODEX_HOME/skill-routing.md` | 由 `AGENTS.md` 指示按需读取 |
| 可复用流程 | Skill | 只注入 name/description/locator，正文按需 |
| 必须每次执行的行为 | hooks / sandbox / approval | 确定性门禁 |
| 外部系统访问 | MCP server | 工具 schema 注册，按需调用 |
| 长期项目决策 | 仓库 `docs/` / ADR | 由项目 `AGENTS.md` 指示按需读取 |
| 一次性要求 | 当前用户消息 | 是，当前轮 |

判断标准：这条规则放错层会让 Agent 更容易犯错吗？会就放对；不会就不写。

## 安装后自检

全局 `AGENTS.md` 在会话上下文构造时注入；Codex 检测到文件变化时可能通过 WorldState 发替换通知，但**以新会话或 `codex debug prompt-input` 的实际结果为准**。

```bash
test -s "$CODEX_HOME/AGENTS.md" && echo "AGENTS.md installed"
bash "$CODEX_HOME/global-instruction/validate.sh"   # 完整安装
bash "$CODEX_HOME/templates/env-check.example.sh"   # 环境体检
codex doctor --all
```

新开一个 Codex 会话，确认：

1. 问一个全局规则问题（如“§0 优先级表第一层是什么”），回答应体现新策略。
2. `codex debug prompt-input '列出你加载的指令来源'` 能看到全局与项目 `AGENTS.md` 的顺序。
3. 项目根/子目录 `AGENTS.md` 按 root→cwd 链加载；同目录 `AGENTS.override.md` 替换 `AGENTS.md`。
4. 放入 `CLAUDE.md` 不会被 Codex 提示词发现加载。

## 卸载/回滚

```bash
rm -f  "$CODEX_HOME/AGENTS.md" "$CODEX_HOME/AGENTS.override.md"
rm -f  "$CODEX_HOME/SEDS.md" "$CODEX_HOME/guides" "$CODEX_HOME/templates" "$CODEX_HOME/validate.sh"
rm -rf "$CODEX_HOME/global-instruction"
# machine-profile.md / skill-routing.md 是否删除由你决定
```

删除前确认这些路径没有你自己的内容；本包不覆盖 `$CODEX_HOME/AGENTS.md` 之外的全局配置。

## 不要安装

- 配置模板（`*.example.md` / `*.example.toml` / `hooks.example.json` 等）：不是可直接使用的配置；必须替换占位符后再合并。
- `templates/skill-install.example.sh` 是例外：它可直接运行，先加 `--dry-run` 预览。
- `archive/`：只在仓库内追溯；安装时可省略。
- 真实 `machine-profile.md` / `skill-routing.md`：含机器事实，不能进公共仓库。

## 维护

- `AGENTS.md` 是跨项目策略，**不要**把机器路径、技能目录、API key 写进去。
- 机器事实放 `machine-profile.md`（每台机器自己的，不进仓库）。
- 项目事实放项目级 `AGENTS.md`；流程细节放 `guides/`；可复制骨架放 `templates/`。
- live 更新配方：先改包内 `AGENTS.md` → 复制到 `$CODEX_HOME/AGENTS.md` → 保留本机 `machine-profile.md` / `skill-routing.md` → diff 确认只有预期变化。
- 变更后跑 `validate.sh`；再跑 8 个代表任务：读取全局规则、项目链/override、拒绝越权、完成门禁并报告证据、Skill 触发、Hook 门禁、MCP 路由、压缩后重定位。

## 安全

- 本目录不含 token、API key、密码。
- `AGENTS.md` 是**上下文不是强制配置**：必须硬性拦截的行为用 sandbox、approval、hooks 或质量门禁，不要指望提示词。
- hooks 是本地命令执行：从任何来源安装 hooks 前先审查命令与参数；非托管 hook 需审查/信任，项目级 hook 需项目 trust。
- 项目级 MCP 配置需要项目 trust；不要因为 clone 了仓库就自动信任并连接。
- 插件可贡献 Skill/MCP/App/hooks；启用前审查来源与权限。
- `model_instructions_file` 会替换模型内置 instructions，可能显著降低表现；除非明确知道影响，不要用它替代 `AGENTS.md`。
- 技能目录只占上下文约 2%、上限 10k tokens；不要一次软链整个 `skills/` 仓库。`skill-install.example.sh` 只安装精选集，遇到同名冲突会停止。
