# Codex 自定义 Provider、模型目录与高权限 Shell

> 版本基线：Codex CLI **0.167.1**（源码 tag `rust-v0.167.1`，commit `0a94398f...`）
> 调研日期：2026-11-11
> 适用范围：本机 Codex CLI、`wire_api = "responses"` 的 OpenAI 兼容网关、`model_catalog_json` 自定义模型目录。
> 本文是版本/机器相关说明，**不属于** [`global-instruction/`](global-instruction/README.md) 可移植包。

本文回答三件事：

1. 如何把 Codex 接到非 OpenAI 官方 API（自定义网关、聚合器、本地代理）。
2. 如何声明自定义模型列表，让 `/model`、上下文窗口、推理档位和 base instructions 正常工作。
3. 如何用 shell 别名免人工确认执行高权限命令，以及这个做法**不能**保证什么。

文中不包含任何真实 token。本机实际接入点、密钥变量名和模型列表见 `~/.codex/config.toml`、`~/.codex/models_catalog.json` 与 `~/.codex/machine-profile.md`。

> ⚠️ **会话 rollout 可能记录明文凭据。** 本机核对时发现 `~/.codex/sessions/**/rollout-*.jsonl` 至少有一个文件包含 `MAGPIE_API_KEY`（来自工具读取 `~/.claude/settings.json` 的输出）。rollout 是 Codex 的审计/恢复层，默认不会自动重新注入模型，但仍会随备份、同步、共享目录扩散。处理方式见 §4.4。

## 0. 证据等级

| 标记 | 含义 | 来源 |
|---|---|---|
| **[A]** | 固定版本源码确认 | `codex-rs/model-provider-info`、`config`、`protocol`、`models-manager` |
| **[B]** | 本机运行态确认 | `codex --help`、`codex debug models`、`codex doctor`、本机配置文件 |
| **[C]** | 官方文档/通用协议约定 | OpenAI Responses API、Codex 配置文档 |
| **[D]** | 未验证 | 具体网关的字段改写、缓存、工具支持差异 |

## 1. 配置总览

Codex 的模型接入由三块组成：

```text
config.toml
├── model                 # 当前模型 slug
├── model_provider        # 指向 [model_providers.<id>]
├── model_context_window  # 可选：覆盖上下文窗口
├── model_catalog_json    # 可选：自定义模型目录（启动时加载）
└── [model_providers.<id>]
    ├── base_url          # OpenAI 兼容 API 根，通常以 /v1 结尾
    ├── env_key           # 从哪个环境变量读 API key
    ├── wire_api          # 0.167.1 只支持 "responses"
    └── ...               # headers、重试、超时、websocket 等

models_catalog.json
└── models[]
    ├── slug / display_name
    ├── base_instructions 或 model_messages.instructions_template
    ├── context_window / max_context_window
    ├── supported_reasoning_levels
    ├── shell_type / truncation_policy
    └── ...
```

关键点：

- **`model_provider` 只是选择 provider 条目**，不会自动发现模型。
- **模型元数据不会从 `/v1/models` 自动变成 Codex 目录**。Codex 需要的是 Codex 目录格式，不是 OpenAI 公共模型列表格式。[A]
- **没有目录条目时 Codex 仍可启动**，但会使用合成的 fallback 元数据（默认 272k 上下文、无推理档位、无模型专属 base instructions），行为可能与预期不同。[A]

## 2. Provider 配置

### 2.1 最小可用配置

```toml
# ~/.codex/config.toml
model = "<model-slug>"
model_provider = "<provider-id>"
model_context_window = 1000000

[model_providers.<provider-id>]
name = "<display-name>"
base_url = "http://127.0.0.1:3425/v1"
env_key = "<ENV_VAR_NAME>"
wire_api = "responses"
```

对应环境变量：

```bash
# 写入 Codex shell 实际读取的启动文件；本机非交互 zsh 读 ~/.zshenv
export <ENV_VAR_NAME>='<redacted>'
```

不要写进 `config.toml`：

```toml
# 不要这样做
experimental_bearer_token = "<token>"
```

`experimental_bearer_token` 源码中仍存在，但注释明确说“出于安全原因不鼓励”，因为配置文件容易被备份、同步和误提交。优先 `env_key`。[A]

### 2.2 字段语义

