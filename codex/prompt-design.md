# Codex 提示词体系设计

> 版本基线：Codex CLI **0.167.1**（`codex-cli 0.167.1`；源码 tag `rust-v0.167.1`，检出 commit `0a94398fa60c4fac0e7659e4213a0a36e613dd46`）
> 调研日期：2026-11-11
> 适用范围：本机 Codex CLI 0.167.1、`wire_api = "responses"` 的模型 provider，以及本机自定义模型目录。其他版本、其他 provider 或其他客户端可能调整角色映射、工具装配与缓存行为。

本文描述 Codex 在一次模型请求中如何组织上下文：模型自带的 base instructions、配置注入的 developer instructions、`AGENTS.md`、world-state 指令与上下文、Skill、MCP、Hooks、Plugins、Subagents、Memories、Compaction 与 Prompt Caching。文中“已确认”指从本机运行态、本机安装物或固定源码 tag 直接读到；“推断”指代码路径清楚但本次未实际触发；“未知”单独列出。

Codex 与 ZCode、Claude Code 最大的区别是：它没有一份跨模型固定的“大 system prompt”。**base instructions 由模型目录提供，工具定义单独传递，其余上下文由 `WorldState` section 逐轮做增量 diff。** 只读文档或只抓首轮请求，很容易把其中两层误认为一层。

| 章 | 内容 |
|---|---|
| 0 | 证据等级与调研方法 |
| 1 | 总栈：一次请求里的三层 |
| 2 | 内置提示词与配置注入 |
| 3 | 指令文件体系（AGENTS.md） |
| 4 | 记忆体系（Memories） |
| 5 | Skill 体系 |
| 6 | MCP 体系 |
| 7 | Hooks、Plugins、Subagents、Compaction、Caching |
| 8 | 设计原则总结 |
| 9 | 本机验证快照（2026-11-11） |
| 10 | 已知未知与验证方法 |
| 11 | Harness 设计检查清单 |
| 附录 | 常量、证据索引、复现命令 |

## 0. 证据等级与调研方法

| 标记 | 含义 | 本文中的典型来源 |
|---|---|---|
| **[A]** | 从固定版本源码直接确认 | `openai/codex` tag `rust-v0.167.1` 的 Rust 源码、模板、常量 |
| **[B]** | 从本机运行态直接确认 | `codex --version`、`codex doctor`、`codex debug prompt-input`、`~/.codex/models_catalog.json`、rollout JSONL |
| **[C]** | 官方文档明确，但未在本机逐项触发 | `developers.openai.com/codex/*`、Responses API prompt caching 文档 |
| **[D]** | 未确认 | provider/gateway 的角色映射、服务端缓存命中、未触发的特性组合 |

固定版本源码树：

```text
openai/codex @ rust-v0.167.1
└── codex-rs/
    ├── protocol/src/prompts/base_instructions/default.md
    ├── core/src/context/world_state/
    ├── core/src/session/
    ├── core/src/compact.rs
    ├── core/src/hook_runtime.rs
    ├── prompts/src/
    ├── ext/skills/src/
    ├── ext/memories/
    ├── codex-mcp/src/
    └── memories/
```

本机安装物：

```text
codex --version
# codex-cli 0.167.1

~/.nvm/versions/node/v24.21.0/lib/node_modules/@openai/codex/
└── node_modules/@openai/codex-linux-x64/vendor/x86_64-unknown-linux-musl/bin/codex
    # 320,186,856 bytes, static-pie linked, stripped
```

运行态证据：

```text
~/.codex/config.toml
~/.codex/models_catalog.json
~/.codex/sessions/<date>/rollout-*.jsonl
~/.codex/state_5.sqlite
~/.codex/thread_history_1.sqlite
```

`codex debug prompt-input` 是一个高价值入口：它把当前会话将要发送的 **input 列表** 渲染成 JSON。它不包含 base instructions 与完整工具的 wire 表示，因此必须和 `codex debug models`、源码里的 `build_prompt` / `build_responses_request` 交叉验证。

本文区分两个概念：

- **wire role**：Responses API 输入项上的 `role`，例如 `developer`、`user`。
- **provenance**：`ContentItemMetadata` 中的来源分类，例如 `AgentsMd`、`Skills`、`Harness { hook: true }`、`Tool`、`User`。

Codex 的权威语义更多由 provenance 与 section 决定，而不是只看 role。把 role 当作者身份，会误判 `AGENTS.md`、Skill 正文和 hook 输出的信任等级。

## 1. 总栈：一次请求里的三层

### 1.1 三层模型

Codex 0.167.1 的一次模型请求由三块组成：

| 层 | 内容 | 传递位置 | 变化频率 |
|---|---|---|---|
| Base instructions | 模型自带的完整 agent 规则 | `input` 最前面的 `BaseInstructionsFragment`（wire role = `developer`） | 模型或配置变化时 |
| Developer/user context | world-state 生成的权限、协作模式、`AGENTS.md`、环境、Skill 清单、插件说明等 | `input` 中的 developer/user message | 每轮可增量变化 |
| Tools | 内置函数、MCP 工具、Web Search、协作工具等 schema | Responses 请求的 `tools` 数组；Responses Lite 下改为 `AdditionalTools` 输入项 | 工具集合或 schema 变化时 |

推理参数、输出 schema、service tier、缓存键等属于请求控制面，不是提示词文本：

```text
model
stream = true
store = false
tool_choice = "auto"
parallel_tool_calls = true
reasoning = { effort, summary }
include = ["reasoning.encrypted_content", ...]
prompt_cache_key = <session-derived>
text = { verbosity?, format? }
```

### 1.2 请求结构

普通模型（非 Responses Lite）的请求大致是：

```text
ResponsesApiRequest {
  model,
  input: [
    developer(message, content=[base instructions]),       // model.base_instructions
    developer(message, content=[skills catalog, permissions, collaboration mode, ...]),
    user(message, content=[AGENTS.md instructions, environment context]),
    user(message, content=[actual user prompt]),
    ...
  ],
  tools: [ ... ],
  ...
}
```

Responses Lite 模型则把顶层工具目录转成 `AdditionalTools` 输入项，并把 `tools` 字段收缩为仅保留 hosted tools（例如 Web Search）。这也是为什么同一份对话在不同模型上看起来“工具出现了两次”或“工具不在 tools 数组里”。

### 1.3 装配链路

核心链路（简化）[A]：

```text
Session::build_world_state_for_step
  -> 生成有序 WorldState sections
Session::build_initial_context_with_world_state
  -> render_full / render_history_diff
  -> 把 developer fragments 合并成 developer message
  -> 把 user fragments 合并成 user message
  -> 保留 standalone developer items
ContextManager::for_prompt
  -> 转成模型可读 ResponseItem
Session::build_prompt
  -> prompt.input / prompt.tools / prompt.base_instructions
ModelClientSession::build_responses_request
  -> 若 base_instructions 非空，prepend BaseInstructionsFragment
  -> 生成 ResponsesApiRequest
```

`build_initial_context_with_world_state` 里有一个容易忽略的细节：**同一轮里连续的 developer fragment 会合并成一条 developer message，连续的 user fragment 会合并成一条 user message**；只有标记为 `Standalone` 的段（例如 token-budget context、部分多代理角色说明、guardian policy）才单独成条。

### 1.4 全量上下文与增量 diff

Codex 的 `WorldState` 不是“每轮重新拼一遍大 prompt”，而是：

