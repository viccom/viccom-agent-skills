# Spec-Driven Workflow — 项目级 AI Coding 工作流

> 位置: ~/.jcode/env/spec-driven-workflow.md
> 用途: 新项目/新功能启动时套用此循环。全局指令文件指向此处。

## 核心循环

```
spec（写清可验证的验收标准）
  → tasks（拆为小任务，每个自带验证命令）
  → execute（小批量执行，无依赖任务可并行）
  → gate（just quality + 项目测试，全绿才算完成）
  → review（人审 diff，决定 merge）
```

原则:
- 每次只让 agent 处理少量任务——小批量是 Control，大批量是 Vibe
- 任务完成的定义是验证命令通过，不是"看起来对"
- AI 生成不等于入库，merge 决策永远在人

## 使用时机

- 新项目: 先做"项目初始化"，再进入循环
- 新功能/中型改动: 从 SPEC 开始
- 小 bug 修复: 直接修加测试，不套全流程，避免流程税

## 按项目规模选规范强度

- 小型(<1 万行,原型/工具/脚本): AGENTS.md/CLAUDE.md + just test。spec 用一节口头验收标准, 不立项
- 中型(1-10 万行,正式产品): 完整循环(spec/tasks/gate/review) + 按语言启用对应门禁
- 大型(>10 万行,多人协作): 中型全部 + 分层指令文件(根目录放全局边界, 子目录放模块细则) + 测试成为"能否继续改"的硬依据 + 技术债排期消化
- 深读: AI-Agent-Reasearch 的 golang/rust-architecture-by-code-size.md、ai-coding-agent-methodology.md 第五部分

## 项目初始化(新项目第一步)

1. AGENTS.md(jcode/Codex 读)或 CLAUDE.md(Claude Code 读): 按 ~/.jcode/env/SEDS.md 十四段式生成, 填项目实际信息; 取一为权威源并在两文件头注明
2. justfile: 加一行 `import "~/.jcode/env/quality.just"`, 之后 `just quality` 即全套门禁(just ≥1.44 支持 ~ 展开)

## SPEC 模板

复制到项目 `docs/spec-<功能>.md`, 逐项填写。不可验证的条目不算验收标准。

````markdown
# SPEC: <功能名>

- 日期: <YYYY-MM-DD> / 作者: <who> / 状态: draft | agreed | done

## 问题
要解决什么，为什么现在解决(2-5 句)

## 目标
- 可度量的结果，逐条列出

## 非目标
- 明确不做什么，防止范围蔓延

## 验收标准(必须可验证)
- [ ] <给定输入 X，行为应为 Y> — 验证: <命令或测试>
- [ ] ... — 验证: ...

## 约束
- 技术/性能/安全边界，依赖的既有模块

## 开放问题
- 未决项与决策时限
````

验收标准写法对照:
- 弱: "提升性能" → 强: "p95 延迟低于 200ms — 验证: just bench"
- 弱: "支持登录" → 强: "错误密码连续 5 次锁定 10 分钟 — 验证: tests/auth_test.go::TestLockout"

## TASKS 模板

复制到项目 `docs/tasks.md`, 与 spec 互相引用。每个任务自带验证命令。

````markdown
# TASKS: <功能名>(对应 docs/spec-<功能>.md)

- [ ] T1 <动词开头, 半天以内粒度>
      验证: <命令>
      依赖: 无
- [ ] T2 <...>
      验证: <命令>
      依赖: T1
- [ ] T3 <...>(P: 可与 T2 并行)
      验证: <命令>
      依赖: T1

## 完成定义
- 全部任务勾选 + just quality 通过 + spec 验收标准全绿 + 人审 diff
````

拆分原则:
- 一个任务等于一个可验证增量, 禁止"实现整个模块"式大任务
- 任务间依赖显式标注, 无依赖标 P 供并行
- 一批 2-4 个任务, 完成一批验收一批

## 执行模式

### 串行(默认)
逐任务: 实现 → 跑该任务验证命令 → just quality → git commit(原子提交, 一任务一提交)。

### 并行(无依赖任务多时)
- git worktree 隔离: `git worktree add ../<repo>-t2 -b feat/t2`, 各线独立, 完成后逐支 review 再 merge
- 或派 agent: 每任务一个会话/agent, 独立 worktree 工作, 完成即回报
- 收敛: 先完成者先 merge, 后完成者 rebase 后重过门禁

### 对话拆分(上下文卫生)
- spec 讨论 / 实现 / review 分不同会话, 避免上下文串味
- 实现会话只携带: AGENTS.md + spec + 当前任务

### 批量/夜间模式(可选)
- 白天: 写 spec、拆任务、review; 离开时让 agent 按 tasks.md 顺序执行独立任务, 每任务独立提交; 次日逐 commit review + 门禁, 不合格 revert 重做

## 门禁(gate)

每个任务提交前:
```
just quality    # gitleaks + shellcheck + git 检查(全局导入, 严格模式)
just test       # 项目测试(项目 justfile 定义)
```
两者全绿才算完成。门禁失败 → 修复 → 重跑。禁止跳过或放宽门禁让构建通过; 确需临时放宽 `QUALITY_LENIENT=1 just quality`, 并在交付说明中声明跳过了什么。

## 角色(人的位置)

- agent 是执行者: 写 spec 草稿、实现、自测
- 人是验收者: 定验收标准、审 diff、决定 merge
- 人的价值在判断——plausible 不等于 correct, agent 不会主动说"我不确定", 只有人能审出"自信的错误"