| 字段 | 作用 | 注意 |
|---|---|---|
| `name` | 显示名 | 可为空，但建议填写 |
| `base_url` | OpenAI 兼容 API 根 | Codex 会拼接 `/responses` 等路径；通常写到 `/v1` |
| `env_key` | 读取 API key 的环境变量名 | 变量为空/未设置时认证失败 |
| `env_key_instructions` | 认证失败时给用户的提示 | 可写“如何设置该变量” |
| `wire_api` | 线协议 | **0.167.1 只接受 `responses`**；`chat` 已移除并报错 |
| `requires_openai_auth` | 是否要求 OpenAI/ChatGPT 登录 | 自定义网关保持默认 `false` |
| `http_headers` | 固定附加请求头 | 不要放长期 token；会进配置文件 |
| `env_http_headers` | 从环境变量取值的请求头 | 变量不存在时该头不发送 |
| `query_params` | 附加 query 参数 | 少数网关需要 |
| `request_max_retries` | HTTP 重试次数 | 网关不稳定时再调 |
| `stream_max_retries` | 流断线重连次数 | 与 `stream_idle_timeout_ms` 配合 |
| `stream_idle_timeout_ms` | 流空闲超时 | 长推理网关可适当放大 |
| `supports_websockets` | 是否支持 Responses WebSocket | 多数第三方网关为 `false` |
| `supports_standalone_web_search` | 是否支持独立 web search 端点 | 不确定时不要开 |
| `model_catalog_url` | 从 provider 拉 Codex 目录 | 必须是 Codex 目录格式，不是 `/v1/models` |

`model_providers` 中不能覆盖内置 provider ID：`openai`、`amazon-bedrock`、`amazon-bedrock-runtime`、`gcp`、`ollama`、`lmstudio`；自定义请用新 ID。[A]

### 2.3 本机示例（已脱敏）

本机使用本地 magpie 网关：

```toml
model = "auto/deepseek-v4.1-flash"
model_provider = "magpie"
model_context_window = 1000000
model_catalog_json = "~/.codex/models_catalog.json"   # TOML 不展开 ~，但 Codex 会展开；建议写绝对路径

[model_providers.magpie]
name = "magpie"
base_url = "http://127.0.0.1:3425/v1"
env_key = "MAGPIE_API_KEY"
wire_api = "responses"

# 备用网关
[model_providers.ccswitch]
name = "ccswitch"
base_url = "http://127.0.0.1:51180/v1"
env_key = "OPENAI_API_KEY"
wire_api = "responses"
```

本机可用模型：

| slug | 显示名 | 上下文 | 默认推理档 | 可选推理档 |
|---|---|---:|---|---|
| `auto/deepseek-v4.1-flash` | DSF · DeepSeek V4.1 Flash | 1,000,000 | `high` | `low` / `high` / `max` |
| `auto/glm-5.3-flash` | GLM-5.3-Flash | 1,000,000 | `high` | `high` / `max` |
| `auto/glm-5.3` | GLM-5.3 | 1,000,000 | `high` | `low` / `high` / `max` |
| `auto/minimax-m3.1-flash` | MiniMax-M3.1-Flash | 1,000,000 | `high` | `low` / `medium` / `high` / `xhigh` / `max` |

推理档位因模型而异；实际以 `codex debug models` 输出为准。

> 回环地址 `127.0.0.1` 可以出现在公开文档中；真实外部网关域名、端口和 token 不要写进仓库。

### 2.4 切换 provider 与模型

```bash
# 会话内切换模型
/model

# 启动时指定模型
codex -m auto/glm-5.3

# 临时覆盖 provider
codex -c 'model_provider="ccswitch"' -m '<model-slug>'
```

`-c` 的值按 TOML 解析；字符串建议加引号：

```bash
codex -c 'model_provider="magpie"' -c 'model="auto/glm-5.3"'
```

### 2.5 命名 profile

0.167.1 的旧式 `profile = "<name>"` 已不再支持。现在用 `-p/--profile <name>`，加载 `$CODEX_HOME/<name>.config.toml`，叠加在基础 `config.toml` 之上。[A]

```bash
# ~/.codex/magpie.config.toml
model = "auto/glm-5.3"
model_provider = "magpie"

# ~/.codex/ccswitch.config.toml
model = "<model-slug>"
model_provider = "ccswitch"
```

```bash
codex -p magpie
codex -p ccswitch
```

profile 适合按任务切换模型，不适合存密钥。

## 3. 自定义模型目录

### 3.1 为什么需要

Codex 的 base instructions、工具模式和上下文窗口由**模型目录**决定，而不是由 provider 决定。自定义模型如果不进目录：

