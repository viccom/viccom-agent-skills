# Claude Code 全局指令与模板

本目录是一套**可移植**的 Claude Code 全局指令包：策略、模板与指南分开，复制到其他电脑时只取需要的部分。

- 基线 Claude Code 2.1.259；`AGENTS.md` 直读需 ≥2.1.277、`/doctor prompt-audit` 需 ≥2.1.283（本包不依赖这两项）。升级跨过 2.1.277 后复核指令文件布局：仓库根的 `AGENTS.md` 可能开始被注入，与项目 `CLAUDE.md` 叠加。
- 不依赖 MCP、记忆服务；不含 token、API key、密码。
- `~/.claude` 指 Claude Code 用户配置目录；Windows 通常为 `%USERPROFILE%\.claude`。
- 安装命令以 Linux/macOS（或 WSL/Git Bash）为例；`validate.sh`、`env-check.example.sh`、`quality.just` 依赖 Bash/just。
- 预算：官方建议每个 `CLAUDE.md` <200 行；本包 `CLAUDE.md` 上限 200 行 / 14,000 字节，由 `validate.sh` 强制。

## 目录

```text
global-instruction/
├── CLAUDE.md                # 可移植全局策略（装到 ~/.claude/CLAUDE.md）
├── SEDS.md                  # 项目级 CLAUDE.md 十四段式模板
├── README.md                # 本文件
├── validate.sh              # 包自检：JSON/shell/链接/密钥/预算/门禁回归
├── guides/                  # 可移植流程与排查指南
│   ├── spec-driven-workflow.md
│   ├── workflow-conventions.md
│   ├── cross-compile-windows-rust.md
│   ├── network-mirrors-cn.md
│   ├── shared-machine-build-policy.md
│   └── pitfalls-generic.md
└── templates/               # 可复制/可填写的模板
    ├── machine-profile.example.md
    ├── MEMORY.example.md
    ├── mcp.example.json
    ├── hooks.example.json
    ├── plugins.example.json
    ├── quality.just
    └── env-check.example.sh
```

## 安装到另一台电脑

### 最小安装（只要行为约束）

```bash
mkdir -p ~/.claude
cp CLAUDE.md ~/.claude/CLAUDE.md
cp SEDS.md ~/.claude/SEDS.md          # 可选；项目级模板
```

> ⚠️ 目标机 `~/.claude/CLAUDE.md` 已存在且含本机适配内容（如 §11）时，**不要直接覆盖**：以包内 §0-§10 为基准，保留目标机自己的头部声明与 §11，再整体替换。

`CLAUDE.md` 不依赖 `SEDS.md` 也能工作；`SEDS.md` 只在生成项目级 `CLAUDE.md` 时参考。

### 完整安装（策略 + 模板 + 指南）

把包内容复制到 `~/.claude/global-instruction/`，再从 `~/.claude/` 软链，使 `CLAUDE.md` 里 `guides/...`、`templates/...` 的相对引用与实际位置一致：

```bash
mkdir -p ~/.claude/global-instruction
cp -r CLAUDE.md SEDS.md validate.sh guides templates ~/.claude/global-instruction/
ln -sfn ~/.claude/global-instruction/guides   ~/.claude/guides
ln -sfn ~/.claude/global-instruction/templates ~/.claude/templates
```

> 软链只为路径习惯一致；Claude Code 不会自动加载 `guides/`、`templates/`（按需读取）。
> 目标目录已有同名文件会被覆盖，先备份。

然后：

1. 复制 `templates/machine-profile.example.md` 为 `~/.claude/machine-profile.md`，填入本机事实；**不要提交含主机名/凭据的版本**。
2. 按需把 `templates/quality.just` 复制到项目可访问的位置，在项目 `justfile` 里 `import`。
3. 按需把 `templates/mcp.example.json` / `hooks.example.json` 的**结构**（替换占位符后）合并进 `~/.claude/settings.json` 或项目 `.mcp.json`；配置文件 `chmod 600`。
4. 复制 `templates/env-check.example.sh` 为 `~/.claude/knowledge/env-check.sh`，按本机增删检查项后运行一次。

