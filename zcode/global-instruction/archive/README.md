# Archive：原始机器记忆快照

本目录保存从本机 ai-memory 全局 profile 与 `~/.jcode/env/` 复制的**原文**，仅用于追溯来源与对照。

**这些文件不是可移植配置，不要直接安装到其他电脑。**

- `ai-memory/profile/env/*`、`profile/ops/*`：本机 ai-memory 全局 profile 页。
- `jcode/env/*`：本机 jcode 环境文档、体检脚本、坑录、质量门禁模板、SEDS 副本。

它们包含：

- 本机主机名、路径、端口、工具链版本；
- 共享机资源约束、镜像配置、浏览器/字体路径；
- 1Panel/warden 等站点或进程守护事实；
- 可能过期的日期化条目。

## 可移植版本

需要跨机使用的版本已整理到：

- `../AGENTS.md`：可移植全局策略；
- `../SEDS.md`：项目级规范模板；
- `../guides/`：通用流程与排查指南；
- `../templates/`：机器 profile、记忆、MCP/hooks、质量门禁、体检脚本模板；
- `../validate.sh`：包自检（JSON/shell/链接/密钥/门禁回归）；
- `../README.md`：安装、自检、卸载说明。

## 维护

- 不在这里直接修改；原始快照只读。
- 如果上游（ai-memory/jcode）更新，重新复制并保留旧版本或记录差异。
- 从这些原文提炼可移植内容时，去掉主机名、路径、端口、账号、token 和日期化事故细节。