- 没有模型专属 base instructions；
- 没有 `supported_reasoning_levels`，推理档位选择受限；
- 上下文窗口回退到 272k；
- `shell_type`、`truncation_policy`、图像输入等能力按 fallback 处理。

本机 `prompt-design.md` 已记录：不同模型可以有不同 prompt family，不能假设所有会话共享同一份 base instructions。

### 3.2 文件结构

```json
{
  "models": [
    {
      "slug": "auto/glm-5.3",
      "display_name": "GLM-5.3",
      "description": "Custom gateway model",
      "context_window": 1000000,
      "max_context_window": 1000000,
      "default_reasoning_level": "high",
      "supported_reasoning_levels": [
        {"effort": "low",  "description": "Fast responses"},
        {"effort": "high", "description": "Greater reasoning depth"},
        {"effort": "max",  "description": "Maximum reasoning depth"}
      ],
      "shell_type": "unified_exec",
      "visibility": "list",
      "supported_in_api": true,
      "priority": 1,
      "truncation_policy": {"mode": "tokens", "limit": 10000},
      "input_modalities": ["text", "image"],
      "include_skills_usage_instructions": true,
      "base_instructions": "You are a coding agent running in the Codex CLI..."
    }
  ]
}
```

### 3.3 必填与关键字段

| 字段 | 必填 | 说明 |
|---|---|---|
| `slug` | 是 | 必须与 `model` / `-m` 一致；显式目录按精确 slug 匹配，不做前缀回退 |
| `display_name` | 是 | `/model` 显示名 |
| `base_instructions` 或 `model_messages.instructions_template` | 是 | 两者至少一个；都缺会解析失败 |
| `supported_reasoning_levels` | 是 | 可为空数组，但推理档位会受限 |
| `shell_type` | 是 | `unified_exec`；兼容别名 `default` / `local` / `shell_command` |
| `visibility` | 是 | `list` 才在模型选择器显示 |
| `supported_in_api` | 是 | 是否允许 API 调用 |
| `priority` | 是 | 默认模型选择排序 |
| `truncation_policy` | 是 | `{"mode":"tokens","limit":10000}` 或 bytes |
| `context_window` | 否 | 不填则回退 `max_context_window`，再回退 fallback |
| `max_context_window` | 否 | `model_context_window` 覆盖时会被它夹紧 |
| `default_reasoning_level` | 否 | 缺省时 `ModelPreset` 可能回退为 `none` |
| `input_modalities` | 否 | 支持图像时加 `image` |
| `use_responses_lite` | 否 | 仅在网关明确支持时开启 |
| `tool_mode` | 否 | `direct` / `code_mode` / `code_mode_only`；不确定时不要设 |
| `include_skills_usage_instructions` | 否 | 设为 `true` 才追加 `### How to use skills`；省略时默认 `false`，模型只看到目录，不知道要先读 `SKILL.md` |
| `include_plugin_usage_instructions` | 否 | 是否追加插件使用说明 |
| `include_apps_usage_instructions` | 否 | 默认 true |
| `support_verbosity` | 否 | 是否支持 Responses `text.verbosity`；不确定时 `false` |
| `experimental_supported_tools` | 否 | 实验工具白名单；不确定时留空 |

`base_instructions` 是旧字段；源码会在没有 `model_messages.instructions_template` 时把它提升为后者。新目录建议直接写 `model_messages.instructions_template`，旧目录继续用 `base_instructions` 也能工作。[A]

### 3.3.1 技能使用说明开关

Codex 的 `<skills_instructions>` 有两部分：

```text
技能目录（name / description / file locator）
  + ### How to use skills（触发规则、必须先读 SKILL.md、references/scripts 处理）
```

第二部分由模型目录字段控制：

```json
"include_skills_usage_instructions": true
```

该字段在 `ModelInfo` 中默认是 `false`。自定义模型目录省略它时，Codex 仍会列出技能，但不会告诉模型“先完整读取 `SKILL.md`”；表现就是技能目录可见、模型却不主动使用技能。[A]

每个模型条目都要设置，不能只在顶层写一次。改完后重启 Codex 会话，并用：

```bash
codex debug models | jq -r '.models[] | [.slug, .include_skills_usage_instructions] | @tsv'
codex debug prompt-input 'Reply with OK only.' | grep -c '### How to use skills'
```

第二条应输出 `1`。

### 3.4 目录加载规则