```text
WorldState {
  sections: IndexMap<stable_id, WorldStateSection>
}
```

每个 section 有：

```text
stable ID
Snapshot 类型
render_diff(previous) -> (new_snapshot, updates)
```

首次请求、新 context window、压缩后的 replacement history 使用 `render_full()`；之后的轮次使用 `render_history_diff()`。每个 section 的 snapshot 会写进 rollout 的 `WorldStateItem`，缺 snapshot 时重新全量渲染，存在但旧 fragment 被裁掉时也会重新渲染。

这带来两个直接结果：

- **未变化的段不会重复出现。** 例如 `AGENTS.md` 未变时，不会每轮再发一遍。
- **变化的段以“替换通知 + 新内容”出现。** 例如 `AGENTS.md` 改变时会写明 “These AGENTS.md instructions replace all previously provided AGENTS.md instructions.”；环境 cwd 改变时只 diff 变化的环境。

### 1.5 为什么不是一个大 system prompt

1. **模型差异**：base instructions 由模型目录提供，GPT-6、GPT-5.5、自定义 DeepSeek 的 prompt family 不同。
2. **缓存友好**：稳定 base 在前，变化 context 以新消息追加；不必每轮重写前缀。
3. **可观测**：section 有稳定 ID 与 snapshot，rollout 可审计“这轮实际新增了什么”。
4. **可裁剪**：Skill 清单、MCP namespace、环境、权限各自有预算，不靠整体重写。
5. **失败隔离**：单个 Skill/MCP/插件异常不会让整段提示词消失。

### 1.6 与 ZCode / Claude Code 的关键差异

| 维度 | Codex 0.167.1 | ZCode 3.17.2 | Claude Code 2.1.322 |
|---|---|---|---|
| 身份/base prompt | 模型目录的 `base_instructions` / `model_messages.instructions_template` | bundle 内固定身份段 | bundle 内固定 section + 模型 traits |
| 指令文件 | `AGENTS.md`，项目根→cwd 逐目录拼接 | 全局 + 最近一个 workspace `AGENTS.md` | 祖先链 `CLAUDE.md`/`AGENTS.md` 全链 + 子目录懒加载 |
| 动态 context | `WorldState` section + diff | section + stable/dynamic 注入 | system prompt + `<system-reminder>` |
| Skill 清单 | developer `<skills_instructions>`，默认约 2% 上下文 | meta_user 技能段，约 20KB | system/attachment 技能清单 |
| MCP 指令 | 作为 tool namespace description，不是独立全局块 | 部分进提示词、部分工具注册 | 独立 `# MCP Server Instructions` 块 |
| 压缩 | 独立 summarization prompt + replacement history | 原生 compaction | 独立 compact + 摘要 |
| 缓存 | Responses API 自动缓存 + `prompt_cache_key` | `cache_control: ephemeral` | `cache_control` 断点，1h TTL |

## 2. 内置提示词与配置注入

### 2.1 模型目录决定 base instructions

base instructions 的解析优先级 [A]：

1. `config.base_instructions`（代码/宿主配置）
2. 会话历史中的 `session_meta.base_instructions`
3. 当前模型的 `instructions_template`

源码里的 `render_model_instructions` 不做模板展开、不做 section 拼接，它就是取模型目录中的字面文本。若模型既没有 `base_instructions`，也没有 `model_messages.instructions_template`，会返回空字符串并告警。

因此，“Codex 的 system prompt 是什么”这个问题没有单一答案。必须先确定模型。

### 2.2 两个明显的 prompt family

本机 `codex debug models` 暴露了不同家族的 base instructions。以字符长度和标题结构为例 [B]：

| 模型 | base 长度 | 典型结构 | Responses Lite | Skill 使用说明 |
|---|---:|---|---|---|
| `gpt-6.1-sol` | 21,769 chars | 权限判断 / 自主性 / 个性与写作 / 技术沟通 / 工具与技能 / Apps / Plugins | true | base 内含 |
| `gpt-5.5` | 21,459 chars | Personality / General / Engineering judgment / Editing constraints / Autonomy / Formatting / Final answer | false | catalog 追加 |
| `auto/deepseek-v4.1-flash` | 20,751 chars | 默认 CLI family：How you work / AGENTS.md spec / Responsiveness / Planning / Task execution / Tool Guidelines | null | catalog 未追加 |

默认 CLI family 的开头是：

```text
You are a coding agent running in the Codex CLI, a terminal-based coding assistant.
The Codex CLI is an open source project led by OpenAI. You are expected to be precise,
safe, and helpful.
```

GPT-6 family 的开头则是：

```text
You are Codex, an agent based on GPT-6. You and the user share one workspace,
and your job is to collaborate with them until their intended goal is completely handled.
```

两者共享“自主推进、工具使用、验证、最终答复格式”等目标，但段落组织不同。GPT-6 family 更强调权限判断、完成前证据、写作风格与技能/插件路由；默认 CLI family 更强调 `update_plan`、任务执行、验证与输出结构。

### 2.3 developer instructions

有两类“额外 developer 指令”：

| 来源 | 注入位置 | 说明 |
|---|---|---|
| `config.developer_instructions` | 普通 developer 合并段的最前面 | 宿主/用户追加的会话级规则 |
| `requirements.additional_developer_instructions` | 单独的 managed developer message | 企业/托管策略，最后注入，便于审计 |

`developer_instructions` 与 `AGENTS.md` 的差别是：前者是配置层，后者是仓库/用户文件；两者最终都以“指令”而非“数据”呈现，但 provenance 不同。

### 2.4 permissions instructions

权限块由运行时状态生成，wire 上是 developer 段，标题是 `<permissions instructions>`。内容取决于：

- `sandbox_mode`：`read-only` / `workspace-write` / `danger-full-access`
- approval policy：`untrusted` / `on-request` / `never`
- writable roots
- 已批准的命令前缀
- 网络策略
- 是否启用 `ExecPermissionApprovals` / `RequestPermissionsTool`

一个很有用的观察是：**权限说明的大小随策略剧烈变化**。本机当前会话是 `danger-full-access` + `never`，权限块只有 **362 chars**；而 `codex debug prompt-input` 默认的 `workspace-write` 场景下是 **7,443 chars**，包含完整的 escalation 流程、prefix rule 示例与安全约束。[B]

这说明：

- 权限不只是运行时门禁，也是提示词的一部分。
- 用 `danger-full-access` 会显著缩短提示词，但不等于“更安全/更简单”，只是把约束交给外部环境。
- 不能只靠提示词里的“不要执行”保证安全；真正的门禁在 sandbox/approval/hook。

### 2.5 collaboration mode

模式说明以 `<collaboration_mode>` developer 段注入，默认 `include_collaboration_mode_instructions = true`。内容来源优先级：

1. 模型目录的 `model_messages.collaboration_modes` 覆盖
2. `collaboration_mode.settings.developer_instructions`
3. Codex 内置的 Default/Plan 预设

本机当前 Default 模式块为 **1,329 chars**，包含默认模式行为、Plan 模式切换说明，以及 `request_user_input` 可用性。[B] 这部分容易被误认为“base prompt 的一部分”，实际上它是 world-state 的独立 section。

### 2.6 environment context

环境块 wire role 是 `user`，内容为 `<environment_context>`，包含：

```text
cwd
status (starting / failed)
shell
current_date
timezone
network policy
filesystem policy
subagents
```

