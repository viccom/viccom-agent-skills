# Codex 全局指令首次安装前状态（2026-11-11）

> 本文件是脱敏的审计快照，不是可安装配置。
> 只记录“当时有什么/没有什么”，不包含 token、完整主机名或机器专属端口。

## 全局层

建立 Codex 全局指令包之前，`$CODEX_HOME`（本机为 `~/.codex`）下没有：

- `AGENTS.md`
- `AGENTS.override.md`
- `machine-profile.md`
- `skill-routing.md`

因此 Codex 的全局指令层为空；会话只加载项目根 `AGENTS.md`。

## 已有内容（非本包）

`$CODEX_HOME` 当时已有：

- `config.toml`：模型 provider、模型、项目 trust、TUI 设置；
- `models_catalog.json`：自定义模型目录；
- `sessions/`、`state_*.sqlite`、`thread_history_*.sqlite` 等运行态；
- `skills/.system/`：Codex 随附的系统技能；
- 全局 `rules/default.rules`：命令前缀审批规则。

`~/.agents/skills/` 当时已有 6 个 `ai-memory-*` 技能；没有本仓库的语言/框架技能。

## 安装后

- 全局策略：`$CODEX_HOME/AGENTS.md`
- 完整包：`$CODEX_HOME/global-instruction/`
- 机器事实：`$CODEX_HOME/machine-profile.md`
- 技能路由：`$CODEX_HOME/skill-routing.md`
- 精选编程技能：从本仓库软链到 `~/.agents/skills/`

## 维护

- 本快照只读；后续变更不要回写这里。
- 需要新的审计快照时，按 `archive/<event>-<YYYY-MM>/` 新建目录并脱敏。
