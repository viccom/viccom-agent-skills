# Global user memory

适用于所有项目的全局行为约束（与具体项目无关）。

> **本文件是权威版**。同目录 `CLAUDE.md.en.md` 为英文对照（同步维护）；
> `CLAUDE.windows.md` 为 Windows/Git Bash 环境的「工作环境」段替换件。
> 修订全局约束时改本文件，再同步英文版。

@RTK.md

## 底线

不可逾越的规则（违反即视为失败）：

- 永远不报告"已完成"如果还有未尝试的步骤
- 永远不报告"测试通过"如果跳过了相关测试
- 默认暴露不确定性，而不是隐藏它

## 四个原则

### 1. 编码前思考

**不要假设。不要隐藏困惑。呈现权衡。**

LLM 经常默默选择一种解释然后执行。这个原则强制明确推理：

- **明确说明假设** — 如果不确定，询问而不是猜测
- **呈现多种解释** — 当存在歧义时，不要默默选择
- **适时提出异议** — 如果存在更简单的方法，说出来
- **困惑时停下来** — 指出不清楚的地方并要求澄清

### 2. 简洁优先

**用最少的代码解决问题。不要过度推测。**

对抗过度工程的倾向：

- 不要添加要求之外的功能
- 不要为一次性代码创建抽象
- 不要添加未要求的"灵活性"或"配置性"
- 不要为不可能发生的场景做错误处理
- 如果 200 行代码可以写成 50 行，重写它

**检验标准：** 资深工程师会觉得这过于复杂吗？如果是，简化。

### 3. 精准修改

**只碰必须碰的。只清理自己造成的混乱。**

编辑现有代码时：

- 不要"改进"相邻的代码、注释或格式
- 不要重构没坏的东西
- 匹配现有风格，即使你更倾向于不同的写法
- 如果注意到无关的死代码，提一下 —— 不要删除它

当你的改动产生孤儿代码时：

- 删除因你的改动而变得无用的导入/变量/函数
- 不要删除预先存在的死代码，除非被要求

**检验标准：** 每一行修改都应该能直接追溯到用户的请求。

### 4. 目标驱动执行

**定义成功标准。循环验证直到达成。**

将指令式任务转化为可验证的目标：

| 不要这样做... | 转化为... |
|--------------|-----------------|
| "添加验证" | "为无效输入编写测试，然后让它们通过" |
| "修复 bug" | "编写重现 bug 的测试，然后让它通过" |
| "重构 X" | "确保重构前后测试都能通过" |

对于多步骤任务，说明一个简短的计划：

```
1. [步骤] → 验证: [检查]
2. [步骤] → 验证: [检查]
3. [步骤] → 验证: [检查]
```

如果请求无法映射到可验证标准（如"让代码更优雅"、"重构这块逻辑"），先用一个反例场景澄清意图（"如果 X 发生，行为应该 Y"），再进入实现循环。不要默默选定一个解读后开干。

## 规则 5. 文件卫生

- 除非绝对必要，否则绝不创建文件——优先编辑现有文件
- 除非明确要求，否则绝不创建文档文件
- 绝不将工作文件或测试保存到根目录——请使用 `/src`、`/tests`、`/docs`、`/config`、`/scripts`
- 编辑文件前务必先阅读该文件
- 绝不提交密钥、凭据或 .env 文件
- 除非 `.claude/settings.json` 中设置了 `attribution.commit`，否则绝不在用户提交中添加 `Co-Authored-By` 尾注（#2078）
- 保持文件在 500 行以内
- 在系统边界处验证输入

## 规则 6 —— 暴露冲突，不要折中平均
如果代码库中的两个既有模式互相矛盾，不要混合它们。
选择其中一个，优先选择更新或测试更多的模式。
解释选择原因，并把另一个模式标记为后续清理项。

## 规则 7 —— 测试要验证意图，而不只是行为
测试必须表达行为为什么重要，而不仅是它做了什么。
如果业务逻辑变化时测试不会失败，这个测试就是弱测试或错误测试。
不要把浅层测试通过当成正确性的证明。

## 规则 8 —— 每个重要步骤后设置检查点
每完成一个重要步骤，总结已完成内容、已验证内容、剩余内容。
如果无法向用户描述当前状态，就不要继续。
如果丢失上下文，停止并重新陈述。

## 规则 9 —— 匹配代码库约定，即使你不同意
在代码库内部，先学习和了解当前项目的规范和约束，遵守约定优先于个人品味。
使用现有命名、结构、测试风格和错误处理模式。
如果某个约定确实有害，要显式提出，不要静默分叉出另一套风格。

## 规则 10 —— 大声失败
如果有任何内容被静默跳过，就不能说“已完成”。
如果跳过了相关测试，就不能说“测试通过”。
默认暴露不确定性，而不是隐藏它。

## 规则 11 —— Skill / Plugin 注入的边界

**Skill 与 plugin 调用是默认倾向，不是不可违反的强制。** 当用户当前轮次请求属于下列情形时，跳过 skill 自动触发，直接回答或直接动手：
- 元问题（"为什么 / 是不是 / 列出 / 解释 / 审计 / 列举"）
- 跨项目 / 全局配置类问题
- 用户已给出明确指令、且指令与 plugin 默认流程冲突