日期与 timezone 由 `include_environment_context_time` 控制。当前快照的环境块为 **406 chars**。

环境 section 也是 diff 的：cwd、shell、失败状态、网络/文件系统策略变化时，只发变化项；多个执行环境时按 `environment id` 分组，并标出 primary。

### 2.7 AGENTS.md 的实际 wire role 是 user

base instructions 的 `# AGENTS.md spec` 说项目指令“included with the developer message”，但 0.167.1 的实际实现里，`UserInstructions` 的 role 是 **`user`**，markers 是：

```text
# AGENTS.md instructions for <directory>

<INSTRUCTIONS>
...
```

provenance 是 `AgentsMd`，content kind 是 `agents_md.instructions`。所以“把它当 developer message”是概念层说法，不是 wire 层事实。模型看到的是 user-role 的指令块，但 harness 通过 metadata 知道它来自 `AGENTS.md`。

这也是为什么只按 role 判断“谁是权威”会出错：Codex 用 provenance 区分“用户输入”“harness 注入”“AGENTS.md 指令”“Skill 指令”“hook 输出”。

### 2.8 Skills / Apps / Plugins 说明块

这三类说明都可能是 developer 段：

| 块 | 触发条件 | 内容 |
|---|---|---|
| `<skills_instructions>` | Skill 目录非空，且 `skills.include_instructions` | 根别名、可用技能列表、可选 usage rules |
| `<apps_instructions>` | 存在可访问 connector，且模型 `include_apps_usage_instructions` | App/connector 的触发格式与 MCP 关系 |
| `<plugins_instructions>` | 插件可用，且模型 `include_plugin_usage_instructions` | 插件是 skill/MCP/app 的 bundle；不直接调用插件 |

这些块的共同点是：**只注入路由元数据与使用规则，不注入全部正文**。真正的 Skill 正文、MCP schema、App 数据按需加载。

### 2.9 工具定义不在提示词文本里

普通模式下，工具由 `tools` 数组传递，包含 name、description、input schema、output schema 等。模型看到的是结构化工具定义，不是一段自然语言“可用工具列表”。

Responses Lite 下，工具目录被序列化为 `AdditionalTools` 输入项，`tools` 字段只保留 hosted tools。工具定义仍然不是普通 developer 文本，而是专门的 input item。

因此：

- 修改工具描述、schema、顺序，都会改变缓存前缀。
- 不要期望在 `codex debug prompt-input` 里看到完整工具数组；该命令主要渲染 message input。
- Skill/MCP 的“工具化”与“正文注入”是两条不同路径。

### 2.10 专用 prompt

Codex 还有几类不是普通对话的模型请求 [A]：

| 请求 | 入口 | 提示词特征 |
|---|---|---|
| Review | `codex review` | 使用独立的 review base prompt 与 review rubric，不是普通 coding agent prompt |
| Guardian / auto-review | 审批自动审查 | 独立 reviewer session、policy/classifier 模板、受限工具与上下文 |
| Memory extraction | 后台记忆管线 Phase 1 | 结构化 JSON 输出，把 rollout 转成 `raw_memory` / `rollout_summary` |
| Memory consolidation | 后台记忆管线 Phase 2 | 独立 consolidation subagent，无 approvals、无 network、本地写 |
| Compaction | 手动或自动压缩 | 独立 summarization prompt，输出 handoff summary |

这些请求共享模型客户端与部分 base instructions，但不应和主 agent 的 world-state prompt 混为一谈。

## 3. 指令文件体系（AGENTS.md）

### 3.1 两类来源

Codex 的 `AGENTS.md` 体系有两层 [A][C]：

| 层级 | 位置 | 规则 |
|---|---|---|
| 全局 | `$CODEX_HOME/AGENTS.override.md` → `$CODEX_HOME/AGENTS.md` | 只取第一个非空文件 |
| 项目 | 从项目根到 cwd 的每个目录：`AGENTS.override.md` → `AGENTS.md` → fallback names | 每个目录最多一个文件 |

`$CODEX_HOME` 默认是 `~/.codex`。`project_doc_fallback_filenames` 可追加 `TEAM_GUIDE.md`、`.agents.md` 等名称。

### 3.2 发现算法

```text
1. 从 cwd 向上找项目根：
   - 使用 project_root_markers，默认 [".git"]
   - 找不到根时只考虑 cwd
2. 构造 root → cwd 的目录链
3. 每个目录按候选名找第一个存在的文件：
   - AGENTS.override.md
   - AGENTS.md
   - project_doc_fallback_filenames...
4. 从 root 到 cwd 顺序拼接
5. 空文件不产生内容；总预算达到 project_doc_max_bytes 后停止
```

全局层会依次尝试 override 与默认文件，直到找到第一个非空内容；项目层则是“每个目录选第一个存在的候选文件”，因此一个空的项目 override 不会自动回退到同目录的 `AGENTS.md`。[A]

项目根默认是 Git 根。Codex 不会越过项目根继续向上找项目 `AGENTS.md`。全局文件与项目链是分开的：全局文件先加载，再拼项目链。

### 3.3 拼接顺序与“优先级”

实际文本顺序 [A]：

```text
user instructions (global)
thread instructions (host-provided)
project docs root -> cwd
```

单项目环境用 `--- project-doc ---` 分隔全局/项目；多项目环境会改用 `for <environment_id> with root <cwd>` 标签分组。后出现的文件更靠近当前工作目录，因此在冲突时通常被模型视为更具体；但 Codex 的 base instructions 明确写了“直接 system/developer/user 指令优先于 AGENTS.md”，所以文件顺序不是绝对权威链。

`AGENTS.override.md` 的语义是**同目录替换**，不是全局覆盖。某个目录有 override 时，该目录的 `AGENTS.md` 被忽略；更上层目录的规则仍然保留。

### 3.4 预算与截断

`project_doc_max_bytes` 默认 **32 KiB**，在所有执行环境之间共享。超限时后面的文件会被截断，日志会告警。它不是“每个文件 32 KiB”，而是整个项目链加起来的预算。

全局文件与 thread instructions 不受这个项目预算控制；thread instructions 另有约 **10,000 estimated tokens** 的上限，超限直接报错而不是截断。

### 3.5 信任边界

`load_project_instructions` 在 `config.active_project.is_untrusted()` 时直接返回已加载的全局/thread 指令，不读取项目文件。项目 `.codex/` 不受信任时，项目 hooks 也不会加载。

这条规则很重要：**“文件存在”不等于“会被读取”**。把安全规则放进未受信任仓库的 `AGENTS.md`，不能替代全局策略或运行时门禁。

### 3.6 子代理与恢复

- 子代理继承已应用的 user/thread instructions，以及可选的 repository snapshot。
- 审查型子代理可以接收固定的 project snapshot，避免在审查期间仓库文件变化影响判断。
- `InitialHistory::Resumed` 会优先复用历史中的 base instructions；不会因为模型目录更新而悄悄改写旧会话的身份。

### 3.7 设计解读

Codex 的 `AGENTS.md` 设计是“**项目根→cwd 的层级拼接**”，与 ZCode 的“最近一个 workspace 文件”不同，也比 Claude Code 的祖先链更简单：Codex 的提示词发现不读 `CLAUDE.md`（外部配置迁移功能除外），子目录规则通过逐目录 `AGENTS.md` 生效，而不是懒加载。

实践上：

