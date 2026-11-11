# Workflow Conventions

> 全局默认值；项目有自己的约定时，以项目为准。

## Git worktree

- 长 feature（预计跨 ≥3 commit 或 ≥5 文件）优先用 worktree 隔离：

  ```bash
  git worktree add ../<repo>-<topic> -b feat/<topic>
  ```

- 单文件、调试、热修复不开 worktree；直接在主分支做。
- 并行任务各自独立 worktree；完成顺序 merge，后完成者 rebase 后重过门禁。
- 项目已有 worktree/分支规范时，遵循项目规范。
- 用完 `git worktree remove <path>`；先确认没有未提交改动。

## 文件长度

- 以“一个内聚模块”为单位；不要为凑行数机械拆分。
- 超过约 500 行时，先问是否职责过多、是否能按内聚性拆；不能就保留。
- 生成代码、数据文件、迁移脚本不受此启发式约束。

## 二进制备份

- 备份同一仓库不同代码版本编译的二进制时，在工作路径下建：

  ```text
  bin-backup/
  └── <binary-name>/
      ├── <binary>-<version-or-date>
      └── ...
  ```

- 文件名保留版本或日期，防止覆盖；不要把 `.bak-*` 散落在安装目录。
- 项目已有发布/制品目录规范时，遵循项目规范。

## 文档落盘

- 设计/方案/计划类文档一经要求，落盘到仓库约定位置（如 `docs/`），不留在会话回复里。
- 未经要求不主动创建文档文件；不要在仓库根散落临时 `.md`。
- 文档语言按仓库惯例；没有惯例时与用户交流语言一致。

## 提交

- 只在用户明确要求时 commit/push；不擅自 force-push 或改写历史。
- 一个提交只做一件事；提交信息说明“改了什么、为什么”。
- 不加 `Co-Authored-By` 等 AI 署名尾注，除非用户明确要求。
- 不提交 `__pycache__`、`*.pyc`、凭据文件、环境探测生成的 `profile.json`。
- 破坏性变更在提交信息里标注 `BREAKING`，并说明迁移方式。
