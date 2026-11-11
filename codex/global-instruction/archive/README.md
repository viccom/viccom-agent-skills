# Archive：Codex 全局指令历史

本目录保留 Codex 全局指令体系建立前的状态，仅用于追溯。

- `pre-install-2026-11/state.md`：首次安装前的脱敏审计快照。

## 当前状态

建立本包前，`$CODEX_HOME` 下没有：

- `AGENTS.md`
- `AGENTS.override.md`
- `machine-profile.md`
- `skill-routing.md`

因此 Codex 的全局指令层当时为空；会话只加载项目根 `AGENTS.md`。本包是该全局层的首个可移植版本。

安装后本机状态：

- `$CODEX_HOME/AGENTS.md`：包内策略副本；
- `$CODEX_HOME/global-instruction/`：完整包；
- `$CODEX_HOME/machine-profile.md`、`skill-routing.md`：本机事实与技能路由；
- `~/.agents/skills/`：从本仓库软链的精选编程技能。

## 可移植版本

- `../AGENTS.md`：可移植全局策略；
- `../SEDS.md`：项目级 `AGENTS.md` 十四段式模板；
- `../guides/`：通用流程、排查与 Codex harness 观测指南；
- `../templates/`：机器 profile、Memories、MCP/hooks/plugins、技能路由、精选技能安装脚本、质量门禁、体检脚本；
- `../validate.sh`：包自检；
- `../README.md`：安装、自检、卸载说明。

## 维护

- 本目录不保存真实凭据或机器专属配置。
- 若以后有本机 live 全局文件需要追溯，可在此按日期保存脱敏快照；不要直接修改历史快照。
- 从 live 文件提炼可移植内容时，去掉主机名、路径、端口、账号、token 和日期化事故细节。