- 跨项目底线放 `$CODEX_HOME/AGENTS.md`。
- 项目构建/测试/架构规则放仓库根 `AGENTS.md`。
- 模块特例放子目录 `AGENTS.md` 或同目录 `AGENTS.override.md`。
- 不要把机器 IP、端口、token 放进仓库 `AGENTS.md`。

## 4. 记忆体系（Memories）

### 4.1 默认关闭

官方文档明确：Memories 默认关闭；本机 `codex features list` 显示 `memories stable false`。[B][C]

可在 `config.toml` 打开：

```toml
[features]
memories = true
```

本机 `~/.codex/memories_1.sqlite` 存在，但当前会话没有注入 `# Memory` 或 memory summary；world-state snapshot 也没有 memory section。因此本文把 Memories 归为“代码路径清楚、本机未启用”。

### 4.2 写入管线

后台管线只在根会话启动时触发，条件包括：非 ephemeral、功能启用、非子代理、state DB 可用。它分两阶段 [A]：

```text
Phase 1: rollout extraction
  - 从 state DB 选取满足年龄/空闲/限额条件的 rollout
  - 过滤成 memory-relevant items
  - 调用模型生成 raw_memory / rollout_summary / rollout_slug
  - 脱敏后写回 state DB

Phase 2: global consolidation
  - 取得全局锁
  - 选取 bounded stage-1 输出
  - 同步 raw_memories.md / rollout_summaries/
  - 生成 workspace diff
  - 启动 consolidation subagent
  - 更新 MEMORY.md / memory_summary.md / skills/
```

### 4.3 读取路径注入

启用后，读取路径使用 `read_path_v2.md` 生成 developer 段（`MemoryContextFragment::ReadInstructions`），把 `memory_summary.md` 嵌入：

```text
========= MEMORY_SUMMARY BEGINS =========
...
========= MEMORY_SUMMARY ENDS =========
```

每个 memory 相关片段有 **8,900 bytes** 上限。模型被要求：

- 把 memory 当历史上下文，不当当前事实证明。
- 有实质影响时检查当前实际源文件。
- 只在确实使用 rollout summary 时附 memory citation。
- 用户明确要求 remember/forget/correct 时，写到 `extensions/ad_hoc/notes/`，不直接改生成文件。

### 4.4 与 AGENTS.md 的分工

官方明确建议：必须始终适用的团队规则放 `AGENTS.md` 或提交的文档；Memories 是本地回溯层，不是规则唯一来源。Codex 的 base instructions 也把 `AGENTS.md` 放在“项目指令”层，把 memory 放在“历史上下文”层。

实践矩阵：

| 内容 | 放哪里 |
|---|---|
| 团队强制规则、构建/测试命令 | `AGENTS.md` 或提交文档 |
| 用户偏好、重复工作流、已知坑 | Memories（启用时） |
| 当前任务约束 | 当前用户消息 / spec |
| 机器事实 | 每机器 `machine-profile.md`，由全局 `AGENTS.md` 或 Skill 引用 |

## 5. Skill 体系

### 5.1 定义与渐进披露

Skill 是带 `SKILL.md` 的目录。Codex 初始只把 **name + description + locator** 放进上下文；模型决定使用后，才读取完整 `SKILL.md`。官方称这是 progressive disclosure。[C]

这与 MCP 不同：MCP 工具是 schema 注册，Skill 是指令文件按需读取。

### 5.2 发现根与顺序

官方列出的根 [C]：

| scope | 位置 |
|---|---|
| repo | `$CWD/.agents/skills` 到 `$REPO_ROOT/.agents/skills` 的每一层 |
| user | `$HOME/.agents/skills` |
| admin | `/etc/codex/skills` |
| system | OpenAI 随 Codex 捆绑 |

源码还保留了兼容根 `$CODEX_HOME/skills`（deprecated user skills）以及插件 skills 根。[A] 当前本机 `codex debug prompt-input` 显示：

```text
r0 = ~/.agents/skills
r1 = ~/.codex/skills/.system
```

同名 Skill 不会自动合并：Codex 按路径去重，但不同路径的同名项可以同时出现。软链接会被追踪。

### 5.3 frontmatter 与元数据

`SKILL.md` 必须有 YAML frontmatter；`name` 与 `description` 是核心字段。解析器把 name 限制为 64 字符，description 不能为空；`metadata.short-description` 可作为目录展示的短描述。[A]

可选 `agents/openai.yaml` 可提供：

```yaml
interface:
  display_name: ...
  short_description: ...
policy:
  allow_implicit_invocation: false
dependencies:
  tools: ...
```

`allow_implicit_invocation: false` 时只允许显式 `$skill` 调用。

### 5.4 目录渲染与预算

Skill 目录以 developer `<skills_instructions>` 注入。默认预算：

- 模型上下文窗口的 **2%**，上限 **10,000 tokens**；上下文未知时回退 **8,000 chars**。
- 单条描述最多 **1,024 chars**，超出截断。
- 目录超预算时先截短描述；仍然超限时省略部分 Skill 并发出 warning。
- 被选中 Skill 的正文读取上限 **8,000 bytes**；超过会截断。

本机当前目录块为 **22,021 chars / 22,229 bytes**，列出 **56 条 Skill 条目**：4 个系统 Skill（`review-agent` 未列入）+ 52 个用户 Skill（46 个本仓库软链 + 6 个 ai-memory）。`include_skills_usage_instructions` 在当前自定义模型目录中已显式设为 `true`，因此目录末尾会追加 `### How to use skills` 规则块（包含“必须先完整读取 `SKILL.md`”与触发规则）。该字段在 `ModelInfo` 中默认是 `false`；自定义模型目录若省略它，Codex 只注入技能目录，不注入使用规则。[A]

### 5.5 激活与正文注入

两条激活路径：

1. **显式**：`$skill-name`、`/skills` 选择器或用户直接点名。
2. **隐式**：任务与 description 匹配，且 policy 允许隐式调用。

正文以 user `<skill>` 段注入：

```text
<skill>
<name>...</name>
<path>...</path>
<resource_access>{...}</resource_access>
... SKILL.md 正文 ...
</skill>
```

provenance 是 `Skills`。对于 executor/cloud package，还会带 `resource_access`，提示模型用 `skills.read` 读取包内资源，而不是把 `skill://` 当本地路径。

### 5.6 插件与远程 Skill

插件贡献的 Skill 名称会带 `plugin_name:` 前缀；插件 Skill 根与普通 repo/user/system 根分开。远程 executor/cloud Skill 通过 `skills.read` 读取，目录里显示的是 package locator，不是本地路径。

### 5.7 设计原则

- description 写“何时触发”，不要写营销文案。
- 正文按任务分支组织，避免一开始加载所有 references。
- 重要约束放 `SKILL.md` 顶部，因为正文可能被 8,000 bytes 截断。
- 不要把“必须每次执行”的规则只写在 Skill 里；用 hook 做确定性门禁。
- 大清单要控制数量：目录预算只有上下文的 2%，且最多 10k tokens。

## 6. MCP 体系

### 6.1 配置与传输

MCP 配置在 `config.toml` 的 `[mcp_servers.<id>]`。官方支持：[C]

- STDIO：`command`、`args`、`env`、`env_vars`、`cwd`
- Streamable HTTP：`url`、`bearer_token_env_var`、`http_headers`、`env_http_headers`
- OAuth：`codex mcp login <server>`
- `enabled`、`required`、`startup_timeout_sec`、`tool_timeout_sec`
- `enabled_tools` / `disabled_tools` / `default_tools_approval_mode` / `tools.<tool>.approval_mode`