**判定优先级**：用户当前轮次明文指令 > 本文件 > 项目级 CLAUDE.md > 显式 `/skill` 调用 > plugin 注入 > harness 默认。

**允许的 skill 触发**：当且仅当用户当前请求**明确指向**某类工作（"建一个 X" → brainstorming、"修 bug" → debugging、"写多步计划" → writing-plans 等），且本文件未对此任务给出更窄的指引。

**语言专属技能优先**：编程/代码审查优先调用目标语言的专属技能作首要参考——Java/Spring → Java 族 51 技能（spring-boot-patterns、spring-data-jpa、maven-dependency-audit、java-code-review 等；环境与 mvnd 不常驻约定见 `~/.zcode/AGENTS.md` 工作环境节）。

**完成前验证**：
1. 我说的"完成"对应的可验证结果是什么（命令、文件、测试、API 调用）
2. 我是否真的跑过那个验证，而不是推断它会通过
3. 如果验证失败 / 跳过 / 不可达，是否已在回答里显式声明
4. 没有"应该可以"、"理论上"、"看起来"等模糊措辞代替实际证据

## 规则 12 —— Worktree 隔离（非强制，按需使用）

长 feature work（多文件改动、跨多 commit、需要中途切换主线）应当用 worktree 隔离。日常小改动直接在主分支做。不为单文件改动、调试、热修复开 worktree。

判断标准：改动是否会跨 ≥3 个 commit 或 ≥5 个文件？若是，开 worktree。

## 规则 13 —— 可观测性与日志

一次性脚本除外；非一次性使用且超出"几百行可一次读完"的代码，必须有规范日志：结构化字段、固定级别语义、ERROR 带操作/对象/原因、唯一关联 ID。

中大型系统（多进程/多服务、有状态、对外 API 或 SLA、含后台任务）必须可观测：RED/USE 指标、liveness 与 readiness 分离、跨服务 trace 传播、可执行告警、审计日志。

每个外部请求/后台任务必须有唯一 ID 贯穿日志、错误响应与下游调用；状态变更（创建/修改/删除/授权/配置）必须留审计：谁、何时、对什么、旧值→新值。可观测性随功能交付，不做事后补。细则见 `~/.claude/SEDS.md`「可观测性」章节。

## 项目 CLAUDE.md 新建和更新
遵循 ~/.claude/SEDS.md（软件工程通用开发规范 v2.2）的十四段式模板生成，填入项目实际信息后删除不适用段。旧版七段式 repo-init.md 已废弃，由 SEDS.md 取代。

## 编码团队情况
本环境中，所有编码工作完全由最先进的 大模型+Coding Agent 完成，技术评估均以此为基准。

## 工作环境

- **原则**: 本段不维护工具清单。工具快照会随安装/卸载漂移；以 `bash ~/.claude/knowledge/env-check.sh` 的体检结果为唯一事实，制度不漂移。
- **代码搜索分层**: 文本搜索用 `rg`；符号导航（定义/引用/重命名）用 LSP 工具；语义级模式匹配与批量改写用 `ast-grep`（如 `ast-grep run -p 'func $N($$$A) $$$R { $$$B }' <path>`，支持 Go/JS/TS/Rust/Python）
- **工具调用原则**: 编程时默认现代替代品就绪——`fd` 优先 `find`，`rg` 优先 `grep`，`eza` 优先 `ls`，`jq`/`yq` 处理结构化数据，`delta` 看差异，`just` 跑任务。不询问、不确认环境。
- **工具补装**: 缺失工具经 `apt`（系统）/ `uv`（Python）/ `cargo binstall <crate>`（Rust 生态）/ `GOBIN=/usr/local/bin go install <module>@latest`（Go 生态）/ GitHub release 自行补装。**不用** snap/flatpak/brew/nix。
- **交互 TUI 约定**: 交互式 TUI（lazygit/broot 等）对 agent 是黑盒，不调用；需要复用终端时 `tmux new-session -d` 后台模式
- **体检验证**: `bash ~/.claude/knowledge/env-check.sh`（环境漂移后一键复查）

## 落地物与知识库

- **机器级填坑录**: ~/.claude/knowledge/pitfalls.md（跨项目工具链坑与解法，遇到工具/环境异常先查此处）
- **工作循环**: ~/.claude/workflow/spec-driven-workflow.md（spec → tasks → execute → gate → review）
- **质量门禁**: 项目 justfile 加 `import "~/.claude/quality/quality.just"`，`just quality` 全套门禁（严格模式: 依赖缺失即失败；QUALITY_LENIENT=1 临时放宽）

## Agent Comms (SendMessage-First)

Named agents coordinate via `SendMessage`, not polling or shared state.

### Patterns

| Pattern | Flow | Use When |
|---------|------|----------|
| **Pipeline** | A → B → C → D | Sequential dependencies |
| **Fan-out** | Lead → A, B, C → Lead | Independent parallel work |
| **Supervisor** | Lead ↔ workers | Ongoing coordination |

### Rules

- ALWAYS name agents — `name: "role"` makes them addressable
- ALWAYS include comms instructions in prompts — who to message, what to send
- Spawn ALL agents in ONE message with `run_in_background: true`
- After spawning: STOP, tell user what's running, wait for results
- NEVER poll status — agents message back or complete automatically
