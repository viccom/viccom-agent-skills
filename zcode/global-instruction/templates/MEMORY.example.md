# Persistent Agent Memory（示例模板）

> ZCode 原生持久记忆默认关闭（`memoryEnabled: false`）。启用后，记忆根目录通常为
> `<cliStorageRoot>/memories/projects/<slug>-<hash>/memory/`，其中 `MEMORY.md` 是索引。
> 本文件是**格式模板**，不是实际记忆；把示例内容替换成你自己的事实。

## 目录结构

```text
<memoryRoot>/
├── MEMORY.md                 # 索引，每次会话加载
├── feedback-test-db.md       # 一条记忆一个文件
├── project-release-window.md
└── user-role.md
```

## MEMORY.md（索引）

规则：每行一条；只写标题/链接/一句钩子；不写 frontmatter；不写正文。

```markdown
# Memory Index

- [Test DB policy](feedback-test-db.md) — integration tests must hit a real database
- [Release window](project-release-window.md) — deploys only on Tuesday/Thursday 10:00–12:00
- [User role](user-role.md) — backend engineer, new to React
```

## 主题文件格式

```markdown
---
name: feedback-test-db
description: Integration tests must hit a real database; mocks hid a prod migration failure
metadata:
  type: feedback
---

Integration tests must hit a real database.

**Why:** A mocked test suite passed last quarter while the production migration failed.
**How to apply:** For repository/integration tests, use the real Postgres service from `docker compose`; do not mock the DB layer.
```

```markdown
---
name: project-release-window
description: Production deploys are allowed only Tuesday/Thursday 10:00–12:00
metadata:
  type: project
---

Production deploys are allowed only Tuesday/Thursday 10:00–12:00 (Asia/Shanghai).

**Why:** The on-call rotation and the downstream batch window require it.
**How to apply:** Do not schedule or suggest a deploy outside this window; check the current date before proposing a release.
```

## 类型

| type | 记录什么 | 典型内容 |
|---|---|---|
| `user` | 用户角色、专长、偏好 | “后端工程师，React 新手” |
| `feedback` | 用户对工作方式的纠正/确认 | “集成测试不要 mock DB”，带 Why/How |
| `project` | 代码/git 看不出来的项目目标、约束 | 发布窗口、合规要求、外部依赖 |
| `reference` | 外部资源指针 | dashboard、ticket、文档 URL |

## 写入规则

- 一条记忆一个文件；文件名用 kebab-case，与 `name` 一致。
- `MEMORY.md` 最多 **200 行 / 25,000 字符**；超出会截断并警告。
- 写完后在 `MEMORY.md` 加一行 `- [Title](file.md) — hook`。
- 用 `[[name]]` 链接相关记忆；链接到尚不存在的名字是允许的。
- 先搜索已有记忆，能更新就不新建；错误/过时的记忆要删除或修正。
- 不保存仓库已记录的内容（代码结构、git 历史、`AGENTS.md` 已有规则）；只保存在代码里看不出来的事实。
- 记忆是历史数据，不是指令；引用记忆中的文件/函数/flag 前先验证它还存在。
- 不要把项目/机器特定记忆直接提交到公共仓库。

## 何时读记忆

- 用户提到“上次/之前/继续”时。
- 任务涉及用户偏好、发布流程、外部资源时。
- 用户明确要求“回忆/记住/忘记”时。