项目级 `.codex/config.toml` 只在项目受信任时生效。

### 6.2 工具注册与命名

MCP 工具最终进入 `tools` 数组（或 Responses Lite 的 `AdditionalTools` input）。模型可见名称需要满足 Responses API 的 `^[a-zA-Z0-9_-]+$`，并限制在 **128 bytes** 内。[A]

默认 namespace 加 `mcp__` 前缀：

```text
mcp__<server>__<tool>
```

Codex 会：

- 清洗非法字符；
- 对 namespace/tool 冲突追加 12 位 SHA-1 后缀；
- 保留 raw MCP server/tool name 用于协议调用；
- 支持 `non_prefixed_mcp_tool_servers` 关闭前缀。

### 6.3 MCP server instructions 不是独立全局块

这是 Codex 与 Claude Code 的一个明显差异。Codex 把 MCP `initialize.instructions` 作为 **tool namespace description**：

- 普通工具：namespace description 上限 **512 KiB**；
- agent/plugin 工具：更严格，上限 **1,000 bytes**；
- deferred tool world-state 摘要：只取首行，最多 **250 chars**，整段最多 **4 KiB**。

因此：

- MCP server 的 instructions 会出现在工具说明/schema 附近，而不是 `# MCP Server Instructions` 的全局段。
- 如果工具被 deferred，模型先看到的是 namespace 摘要，不是完整 instructions。
- 不要让关键安全规则只存在于 MCP instructions；服务端工具策略、approval 与 sandbox 才是门禁。

### 6.4 工具输出与信任

工具调用结果以 tool role / tool output item 进入历史，provenance 是 `Tool`。MCP server 可能返回不可信内容；Codex 的权限/审批、tool policy 和 sandbox 负责限制实际动作，提示词层不应把工具输出当授权。

### 6.5 本机快照

`codex doctor` 显示本机 **0 个 MCP server**；当前 world-state 有 `plugins_instructions` 与 `tools` section 的空状态，但没有 MCP 工具或 namespace 描述。因此本机请求的工具数组中没有 `mcp__*` 项。

### 6.6 设计原则

- 工具名保持稳定；改名会破坏缓存与调用预期。
- 工具描述写清输入、输出、副作用和审批需求。
- 大量工具优先使用 deferred namespace，避免首轮 schema 爆炸。
- 对破坏性工具设置 `approval_mode`，不要把安全寄托在模型自觉。
- 只连接可信 server；项目级 MCP 需要项目 trust。

## 7. Hooks、Plugins、Subagents、Compaction、Caching

### 7.1 Hooks

Hook 在生命周期事件上运行命令或 MCP 工具。官方支持的事件包括：[C]

```text
SessionStart, SubagentStart, UserPromptSubmit, PreToolUse, PermissionRequest,
PostToolUse, PreCompact, PostCompact, SubagentStop, Stop, Interrupt, SessionEnd
```

配置位置：

```text
~/.codex/hooks.json
~/.codex/config.toml 的 [hooks]
<repo>/.codex/hooks.json
<repo>/.codex/config.toml 的 [hooks]
插件捆绑的 hooks
```

非托管 hook 在运行前必须经过审查并记录 trust hash；项目 hook 只在项目 `.codex/` 受信任时加载。来自企业/MDM/requirements 的托管 hook 可被策略信任。

对提示词的影响：

- `SessionStart` / `UserPromptSubmit` / `PreToolUse` / `PostToolUse` 等事件可以产生 `additionalContext`。
- Codex 把 additional context 以 **developer role** 的 `HookAdditionalContext` 消息写入对话历史，provenance 为 `Harness { hook: true }`。[A]
- 默认输出上限 **2,500 tokens**；可用 `additionalContextLimit` 调整。大输出会写盘并发送较短预览。
- `PreToolUse` 可以阻断工具调用或改写输入；这属于确定性门禁，不是提示词建议。

因此，hook 输出虽然常被写成“上下文”，但 wire role 是 developer。对 hook 来源的信任必须靠安装/审查流程保证，不能靠 role 判断。

### 7.2 Plugins

插件是本地 bundle，可包含 Skill、MCP server、App 映射、hooks、assets 等。官方说明：[C]

- 插件不是直接调用的工具；使用它贡献的 Skill、MCP 工具与 App 工具。
- 插件 Skill 在目录中带 `plugin_name:` 前缀。
- 插件 MCP 工具保持标准 `mcp__server__tool` 命名。
- 插件安装/启用后通常需要新会话才生效。
- 插件提供的 hooks 走与非托管 hook 相同的 trust 流程。

当插件可用且模型支持时，Codex 注入 `<plugins_instructions>` developer 段，内容主要是“如何路由到插件贡献的能力”，不包含所有插件正文。

本机当前没有启用插件；world-state 有 `plugins_instructions` section 但未渲染内容。

### 7.3 Subagents

官方说明：[C]

- Codex 只有在用户明确要求时才应生成子代理。
- 内置角色包括 `default`、`worker`、`explorer`。
- 自定义角色放在 `~/.codex/agents/` 或 `.codex/agents/`，每个 TOML 必须定义 `name`、`description`、`developer_instructions`。
- 子代理继承当前 sandbox/approval、cwd、模型与推理设置；角色文件可覆盖模型、effort、sandbox、MCP、skills.config。
- `agents.max_threads` 默认 6，`agents.max_depth` 默认 1。

对 prompt 的影响：

- 每个子代理是独立线程，有自己的 base instructions、developer instructions、world-state 与工具数组。
- 父代理的 `base_instructions.text`、`developer_instructions` 与运行时 policy 会被复制到子代理配置；子代理可以再叠加角色指令。
- 多代理模式通过 `<multi_agent_mode>` developer 段控制“显式请求才可委派”或“主动委派”；默认是显式请求。
- 子代理结果以消息/摘要返回父线程，不把子代理的全部中间工具输出直接灌回主上下文。

### 7.4 Compaction

当上下文接近上限、模型降档、`comp_hash` 变化或用户手动请求时，Codex 运行压缩。默认 summarization prompt 很短：[A]

```text
You are performing a CONTEXT CHECKPOINT COMPACTION. Create a handoff summary for another LLM
that will resume the task.

Include:
- Current progress and key decisions made
- Important context, constraints, or user preferences
- What remains to be done (clear next steps)
- Any critical data, examples, or references needed to continue
```

压缩请求的特征：

- 使用独立 model turn，通常不携带普通工具定义。
- 可用 `config.compact_prompt` 或 `experimental_compact_prompt_file` 替换默认 prompt。
- 输出前加 `SUMMARY_PREFIX`，告诉下一个模型“另一个模型已经做了这些工作”。
- replacement history 保留最近最多 **20,000 tokens** 的 user messages，最后追加 `CompactionSummary`（user role）。
- 重新渲染当前 world-state 全量上下文，并把 summary 放在最后；如果存在 retained tool outputs/developer messages，按 feature 保留。
- `compaction_model_hash` / `reviewer_compaction_hash` 记录压缩时的模型，模型变化会使旧压缩失效。

压缩不是“把旧消息原样删掉”，而是“摘要 + 最近用户消息 + 新窗口全量上下文”的 replacement history。压缩后缓存前缀会重建，不能期待旧前缀继续命中。

