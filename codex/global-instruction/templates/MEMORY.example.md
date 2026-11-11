# Codex Memories 模板说明

> Codex Memories **默认关闭**；本文件说明其结构与纪律，供启用后审计/整理参考。
> 不要把必须始终适用的团队规则放这里；规则放 `AGENTS.md` 或提交的文档。

## 启用

在 `$CODEX_HOME/config.toml`：

```toml
[features]
memories = true
```

常用设置：

```toml
[memories]
generate_memories = true
use_memories = true
disable_on_external_context = false
max_rollouts_per_startup = 16
max_raw_memories_for_consolidation = 256
extract_model = "<optional model>"
consolidation_model = "<optional model>"
```

线程内可用 `/memories` 控制当前线程是否使用/生成记忆；线程级选项不改全局设置。

## 存储位置

默认在 `$CODEX_HOME/memories/`（通常 `~/.codex/memories/`）。常见工件：

```text
memories/
├── MEMORY.md                 # 整理后的记忆主体
├── memory_summary.md         # 注入新会话的高信号摘要
├── raw_memories.md           # Phase 1 原始记忆的机械合并
├── rollout_summaries/        # 每个 rollout 的摘要与证据
└── extensions/               # 可选扩展/临时笔记
```

这些是**生成的系统状态**。排查/共享前可检查，但不建议手改；需要修正时用明确的 remember/forget/correct 请求，由 consolidation 处理。

## 读取路径

启用后，Codex 会把 `memory_summary.md` 作为 developer 段注入（受 8,900 bytes 上限约束）。模型应：

- 把 memory 当历史上下文，不当当前事实证明。
- 对有实质影响、可变化的结论检查当前实际源文件。
- 只在确实使用 rollout summary 时附 memory citation。
- 不把 `memory_summary.md` 本身作为引用来源。

## 写入纪律

- 不存代码库可推导的内容（架构、路径、既往修复）；不存 `AGENTS.md` 已写明的规则。
- 优先存稳定偏好、重复工作流、技术栈、项目规范、已知坑。
- 不存一次性讨论、助手提议、未确认的猜测。
- 生成记忆字段会做敏感信息脱敏，但共享 `$CODEX_HOME` 前仍要人工检查。
- 机器事实放 `machine-profile.md`，不进 memory。

## 审计

```bash
find "$CODEX_HOME/memories" -maxdepth 2 -type f -print 2>/dev/null | sort
sed -n '1,80p' "$CODEX_HOME/memories/memory_summary.md" 2>/dev/null
```

发现过期/冲突记忆时，优先修正源 rollout 或发 forget/correct 请求；不要用记忆覆盖当前用户指令或项目 `AGENTS.md`。