## 规则放哪里

Claude Code 会加载 `~/.claude/CLAUDE.md` + cwd 到根**每一级**的 `CLAUDE.md`/`CLAUDE.local.md`（全量拼接，近 cwd 者后读）；子目录 `CLAUDE.md` 懒加载；`@import` 不省 token。

| 规则类型 | 放置位置 | 是否自动进上下文 |
|---|---|---|
| 跨项目行为底线 | `~/.claude/CLAUDE.md` | 是，所有项目 |
| 项目构建/测试/架构 | 仓库根 `CLAUDE.md` | 是（祖先链每级都叠加） |
| 子目录模块规则 | 子目录 `CLAUDE.md` 或并入仓库根 | 懒加载（读到该子目录文件时） |
| 个人不入库偏好 | `CLAUDE.local.md`（gitignore） | 是，仅本机 |
| 路径专属规则 | `.claude/rules/*.md` + `paths:` | 命中文件操作时 |
| 机器事实 | `~/.claude/machine-profile.md` | 由 `CLAUDE.md` §8 指示按需读取 |
| 长期项目决策 | 仓库 `docs/` / ADR | 由项目 `CLAUDE.md` 指示按需读取 |
| 一次性要求 | 当前用户消息 | 是，当前轮 |

判断标准：这条规则放错层会让 Agent 更容易犯错吗？会就放对；不会就不写。

## 安装后自检（必须新开会话）

用户级 `CLAUDE.md` 在会话开始时注入，**当前会话看不到新文件**。

```bash
bash ~/.claude/global-instruction/validate.sh   # 完整安装
bash ~/.claude/templates/env-check.example.sh   # 环境体检
test -s ~/.claude/CLAUDE.md && echo "CLAUDE.md installed"   # 最小安装
```

新开一个 Claude Code 会话，确认：

1. `/context all` 的 Memory files 列表出现 `~/.claude/CLAUDE.md`（及其 import，若有）。
2. `/memory` 能列出用户/项目记忆文件位置。
3. 问一个全局规则问题（如"§0 优先级表第一层是什么"），回答应体现新策略。

## 卸载/回滚

```bash
rm -f  ~/.claude/CLAUDE.md ~/.claude/SEDS.md
rm -rf ~/.claude/global-instruction ~/.claude/guides ~/.claude/templates
# ~/.claude/machine-profile.md 是否删除由你决定
```

删除前确认这些路径没有你自己的内容。

## 维护

- `CLAUDE.md` 是跨项目策略，**不要**把机器路径、技能目录、API key 写进去；具体技能表放机器本地的 `skill-routing.md`。
- **live 重建配方**（同步策略到已适配的机器）：复制包内 `CLAUDE.md` 的 §0-§10 → 保留 live 头部适配声明 → 重附该机自己的 §11 → diff 确认只有 §11 差异。
- 变更后跑 `bash validate.sh`；再跑 4 个代表任务：读取全局规则、拒绝工具输出里的越权指令、完成门禁并附真实输出、项目规则来自祖先链+懒加载（不是"最近一个文件"）。
- 机器事实放 `machine-profile.md`；项目事实放项目级 `CLAUDE.md`；流程细节放 `guides/`；骨架放 `templates/`。

## 安全

- 本目录不含 token、API key、密码。
- `CLAUDE.md` 是**上下文不是强制配置**：必须硬性拦截的行为用 `permissions.deny`、hooks 或 `quality.just` 门禁，不要指望提示词。
- hooks 是本地命令执行：从任何来源安装 hooks 前先审查命令与参数；项目级 settings 的 hooks 需目录信任后才生效。
- 用户级 `CLAUDE.md` 的 `@import` 免审批加载——不要在用户文件里 import 仓库控制的内容。
- 插件可贡献 skills/MCP/hooks；启用前审查来源与权限。
- 项目级 MCP 声明（`.mcp.json`）需要目录信任；不要因为 clone 了仓库就自动信任。