### 7.5 Prompt Caching

Codex 0.167.1 不在请求里写 `cache_control`；它使用 Responses API 的自动提示词缓存，并发送 `prompt_cache_key`。默认策略是 session-derived：[A]

- 根会话使用 `session_id`；
- 内部子会话使用 `source:parent_thread_id` 的派生键；
- 可配置 `Custom(key)` 或 `Omit`。

官方缓存文档说明 [C]：

- 缓存按渲染后的完整前缀匹配，包括指令、工具定义、开发者消息和对话历史。
- 工具、模型、`parallel_tool_calls`、`reasoning.effort`、`text.format`、`text.verbosity` 等变化会影响前缀。
- 顶层 `instructions` 不能放显式断点；要标记可复用的开发者指令，应放在开发者消息的 `input_text` 块中。

这解释了 0.167.1 的一个设计选择：**base instructions 作为 developer item 放在 `input` 里，而不是作为顶层 `instructions` 字段。** 这样它可以和普通 developer 内容一起参与缓存前缀，也便于统一的 item provenance。

Codex 的缓存友好策略：

- base instructions 在前；
- 工具定义稳定；
- world-state 变化以新消息追加，尽量不重写旧前缀；
- `AGENTS.md` / Skill 目录变化时发替换通知，而不是每轮重发；
- 压缩是显式的前缀重建点。

## 8. 设计原则总结

1. **模型拥有 base prompt**：不要假设一套 prompt 适配所有模型；模型目录的 `base_instructions` 是事实源。
2. **两层装配**：base + tools 是执行框架，world-state 是本轮工作上下文；不要把两者混成一段。
3. **provenance 高于 role**：`AGENTS.md` 是 user role 但 `AgentsMd` provenance；hook 输出是 developer role 但 `Harness { hook: true }`；MCP 输出是 Tool。按来源判断信任。
4. **一次全量，之后 diff**：首轮/压缩/新窗口全量，稳态只发变化；这是 Codex 的核心上下文策略。
5. **渐进披露**：Skill 只注入 name/description/locator，正文按需；MCP 工具按需/deferred；Memory 只注入 summary。
6. **硬预算**：AGENTS 32 KiB、Skill 目录 2%/10k tokens、Skill 正文 8 KB、Memory 8.9 KB、deferred tool summary 4 KB；超限截断或省略，不静默无限增长。
7. **确定性门禁优先**：不可逆/对外操作靠 sandbox、approval、hook、MCP tool policy，而不是只靠 prompt 里的“不要做”。
8. **失败隔离**：单个 Skill 解析失败、MCP server 启动失败、插件无能力，不应让其他 section 消失。
9. **可观测**：`codex debug prompt-input` 看 input；`codex debug models` 看 model prompt family；`codex features list` 看门控；rollout `WorldStateItem` 看 diff。
10. **机器事实不入库**：主机、端口、凭据、机器路径放每机器 profile 或 `$CODEX_HOME`，不要放公共 `AGENTS.md` / Skill。

## 9. 本机验证快照（2026-11-11）

| 项 | 值 | 证据 |
|---|---|---|
| Codex CLI | 0.167.1 | `codex --version` |
| 源码 tag | `rust-v0.167.1`，commit `0a94398f...` | `git clone --branch rust-v0.167.1` |
| 二进制 | static-pie ELF, 320 MB, stripped | `file` |
| 模型 | `auto/deepseek-v4.1-flash` | `~/.codex/config.toml` |
| provider | `magpie`，`wire_api = responses` | `codex doctor` |
| 上下文窗口 | 1,000,000 tokens | models catalog |
| cwd | `~/tools-git/viccom-agent-skills` | 当前会话 |
| base instructions | 20,751 chars / 20,904 bytes | 自定义 models catalog |
| developer message | 5,974 chars | rollout |
| ├ skills 目录 | 22,021 chars，56 条 Skill 条目 | `codex debug prompt-input` |
| ├ permissions | 362 chars（danger-full-access / never） | rollout |
| └ collaboration mode | 1,329 chars（Default） | rollout |
| 项目 AGENTS.md 注入块（建立前） | 11,289 chars / 16,598 bytes | rollout；文件 `wc -c` |
| 环境块 | 406 chars | rollout |
| 用户 prompt | 106 chars | rollout |
| 全局 AGENTS.md | 已安装：`~/.codex/AGENTS.md`（16,087B） | `wc -c`；源 `codex/global-instruction/AGENTS.md` |
| 本机全局包 | `~/.codex/global-instruction/` + `machine-profile.md` / `skill-routing.md` | `ls` |
| 项目 AGENTS.md | 仓库根 `AGENTS.md` | AGENTS 块标题 |
| world-state sections | 17 | rollout `world_state` |
| Skill roots | `~/.agents/skills`, `~/.codex/skills/.system` | `codex debug prompt-input` |
| 用户 Skill | 46 个本仓库软链 + 6 个 ai-memory；catalog 用户条目 52 个，总计 56 条 | `~/.agents/skills`；`codex debug prompt-input` |
| Skill 目录成本 | 22,021 chars / 22,229 bytes（56 条 catalog 条目，含 usage rules） | 本机 probe |
| MCP servers | 2：`anysearch` + `ai-memory`（streamable HTTP） | `codex mcp list` / `codex doctor` |
| MCP tools | `anysearch` 5 个 + `ai_memory` 27 个 | `codex exec` 实测 |
| Plugins | 未启用 | turn context / doctor |
| Hooks | 未配置 | `~/.codex` / `config.toml` |
| Memories | 功能关闭，DB 存在 | `codex features list` / `~/.codex` |
| 功能门控 | 66 enabled | `codex doctor --all` |
| `debug prompt-input`（建立前） | 3 个 input item，32,201 bytes | 本机 probe |
| `debug prompt-input`（建立后） | 3 个 input item，53,094 bytes；user block 20,322 chars | 本机 probe |

> 快照只记录结构事实，不含 API key/token。2026-11-11 已建立 Codex 全局指令层；§9 中 developer/user 的细项长度来自建立前会话，建立后新请求会同时注入全局 `AGENTS.md` 与项目 `AGENTS.md`（`--- project-doc ---` 分隔）。`codex debug prompt-input` 使用其自己的 invocation config（本机 probe 为 `workspace-write` + `on-request`），因此 permissions 长度与当前 `danger-full-access` 会话不同；这不是实现矛盾，而是配置不同。

> 同日又安装了精选编程 Skill；技能目录从 4,281 chars 增至 22,021 chars（56 条，含 `### How to use skills`），仍低于默认 10k token 上限，未出现省略/截断警告。

## 10. 已知未知与验证方法

