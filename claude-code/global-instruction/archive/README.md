# Archive：原始机器文件快照

本目录保存改写前的本机 `~/.claude/CLAUDE.md` **原文**，仅用于追溯来源与对照。

**这些文件不是可移植配置，不要直接安装到其他电脑。**

- `claude-2026-11/CLAUDE.md`：2026-11-11 改写前的 live 全局指令（195 行旧版，含 `@RTK.md` import、四个原则、规则 5-13、工作环境、落地物与知识库、Agent Comms）。

它包含：

- 本机路径（`~/.claude/knowledge/`、`~/.claude/workflow/`、`~/.claude/quality/`）；
- 本机工具链约定（rg/LSP/ast-grep、fd/eza/jq/delta/just、补装渠道）；
- 本机技能路由的旧表述。

## 可移植版本

- `../CLAUDE.md`：可移植全局策略（§0-§10，机器内容已剥离）；
- `../SEDS.md`：项目级规范模板；`../guides/`、`../templates/`、`../validate.sh`、`../README.md`。

## 维护

- 不在这里直接修改；原始快照只读。
- 改写后如需追溯"旧版某条规则去了哪里"，对照 `../CLAUDE.md` 的 §0-§10 与本机 live 版 §11。
- 从原文提炼可移植内容时去掉主机名、路径、端口与日期化细节。