- `model_catalog_json` 在**启动时**加载；会话中途改文件不会自动重载。[A]
- 路径类型是 `AbsolutePathBuf`：`~` 会由 Codex 展开，相对路径按 `config.toml` 所在目录解析；为可移植性建议写绝对路径。
- 文件必须至少包含一个模型，否则启动报错。[A]
- 每个模型必须能解析出 instructions，否则报错。[A]
- 设置 `model_catalog_json` 后，provider 使用 `StaticModelsManager`（`ModelOrigin::ExplicitConfig`）；`list_models` 只返回目录条目，但 `get_model_info` 仍走 `construct_model_info_from_candidates`，所以未命中 slug 仍会合成 fallback。[A]
- 未设置目录时，走内置目录 + provider 目录刷新，并允许前缀/命名空间后缀匹配。[A]
- 未命中目录的 slug 会合成 fallback 元数据：272k 上下文、无推理档位、`visibility = none`、内置本地 instructions。[A]

### 3.5 上下文窗口优先级

```text
config.toml model_context_window
  └─ 被模型的 max_context_window 夹紧
       └─ 写入 model.context_window
            └─ 实际可用窗口 = context_window × effective_context_window_percent / 100
```

`effective_context_window_percent` 默认 95%。自动压缩阈值默认是上下文窗口的 90%，可被 `model_auto_compact_token_limit` 进一步压低。[A]

因此：

```toml
model_context_window = 1000000
```

并不等于模型一定能收到 1,000,000 token 输入；还要看 `effective_context_window_percent`、输出预留和压缩阈值。

### 3.6 base instructions 覆盖

优先级（从高到低）：

```text
config.toml base_instructions / instructions
  > model_instructions_file
  > 模型目录的 model_messages.instructions_template / base_instructions
```

`model_instructions_file` 会覆盖模型自带 instructions，源码注释明确“强烈不推荐”，因为偏离 Codex 认可的 instructions 很可能降低表现。[A]

不要把全局 `AGENTS.md` 当成 base instructions 的替代品：两者层级不同。`AGENTS.md` 是 user-role 指令，base instructions 由模型目录提供。

## 4. 验证

### 4.1 配置与目录

```bash
codex --version
codex doctor --all
codex debug models > /tmp/codex-models.json
```

检查：

```bash
jq -r '.models[] | [.slug, .display_name, .context_window, .default_reasoning_level, (.supported_reasoning_levels|map(.effort)|join(","))] | @tsv' \
  /tmp/codex-models.json
```

确认目录来源：

```bash
jq -r '.models[] | select(.slug=="auto/glm-5.3") | {
  slug, context_window, max_context_window,
  shell_type, use_responses_lite, tool_mode,
  has_instructions: ((.model_messages.instructions_template // .base_instructions) != null)
}' /tmp/codex-models.json
```

### 4.2 实际请求

```bash
codex exec --skip-git-repo-check 'Reply with exactly: OK'
```

如果返回 401/404，先看下一节。

### 4.3 查看模型实际看到的输入

```bash
codex debug prompt-input 'Reply with OK only.' > /tmp/codex-input.json
jq -r 'to_entries[] | [.key, .value.role, ((.value.content // [])|length)] | @tsv' /tmp/codex-input.json
```

注意：`debug prompt-input` 不含 base instructions 与完整工具定义，不能单独用它判断模型看到了什么；要和 `debug models`、rollout JSONL、固定源码交叉验证。详见 [`global-instruction/guides/codex-harness-inspection.md`](global-instruction/guides/codex-harness-inspection.md)。

### 4.4 会话 rollout 中的凭据

Codex 的 rollout JSONL 会记录工具输入/输出和用户消息，因此以下操作会把 token 写进历史：

- 在 prompt 里直接粘贴 token；
- 让 Agent 读取含 token 的文件（如 `~/.codex/config.toml`、`~/.claude/settings.json`、`.env`）；
- 运行会打印环境变量的命令（如未脱敏的 `env`、`printenv`、`set`）。

检查当前机器的 rollout 是否包含某个环境变量值（不打印 token 本身）：

```bash
python3 - <<'PY'
import glob, os
token = os.environ.get('MAGPIE_API_KEY')
if not token:
    raise SystemExit('MAGPIE_API_KEY is not set')
for path in glob.glob(os.path.expanduser('~/.codex/sessions/**/*.jsonl'), recursive=True):
    with open(path, 'rb') as fh:
        if token.encode() in fh.read():
            print(path)
PY
```

发现后的处置顺序：