| 未知/边界 | 现状 | 如何验证 |
|---|---|---|
| wire 层 base instructions 是否总为 developer | 源码 `BaseInstructionsFragment` role=`developer`；UI 可显示为 system | 用本地 proxy 抓 `build_responses_request` 的 JSON |
| `codex debug prompt-input` 是否包含全部 runtime 段 | 不含 base/tools，且模式段可能随 invocation config 不同 | 与 rollout、源码、`debug models` 交叉验证 |
| provider/gateway 是否改写 role | 本机 magpie 为 OpenAI 兼容网关，未逐字节对比 | 抓上游请求，比较 `input[].role` |
| 缓存命中率 | 未读取服务端 usage 明细 | 检查响应 `usage.cached_tokens` / gateway 日志 |
| Skill 目录预算的 token 估算 | 源码是 approx_token_count；实际 tokenizer 未验证 | 构造接近 2% 的目录，观察 warning/省略 |
| `include_skills_usage_instructions` 的行为 | **已确认**：默认 `false`，设为 `true` 才追加 `### How to use skills` | `codex debug models` 看字段；`codex debug prompt-input` 搜 `### How to use skills` |
| Memories 实际注入 | 功能未启用 | 打开 `features.memories`，创建 memory summary，新会话检查 developer 段 |
| MCP server instructions 的实际长度 | 未连接 MCP server | 配一个返回长 instructions 的 server，检查 namespace description |
| deferred tool summary 行为 | 本机无 MCP，未触发 | 配大量 MCP 工具，观察 `tools` world-state 段 |
| 压缩后的 retained items | 本机未触发压缩 | 手动 `/compact`，检查 summary、20k user messages、world-state 重建 |
| 子代理 prompt 继承 | 未 spawn 子代理 | 生成一个自定义 agent，比较 base/developer/skills/MCP |
| 插件 hooks 的 trust | 无插件 | 安装带 hook 的插件，观察 `/hooks` 审查流程 |

**通用验证原则**：

```text
先看 model-owned prompt：codex debug models
再看 input 列表：codex debug prompt-input
再看运行态 history：rollout JSONL
最后看固定源码：WorldState / build_prompt / build_responses_request
```

不要只用其中一层下结论。

## 11. Harness 设计检查清单

### 11.1 Harness 关注点与 Codex 机制映射

| Harness 关注点 | Codex 机制 | 证据 |
|---|---|---|
| 上下文装配 | base instructions + `WorldState` sections + `Prompt.input` | §1 [A] |
| 指令层级 | global AGENTS → thread → project root→cwd | §2.7、§3 [A][C] |
| 上下文预算 | 32 KiB AGENTS、2%/10k Skill 目录、8 KB Skill 正文、8.9 KB memory | 附录 A [A][C] |
| 渐进披露 | Skill name/description/locator；正文按需；MCP deferred namespace | §5、§6 [A][C] |
| 权威分层 | provenance > role；`AgentsMd` / `DeveloperInstructions` / `Skills` / `Tool` / `Harness` | §2.7、§8 [A] |
| 权限与确认 | sandbox + approval + `permissions` developer 段 + hooks | §2.4、§7.1 [A][C] |
| 人类在环 | approval policy；不可逆/对外操作先确认 | §2.4、§8 [A][C] |
| 验证与完成 | base instructions 要求实际运行、报告真实输出；无项目门禁 | §2.2、§11.4 [A] |
| 状态与恢复 | rollout、`WorldStateItem`、compaction replacement history | §1.4、§7.4 [A][B] |
| 多代理隔离 | 独立线程、独立 world-state、受控委派 | §7.3 [A][C] |
| 失败隔离 | Skill/MCP/插件单点失败不删除其他 section | §5、§6、§7 [A] |
| 可观测性 | `debug prompt-input` / `debug models` / `features list` / doctor | §9、附录 C [B] |
| 可移植性 | `$CODEX_HOME`、项目 `AGENTS.md`、Skill 根、model catalog | §3、§5 [A][C] |
| 评估与回归 | 代表任务 + 结构断言 | §11.4 [D] |

### 11.2 指令放置矩阵

| 规则类型 | 放哪里 | 原因 |
|---|---|---|
| 跨项目行为底线 | `$CODEX_HOME/AGENTS.md` | 所有会话全局加载 |
| 项目构建/测试/架构 | 仓库根 `AGENTS.md` | 根→cwd 拼接，团队可 review |
| 子目录模块规则 | 子目录 `AGENTS.md` 或 `AGENTS.override.md` | Codex 逐目录加载；override 替换同目录文件 |
| 个人不入库偏好 | `$CODEX_HOME/AGENTS.md` 或本地 profile | 不提交到仓库 |
| 机器事实 | `machine-profile.md` + 全局 AGENTS/Skill 引用 | 每台机器不同，不进公共仓库 |
| 可复用流程 | Skill | 正文按需，目录只占 2% |
| 必须每次执行的行为 | Hook / sandbox / approval | 确定性，不依赖模型判断 |
| 外部系统访问 | MCP server | 协议化工具、schema、权限 |
| 隔离的重活 | Subagent | 独立上下文，只回摘要 |
| 长期项目决策 | `docs/` / ADR | 可审计、不占启动上下文 |
| 会话交接 | spec/tasks / 压缩摘要 | 不依赖聊天记录 |
| 一次性要求 | 当前用户消息 | 最高即时优先级，不持久 |

### 11.3 指令变更检查清单

写或改一条规则前，逐项回答：

1. 它是 base prompt、config developer、AGENTS、Skill、hook、MCP 还是用户消息？放对层了吗？
2. Codex 会加载它吗？全局 `$CODEX_HOME/AGENTS.override.md` 是否遮蔽了 `AGENTS.md`？项目是否受信任？
3. 它是 MUST、SHOULD 还是 DEFAULT？冲突时谁覆盖谁？需要 hook 强制执行吗？
4. 它能被验证吗？验证命令/证据是什么？
5. 它是否与 sandbox、approval、MCP tool policy、hook trust 冲突？
6. 它依赖 Skill/MCP/插件/记忆吗？缺失时还能工作吗？
7. 它会不会超过 32 KiB / 2% / 8 KB / 8.9 KB 预算？是否该拆到 references 或 docs？
8. 它是否把主机、端口、token、机器路径写进公共仓库？

### 11.4 变更后的最小回归

提示词/指令变更至少跑以下任务：

1. **指令加载**：新会话中请求“列出你加载的指令来源”，或检查 `codex debug prompt-input` / rollout，确认全局→项目根→子目录顺序正确。
2. **覆盖语义**：同目录同时放 `AGENTS.override.md` 与 `AGENTS.md`，确认只加载 override；子目录规则不被根规则意外遮蔽。
3. **破坏性操作**：要求删除/覆盖/改绑，确认 Agent 先回显目标并请求确认。
4. **完成定义**：做一个小改动，确认汇报包含实际命令、真实输出、未验证项，而不是“测试通过”。
5. **Skill 触发**：显式 `$skill` 能读取完整正文；description 匹配能隐式触发；缺失 Skill 能降级。
6. **Hook 门禁**：配置一个 `PreToolUse` 阻断已知命令，确认阻断是确定性的；配置 `UserPromptSubmit` 注入上下文，确认它以 developer 段出现。
7. **MCP**：连接一个工具，确认工具名清洗、schema、namespace description、approval 生效；确认不存在独立全局 MCP instructions 块。
8. **压缩**：手动触发压缩，确认 summary、最近用户消息、world-state 重建和新窗口 ID 正确。

这 8 项不是完整 eval，但能覆盖最常见的回归：规则没加载、覆盖错层、越权、假完成、Skill 不触发、hook 不生效、MCP 路由错误、压缩丢上下文。

## 附录 A：关键常量

