# 本机技能路由快照（示例模板）

> 本机专用，不属于可移植包。复制为 `$CODEX_HOME/skill-routing.md`，按实际安装填写。
> 具体可用技能以运行时 Skills 元数据为准；新增/删除后更新本文件与 `machine-profile.md`。

## 语言 / 框架

| 语言/框架 | 已安装路由 | 备注 |
|---|---|---|
| Rust | `<rust-skills, rust-best-practices, rust-router, ...>` | `<scope/limits>` |
| Python | `<modern-python, ruff, ...>` | `<scope/limits>` |
| Go | `<golang-*>` | `<scope/limits>` |
| Node/TS | `<node, typescript-magician, ...>` | `<scope/limits>` |
| Vue | `<vue, pinia, vitest, vite, unocss, ...>` | `<scope/limits>` |
| Java/Spring | `<spring-*, java-*, ...>` | `<scope/limits>` |

- 技能未覆盖：退回项目约定 + 官方文档，不硬套不存在的技能。
- 不硬编码技能目录：本表是快照，运行时元数据优先。

## 研发流程

| 场景 | 优先 Skill | 备注 |
|---|---|---|
| bug / 测试失败 | `<systematic-debugging>` | 先根因再修复 |
| 声称完成前 | `<verification-before-completion>` | 对应完成定义 GATE |
| 多步计划 | `<writing-plans>` | 跨会话执行用 `<executing-plans>` |
| 功能/修复 | `<test-driven-development>` | 测试先行 |

## 前端 / UI

同一轮只选一个“设计方向”技能；按任务选一个主技能，其余只做审计/查询。

| 场景 | 优先 Skill | 备注 |
|---|---|---|
| 新建/重设计整页 | `<frontend-design / hallmark>` | 方向与文案 |
| 已有产品界面自检 | `<design-taste-frontend>` | 浏览器量测/截图 |
| UI 合规审计 | `<web-design-guidelines>` | 输出 `file:line` |
| 设计知识库 | `<ui-ux-pro-max>` | 建议不覆盖项目约束 |
| 设计 token | `<design-system>` | 硬编码扫描 |

## 运维 / 工具

| 场景 | 优先 Skill | 备注 |
|---|---|---|
| 1Panel | `<1panel-ops>` | 探测先行；破坏性操作先确认 |
| 文档/办公 | `<officecli>` | — |