1. **先轮换 token**：在网关侧吊销旧 token，生成新 token，更新 `~/.zshenv` 或凭据文件。
2. **再清理历史**：退出 Codex 后删除或脱敏对应 rollout；不要只改文件权限。
3. **检查扩散**：`~/.codex/archived_sessions/`、备份目录、同步盘、shell 历史、CI 日志。
4. **避免复发**：不要让 Agent 读含 token 的文件；需要检查配置时只打印键名，例如 `jq 'paths(scalars) | join(".")' ~/.codex/config.toml`。

> 删除 rollout 会丢失对应会话的恢复能力；先确认没有需要保留的上下文，或先导出脱敏副本。

## 5. 故障排查

| 现象 | 常见原因 | 处理 |
|---|---|---|
| `401 Unauthorized` | `env_key` 变量未设置/为空；网关不认该 key | 在 Codex 读取的启动文件里导出变量；用 `env \| grep <VAR>` 确认 |
| `404` on `/responses` | `base_url` 少了 `/v1` 或多写了 `/responses` | `base_url` 写到 API 根，例如 `http://127.0.0.1:3425/v1` |
| `wire_api = "chat" is no longer supported` | 0.167.1 只支持 Responses | 网关必须提供 `/v1/responses`；否则换网关或降级 Codex |
| 模型不在 `/model` 列表 | `visibility` 不是 `list`，或目录未加载 | 检查 `model_catalog_json` 与 `codex debug models` |
| 上下文只有 272k | 模型 slug 未命中目录，走了 fallback | 确认 slug 精确匹配；检查目录 JSON 解析 |
| 推理档位只有默认值 | `supported_reasoning_levels` 为空 | 按模型实际能力补档位（如 `low/high/max`） |
| 图像输入失败 | 目录未声明 `image`，或网关不支持 | 补 `input_modalities`；确认网关能力 |
| 工具调用异常 | 网关未完整实现 Responses 工具协议 | 先用纯文本验证；再逐项验证 shell/apply_patch/web_search |
| 长任务流中断 | 网关空闲超时 | 调大 `stream_idle_timeout_ms`、`stream_max_retries` |
| 修改目录不生效 | 目录只在启动时加载 | 退出并重启 Codex |
| 技能目录可见但模型不读 `SKILL.md` | `include_skills_usage_instructions` 缺失或为 `false` | 每个模型条目设为 `true`，重启后确认 prompt 含 `### How to use skills` |

### 5.1 认证头

`env_key` 指向的 key 默认以 `Authorization: Bearer <key>` 发送。[A] 如果网关要求自定义头：

```toml
[model_providers.<id>]
env_http_headers = { "X-Api-Key" = "<ENV_VAR_NAME>" }
```

不要把 token 直接写进 `http_headers`。

### 5.2 `requires_openai_auth`

自定义网关应保持：

```toml
requires_openai_auth = false
```

设为 `true` 会要求 OpenAI/ChatGPT 登录流程，通常不是第三方网关想要的行为。[A]

## 6. 高权限 Shell：别名与真实边界

### 6.1 权限模型

Codex 的命令执行受两层控制：

| 层 | 作用 | 相关参数 |
|---|---|---|
| sandbox | 限制文件/网络/进程能力 | `-s read-only`、`-s workspace-write`、`-s danger-full-access` |
| approval | 决定是否弹人工确认 | `-a on-request`、`-a never` |

两者独立：

```bash
codex -a never
# 不弹确认，但仍按 sandbox 策略执行；未设置 sandbox_mode 时默认 read-only

codex -s danger-full-access
# 放开 sandbox，但仍可能按 approval 策略弹确认

codex -a never -s danger-full-access
# 两者都放开

codex --dangerously-bypass-approvals-and-sandbox
# 等价于同时跳过 approval 与 sandbox；官方标注 EXTREMELY DANGEROUS
```

`--approve-for-me` 不是“全放开”：它把审批请求路由到自动审查，并使用 `workspace-write` sandbox。[B]

### 6.2 本机别名

本机 `~/.zshrc` 与 `~/.bashrc`：

```bash
alias codexx='codex --dangerously-bypass-approvals-and-sandbox'
alias claudex='claude --dangerously-skip-permissions'
```

用法：

```bash
codexx
codexx exec --skip-git-repo-check 'run the test suite'
```

### 6.3 别名不能保证什么

这是最重要的一节：