| 常量 | 值 | 作用 |
|---|---:|---|
| `project_doc_max_bytes` 默认 | 32 KiB | 全局项目链 AGENTS 总预算 |
| thread instructions 上限 | ~10,000 estimated tokens | host-provided thread 指令；超限报错 |
| Skill 目录预算 | 2% context，max 10,000 tokens，fallback 8,000 chars | available skills catalog |
| Skill 单条描述 | 1,024 chars | 超出截断 |
| Skill name | 64 chars（parser）/ 256 bytes（render） | 名称限制 |
| Skill path | 1,024 bytes | locator 限制 |
| Skill 正文 | 8,000 bytes | 选中 Skill 读取上限 |
| Memory fragment | 8,900 bytes | memory summary/evidence 截断 |
| MCP tool name | 128 bytes | Responses API 工具名 |
| MCP namespace description | 512 KiB（普通）/ 1,000 bytes（agent plugin） | tool namespace 说明 |
| Deferred tool summary | 4 KiB，250 chars/namespace | `tools` world-state 段 |
| Hook additional context | 默认 2,500 tokens | 可通过 `additionalContextLimit` 调整 |
| Compaction retained user messages | 20,000 tokens | replacement history 中保留的最近用户消息 |
| 当前模型 truncation policy | 10,000 tokens | 本机自定义模型目录 |

## 附录 B：证据索引

### B.1 固定源码

| 主题 | 文件/函数 |
|---|---|
| base instructions 解析 | `codex-rs/core/src/session/mod.rs` `base_instructions` 解析；`prompts/src/model_instructions.rs` `render_model_instructions` |
| 默认 base prompt | `codex-rs/protocol/src/prompts/base_instructions/default.md` |
| world-state section | `codex-rs/core/src/context/world_state/mod.rs` `WorldState` / `WorldStateSection` / `render_diff` |
| 初轮/增量装配 | `codex-rs/core/src/session/mod.rs` `build_initial_context_with_world_state`、`record_context_updates_and_set_reference_context_item` |
| 请求构造 | `codex-rs/core/src/session/turn.rs` `build_prompt`；`core/src/client.rs` `build_responses_request` |
| 请求结构 | `codex-rs/codex-api/src/common.rs` `ResponsesApiRequest` |
| 角色与 provenance | `codex-rs/protocol/src/models/item_metadata.rs` `ContentItemMetadata` |
| 全局 AGENTS | `codex-rs/codex-home/src/instructions/mod.rs` |
| 项目 AGENTS | `codex-rs/core/src/agents_md.rs`、`agents_md_manager.rs` |
| Skills | `codex-rs/ext/skills/src/{catalog_prompt,render,world_state,fragments,host_roots}.rs` |
| MCP | `codex-rs/codex-mcp/src/{tools,connection_manager}.rs`；`core/src/tools/handlers/mcp.rs` |
| Hooks | `codex-rs/core/src/hook_runtime.rs`；`core/src/context/hook_additional_context.rs` |
| Compaction | `codex-rs/core/src/compact.rs`；`prompts/templates/compact/*` |
| Memories | `codex-rs/memories/README.md`；`ext/memories/templates/memories/read_path_v2.md`；`core/src/context/memory.rs` |
| Subagents | `core/src/agent/child_config.rs`；`prompts/src/multi_agent_instructions.rs` |
| Plugin 说明 | `core/src/context/available_plugins_instructions.rs` |
| Cache key | `core/src/client.rs` `prompt_cache_key`；`core/src/thread_manager.rs` `PromptCacheKey` |

### B.2 本机运行态

| 证据 | 用途 |
|---|---|
| `codex --version` / `codex doctor --all` | 版本、安装、features、MCP、状态 DB |
| `codex debug prompt-input` | input 列表与各段字符数 |
| `codex debug models` | 全部模型 base instructions / flags / tool mode |
| `~/.codex/models_catalog.json` | 当前模型 base 与 flags |
| `~/.codex/sessions/.../rollout-*.jsonl` | 实际 developer/user 内容、`world_state` snapshot |
| `~/.codex/config.toml` | provider、model、sandbox、approval、features |

### B.3 官方文档

- [Codex source at rust-v0.167.1](https://github.com/openai/codex/tree/rust-v0.167.1)
- [AGENTS.md](https://developers.openai.com/codex/guides/agents-md)
- [Skills](https://developers.openai.com/codex/skills)
- [MCP](https://developers.openai.com/codex/mcp)
- [Hooks](https://developers.openai.com/codex/hooks)
- [Subagents](https://developers.openai.com/codex/subagents)
- [Subagent concepts](https://developers.openai.com/codex/concepts/subagents)
- [Memories](https://developers.openai.com/codex/memories)
- [Configuration reference](https://developers.openai.com/codex/config-reference)
- [Plugins](https://developers.openai.com/codex/plugins)
- [Prompt caching](https://developers.openai.com/api/docs/guides/prompt-caching)

## 附录 C：最小复现命令

```bash
# 1. 版本与健康
codex --version
codex doctor --all

# 2. 本机模型目录与 prompt family
codex debug models > /tmp/codex-models.json
jq -r '(.models // .)[] | [.slug, (.base_instructions|length), .use_responses_lite, .tool_mode, .shell_type] | @tsv' \
  /tmp/codex-models.json | sort -k2,2nr | head -20

# 3. 当前 input 列表（不包含 base instructions 与完整 tools）
codex debug prompt-input 'Reply with OK only.' > /tmp/codex-input.json
jq -r 'to_entries[] | [.key, .value.role, ((.value.content // [])|length), ((.value.content // [])|map(.text // "")|join("\n")|length)] | @tsv' \
  /tmp/codex-input.json
jq -r 'to_entries[] | "=== \(.key) \(.value.role) ===", ((.value.content // [])|map(.text // "")|join("\n---\n")), ""' \
  /tmp/codex-input.json | sed -n '1,160p'

# 4. 本机当前模型的 base 长度与 flags
jq -r '(.models // .)[] | select(.slug=="auto/deepseek-v4.1-flash") | {slug, base_len:(.base_instructions|length), include_skills_usage_instructions, include_plugin_usage_instructions, include_apps_usage_instructions, use_responses_lite, tool_mode, shell_type}' \
  ~/.codex/models_catalog.json

# 5. 最近一次 rollout 的角色与内容长度
latest=$(find ~/.codex/sessions -type f -name '*.jsonl' -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-)
jq -r 'select(.type=="response_item" and .payload.type=="message") | [.payload.role, (.payload.content|map(.text // "")|join("\n")|length)] | @tsv' "$latest" | head -10

# 6. world-state section 列表
jq -c 'select(.type=="world_state") | {full:.payload.full, sections:(.payload.state|keys)}' "$latest" | head -2

# 7. feature 门控
codex features list | sed -n '1,120p'

# 8. 源码证据（固定 tag）
git clone --depth 1 --branch rust-v0.167.1 https://github.com/openai/codex.git /tmp/codex-src-01671
rg -n 'build_initial_context_with_world_state|render_diff|build_responses_request|BaseInstructionsFragment' \
  /tmp/codex-src-01671/codex-rs -g '*.rs'
```

## 维护说明

- 本文是**版本相关、机器相关**的调研文档，不是可移植策略包；不要把它当作跨版本规范。
- 升级 Codex 后至少重新检查：base prompt family、`WorldState` section 列表、permissions/AGENTS/Skill/MCP 预算、`prompt_cache_key` 策略、compaction 行为。
- 本机模型目录是自定义的，`base_instructions` 与 `include_*` flags 可能与官方模型不同；不要用官方模型的假设覆盖本机事实。
- 公开仓库不得放入 API key、token、cookie、真实主机凭据；文中只记录结构常量和脱敏路径。