- **别名只在交互式 shell 展开**。脚本、CI、`subprocess`、`codex exec` 内部再调 `codex` 都不会继承别名。
- **Codex 自己的 shell 工具通常是非交互 zsh**，读取 `~/.zshenv`，不读 `~/.zshrc`；因此 Codex 内部执行 `codexx` 也可能找不到。
- **别名不是安全边界**。它只是把危险参数写进命令行；任何能改 shell 启动文件的人都能改它。
- **别名不会让远端/容器更安全**。它只改变本机 Codex 的 sandbox/approval，不改变网关、仓库或操作系统权限。
- **别名不会绕过组织策略**。托管配置、权限 profile、hook、sandbox 平台限制仍可能生效。

### 6.4 需要非交互使用时：wrapper

不要依赖 alias，写显式 wrapper：

```bash
mkdir -p ~/.local/bin
cat > ~/.local/bin/codexx <<'SH'
#!/usr/bin/env bash
set -euo pipefail
exec codex --dangerously-bypass-approvals-and-sandbox "$@"
SH
chmod +x ~/.local/bin/codexx
```

确认 `~/.local/bin` 在 PATH 中：

```bash
command -v codexx
codexx --version
```

wrapper 与 alias 的区别：

| 方式 | 交互 shell | 脚本/CI | Codex 内部 shell | 可审计 |
|---|---|---|---|---|
| alias | 是 | 否 | 通常否 | 差 |
| `~/.local/bin` wrapper | 是 | 是 | 是（若 PATH 可见） | 较好 |
| 显式完整命令 | 是 | 是 | 是 | 最好 |

### 6.5 推荐策略

| 场景 | 建议 |
|---|---|
| 日常开发 | 默认 `workspace-write` + `on-request` |
| 受控容器/一次性 VM | 可用 `codexx` 或 `--dangerously-bypass-approvals-and-sandbox` |
| CI | 显式写完整参数，不依赖 alias；优先在容器内运行 |
| 生产机/共享机 | 不要用全放开；用 sandbox + 审批 + 最小权限账号 |
| 需要自动审批但仍要 sandbox | `--approve-for-me` |
| 只免审批、保留 sandbox | `-a never` |

### 6.6 恢复默认权限

```bash
# 临时：本次会话不加危险参数
codex

# 检查当前配置
codex doctor --all

# 如果 config.toml 写了宽松默认值，改回
# approval_policy = "on-request"
# sandbox_mode = "workspace-write"
```

如果别名来自 `~/.zshrc` / `~/.bashrc`，删除对应行后新开 shell；如果来自 wrapper，删除 `~/.local/bin/codexx`。

### 6.7 不要做的事

- 不要把 `codexx` 写进项目 `AGENTS.md` 当作“授权”；`AGENTS.md` 是提示词，不是权限系统。
- 不要在共享机上用 `codexx` 跑来源不明的脚本。
- 不要让 `codexx` 继承含生产凭据的环境变量；先 `env -i` 或最小环境。
- 不要用别名绕过组织托管策略；那通常会被配置层拒绝或审计。
- 不要把“免确认”误解为“无审计”；rollout、shell 历史和网关日志仍可能记录命令。

## 7. 最小检查清单

```text
[ ] base_url 指向 OpenAI 兼容根，通常以 /v1 结尾
[ ] wire_api = "responses"
[ ] env_key 指向已导出的环境变量，变量非空
[ ] requires_openai_auth = false（自定义网关）
[ ] model_catalog_json 是绝对路径，JSON 可解析，至少一个模型
[ ] 每个模型有 base_instructions 或 model_messages.instructions_template
[ ] slug 与 model / -m 完全一致
[ ] context_window / max_context_window 与网关实际能力一致
[ ] supported_reasoning_levels 与网关实际支持一致
[ ] codex debug models 能看到目录条目
[ ] codex exec 能完成一次纯文本请求
[ ] 再验证 shell / apply_patch / 图像 / web_search 等实际用到的能力
[ ] 高权限 alias 只在受控环境使用，且有恢复默认权限的方法
```

## 8. 相关文档

- [`prompt-design.md`](prompt-design.md)：base instructions、WorldState、AGENTS.md、Skill、MCP、Hooks、Plugins、Subagents、Memories、Compaction 与缓存。
- [`global-instruction/README.md`](global-instruction/README.md)：可移植全局指令包的安装与放置矩阵。
- [`global-instruction/guides/codex-harness-inspection.md`](global-instruction/guides/codex-harness-inspection.md)：如何确认模型实际看到了什么。
