# Claude Code 自定义 Provider 与高权限 Shell

> 版本基线：Claude Code **2.1.322**（本机 `/home/ncpe/.local/bin/claude`）
> 调研日期：2026-11-11
> 适用范围：本机 Claude Code、`ANTHROPIC_BASE_URL` 指向的 Anthropic 兼容网关、`~/.claude/settings.json` 中的 `env` 块。
> 本文是版本/机器相关说明，**不属于** [`global-instruction/`](global-instruction/README.md) 可移植包。

本文回答三件事：

1. 如何把 Claude Code 接到非 Anthropic 官方 API（自定义网关、聚合器、本地代理）。
2. 本机如何配置模型、上下文窗口、推理档位与超时，以及哪些变量是官方变量、哪些是网关约定。
3. 如何用 shell 别名免人工确认执行高权限命令，以及这个做法**不能**保证什么。

文中不包含任何真实 token。本机实际网关地址、token 和模型映射见 `~/.claude/settings.json`；该文件含凭据，权限应为 `0600`，不要复制进仓库。

> ⚠️ **会话历史可能记录明文凭据。** 本机核对时发现 `~/.claude/projects/*/*.jsonl` 至少有两个文件包含 `settings.json` 里的 `ANTHROPIC_AUTH_TOKEN` 明文：一个来自用户直接粘贴，另一个来自工具读取 `settings.json` 后的 `tool_result`。会话 JSONL 默认权限是 `0600`，但仍会随备份、同步、共享目录扩散。处理方式见 §4.4。

## 0. 证据等级

| 标记 | 含义 | 来源 |
|---|---|---|
| **[A]** | 本机安装物直接确认 | Claude Code 2.1.322 可执行文件中的环境变量解析与权限检查 |
| **[B]** | 本机运行态确认 | `claude --help`、`~/.claude/settings.json`、`~/.zshrc` / `~/.bashrc` |
| **[C]** | 官方文档/通用协议约定 | Anthropic Messages API、Claude Code 设置文档 |
| **[D]** | 未验证/网关约定 | 具体网关是否接受某些变量、模型别名如何映射 |

## 1. 配置总览

Claude Code 的自定义接入主要靠环境变量：

```text
~/.claude/settings.json
├── model                  # 会话默认模型别名，如 "opus"
├── env
│   ├── ANTHROPIC_BASE_URL # Anthropic 兼容 API 根
│   ├── ANTHROPIC_AUTH_TOKEN
│   ├── ANTHROPIC_MODEL
│   ├── ANTHROPIC_DEFAULT_OPUS_MODEL
│   ├── ANTHROPIC_DEFAULT_SONNET_MODEL
│   ├── ANTHROPIC_DEFAULT_HAIKU_MODEL
│   ├── CLAUDE_CODE_MAX_CONTEXT_TOKENS
│   ├── CLAUDE_CODE_MAX_OUTPUT_TOKENS
│   ├── CLAUDE_CODE_EFFORT_LEVEL
│   └── API_TIMEOUT_MS
├── permissions
└── skipDangerousModePermissionPrompt
```

关键点：

- **`ANTHROPIC_BASE_URL` 决定请求发往哪里**；不设置时走 Anthropic 官方。
- **`ANTHROPIC_AUTH_TOKEN` 以 `Authorization: Bearer <token>` 发送**；`ANTHROPIC_API_KEY` 走 `x-api-key` 语义。[A]
- **模型别名 `opus` / `sonnet` / `haiku` 会被 `ANTHROPIC_DEFAULT_*_MODEL` 覆盖**，因此可以在不修改 `model` 的情况下把别名映射到第三方模型。[A]
- **`settings.json` 的 `env` 块在启动时注入进程环境**；`--settings` 的 `env` 会覆盖同名 shell 变量（实测 2.1.322）。[B]

## 2. 自定义 Provider 配置

### 2.1 最小可用配置

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "<gateway-base-url>",
    "ANTHROPIC_AUTH_TOKEN": "<REDACTED>",
    "ANTHROPIC_MODEL": "<model-slug>"
  }
}
```

保存到 `~/.claude/settings.json`，并收紧权限：

```bash
chmod 600 ~/.claude/settings.json
```

不要把 token 写进项目 `.claude/settings.json`、`.mcp.json`、`CLAUDE.md` 或 shell 历史。

### 2.2 字段语义

| 变量 | 作用 | 注意 |
|---|---|---|
| `ANTHROPIC_BASE_URL` | Anthropic 兼容 API 根 | 通常不要以 `/v1` 结尾；以网关文档为准 |
| `ANTHROPIC_AUTH_TOKEN` | Bearer token | 以 `Authorization: Bearer` 发送 |
| `ANTHROPIC_API_KEY` | API key | 以 `x-api-key` 语义发送；与 `AUTH_TOKEN` 二选一 |
| `ANTHROPIC_MODEL` | 默认模型 | 可写完整 slug |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | `opus` 别名映射 | `/model opus` 时使用 |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | `sonnet` 别名映射 | `/model sonnet` 时使用 |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | `haiku` 别名映射 | 后台小任务/快速模型 |
| `ANTHROPIC_SMALL_FAST_MODEL` | 旧的快速模型变量 | 仍被 2.1.322 读取；新配置优先用 `ANTHROPIC_DEFAULT_HAIKU_MODEL` |
| `ANTHROPIC_DEFAULT_*_MODEL_NAME` | 别名显示名 | 只影响 UI 显示，不改变请求模型 |
| `ANTHROPIC_DEFAULT_*_MODEL_SUPPORTED_CAPABILITIES` | 声明别名模型能力 | 网关模型需要显式能力声明时使用 |
| `CLAUDE_CODE_MAX_CONTEXT_TOKENS` | 覆盖上下文窗口 | 主要对未知模型生效；已知模型有自己的窗口表 |
| `CLAUDE_CODE_MAX_OUTPUT_TOKENS` | 最大输出 token | 会被模型/服务端上限夹紧 |
| `CLAUDE_CODE_EFFORT_LEVEL` | 推理档位 | `low`/`medium`/`high`/`xhigh`/`max` |
| `API_TIMEOUT_MS` | 请求超时 | 长任务网关可调大 |
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | 关闭非必要流量 | 第三方网关常用 |
| `DISABLE_AUTOUPDATER` | 关闭自动更新 | 固定版本时常用 |
| `CLAUDE_CODE_DISABLE_UNKNOWN_MODEL_WINDOW_ENFORCEMENT` | 允许未知模型使用配置窗口 | 谨慎使用，可能超出真实能力 |
| `CLAUDE_CODE_MODEL_CATALOG` | 控制内置模型目录 | 第三方网关通常不需要；`off` 可关闭目录拉取 |
| `CLAUDE_CODE_MODEL_CATALOG_URL` | 自定义模型目录 URL | 支持 `file://`；目录格式未在本文验证 |

`ANTHROPIC_DEFAULT_*_MODEL_NAME` 只改显示名，不要用它切换模型；真正决定请求的是 `ANTHROPIC_DEFAULT_*_MODEL` 和 `ANTHROPIC_MODEL`。[A]

### 2.3 本机示例（已脱敏）

```json
{
  "model": "opus",
  "env": {
    "ANTHROPIC_BASE_URL": "<gateway-base-url>",
    "ANTHROPIC_AUTH_TOKEN": "<REDACTED>",
    "ANTHROPIC_MODEL": "auto/glm-5.3",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "auto/deepseek-v4.1-flash",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "auto/glm-5.3",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "auto/minimax-m3.1-flash",
    "CLAUDE_CODE_MAX_CONTEXT_TOKENS": "1000000",
    "CLAUDE_CODE_MAX_OUTPUT_TOKENS": "128000",
    "CLAUDE_CODE_EFFORT_LEVEL": "max",
    "API_TIMEOUT_MS": "1200000",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
    "DISABLE_AUTOUPDATER": "1"
  },
  "skipDangerousModePermissionPrompt": true
}
```

本机模型映射：

| 入口 | 实际模型 |
|---|---|
| 默认 `model: "opus"` | `auto/deepseek-v4.1-flash` |
| `ANTHROPIC_MODEL` | `auto/glm-5.3` |
| `sonnet` | `auto/glm-5.3` |
| `haiku` | `auto/minimax-m3.1-flash` |

> 本机还设置了 `ANTHROPIC_REASONING_MODEL` 与 `ANTHROPIC_BETA_HEADER`。在本机 2.1.322 可执行文件中用字符串检索**未找到**这两个名字，因此更可能是网关侧约定，而不是 Claude Code 官方开关。实际是否生效取决于网关；不要把依赖它们的配置当成可移植方案。[D]

### 2.4 模型切换

```bash
# 会话内
/model opus
/model sonnet
/model auto/glm-5.3

# 启动时
claude --model sonnet
claude --model auto/glm-5.3

# 推理档位
claude --effort high
```

`--fallback-model` 可在主模型不可用时按顺序回退：

```bash
claude --fallback-model auto/glm-5.3,auto/minimax-m3.1-flash
```

### 2.5 多套配置切换

推荐用 `--settings` 叠加，而不是反复手改 `~/.claude/settings.json`：

```bash
claude --settings ~/.claude/providers/magpie.json
claude --settings '{"env":{"ANTHROPIC_MODEL":"auto/glm-5.3"}}'
```

`--settings` 可以传文件路径或 JSON 字符串；它作为额外设置层加载。[B]

不要把含 token 的 provider 文件提交到仓库。若必须落盘，放在 `~/.claude/providers/`，权限 `0600`。

### 2.6 环境变量优先级

实测 2.1.322 的生效顺序（从高到低）：

```text
--settings 的 env
  > 用户/项目 settings.json 的 env
  > 真实 shell 环境变量
  > Claude Code 默认值
```

依据（均为本机实测）：[B]

- shell 设 `ANTHROPIC_MODEL=env-override-model`、`--settings` 设 `ANTHROPIC_MODEL=settings-override-model`，请求使用后者。
- shell 设 `ANTHROPIC_MODEL=env-override-model`、不传 `--settings`，请求仍使用 `~/.claude/settings.json` 里的 `auto/glm-5.3`。
- shell 设 `ANTHROPIC_BASE_URL=http://127.0.0.1:9`，请求仍成功走 settings 中的网关。

因此：

- `--settings` 适合临时切换 provider/模型，但会覆盖 settings 文件与 shell 的同名变量；
- `~/.claude/settings.json` 的 `env` 会覆盖 `~/.zshenv` / `~/.zshrc` 中的同名 `ANTHROPIC_*`；
- 只有用 `--setting-sources project` 等跳过用户设置时，shell 变量才直接生效；
- 排查“为什么模型没变”时，按 `--settings` → settings 文件 → shell 环境 的顺序检查。

## 3. 上下文与推理

### 3.1 上下文窗口

`CLAUDE_CODE_MAX_CONTEXT_TOKENS` 是覆盖值，不是“保证值”。源码中它只在未知模型等路径上作为窗口来源之一，已知模型优先使用自己的窗口表；最终还会受自动压缩策略影响。[A]

```json
"CLAUDE_CODE_MAX_CONTEXT_TOKENS": "1000000"
```

只应在网关确实支持该窗口时设置。设置过大而网关不支持，会在长上下文时返回错误或截断。

### 3.2 输出上限

`CLAUDE_CODE_MAX_OUTPUT_TOKENS` 会被模型/服务端上限夹紧；源码中明确该变量不能提高非流式请求的硬上限。[A]

### 3.3 推理档位

```json
"CLAUDE_CODE_EFFORT_LEVEL": "max"
```

也可用 `--effort` 覆盖。若模型不支持该档位，会被夹紧到支持的最高档。[A]

### 3.4 超时

```json
"API_TIMEOUT_MS": "1200000"
```

第三方网关长推理容易超时；先调大超时，再考虑重试。不要用无限重试掩盖网关不稳定。

## 4. 验证

### 4.1 配置是否生效

```bash
claude --version
claude doctor
```

检查当前进程环境：

```bash
env | grep -E '^(ANTHROPIC|CLAUDE_CODE|API_TIMEOUT_MS)' | sed -E 's/=.*/=<REDACTED>/'
```

只打印变量名，不打印值。

### 4.2 实际请求

```bash
claude -p 'Reply with exactly: OK'
```

如果失败，先看下一节。

### 4.3 查看请求快照

Claude Code 会在会话 JSONL 中记录请求结构。`api-request` 本身不含认证头，但用户消息与 `tool_result` 可能含明文 token（见 §4.4）。位置通常在：

```text
~/.claude/projects/<project-slug>/<session-id>.jsonl
```

可用以下命令查看最近的 `api-request` / `prompt_snapshot` 条目：

```bash
ls -t ~/.claude/projects/*/*.jsonl | head -1
```

具体字段与观测方法见 [`prompt-design.md`](prompt-design.md) §9。

### 4.4 会话历史中的凭据

会话 JSONL 会记录工具输入/输出和用户消息，因此以下操作会把 token 写进历史：

- 在 prompt 里直接粘贴 token；
- 让 Agent 读取 `~/.claude/settings.json`、`.env`、`credentials` 文件；
- 运行会打印环境变量的命令（如未脱敏的 `env`、`printenv`、`set`）。

检查当前项目历史是否包含 token（不打印 token 本身）：

```bash
python3 - <<'PY'
import glob, json, os
token = json.load(open(os.path.expanduser('~/.claude/settings.json')))['env']['ANTHROPIC_AUTH_TOKEN']
for path in glob.glob(os.path.expanduser('~/.claude/projects/*/*.jsonl')):
    with open(path, 'rb') as fh:
        if token.encode() in fh.read():
            print(path)
PY
```

发现后的处置顺序：

1. **先轮换 token**：在网关侧吊销旧 token，生成新 token，更新 `~/.claude/settings.json`。
2. **再清理历史**：退出 Claude Code 后删除或脱敏对应 JSONL；不要只改文件权限。
3. **检查扩散**：备份目录、`~/.claude/backups/`、同步盘、shell 历史（`~/.zsh_history`）、CI 日志。
4. **避免复发**：不要让 Agent 读含 token 的文件；需要检查配置时用只打印键名的命令，例如 `jq 'paths(scalars) | join(".")' ~/.claude/settings.json`。

> 删除历史会丢失对应会话的恢复能力；先确认没有需要保留的上下文，或先导出脱敏副本。

## 5. 故障排查

| 现象 | 常见原因 | 处理 |
|---|---|---|
| `401 Unauthorized` | token 缺失/过期；`AUTH_TOKEN` 与 `API_KEY` 冲突 | 检查 `env`；只保留一种认证 |
| `404` | `ANTHROPIC_BASE_URL` 多了 `/v1` 或路径不对 | 按网关文档调整根路径 |
| 模型未切换 | `--settings` 覆盖了 settings 文件；或用户设置未加载 | 检查本次 `--settings`，再看 `env \| grep ANTHROPIC` 与 `--setting-sources` |
| 仍走官方 | `settings.json` 未加载/JSON 无效 | `claude doctor`；检查 `--setting-sources` |
| 上下文只有默认值 | 模型未知或窗口未生效 | 检查 `CLAUDE_CODE_MAX_CONTEXT_TOKENS` 与网关能力 |
| 输出被截断 | 超过模型/服务端输出上限 | 降低单次输出，分段处理 |
| 长任务超时 | `API_TIMEOUT_MS` 太小 | 调大；同时检查网关空闲超时 |
| 工具调用异常 | 网关未完整实现 Anthropic 工具协议 | 先用纯文本验证，再逐项验证 Bash/Edit/Read |
| 启动即退出（root） | `--dangerously-skip-permissions` 禁止 root/sudo | 用非 root 用户，或不要绕过权限 |

### 5.1 认证头

Claude Code 2.1.322 的行为：

```text
ANTHROPIC_AUTH_TOKEN  → Authorization: Bearer <token>
ANTHROPIC_API_KEY     → x-api-key 语义
```

两者同时设置时可能产生歧义；只保留网关要求的那一个。[A]

### 5.2 网关兼容性

第三方网关需要兼容：

- `/v1/messages` 请求与流式响应；
- Anthropic 工具调用块；
- `system`、`tools`、`max_tokens` 等字段；
- 可选 prompt caching beta 头。

如果网关只兼容 OpenAI Chat Completions，不能直接把 `ANTHROPIC_BASE_URL` 指过去；需要协议转换层。

## 6. 高权限 Shell：别名与真实边界

### 6.1 权限模式

Claude Code 2.1.322 的 `--permission-mode` 可选值：[B]

| 模式 | 行为 |
|---|---|
| `manual`（旧名 `default`） | 默认人工确认 |
| `acceptEdits` | 自动接受文件编辑，其他操作仍按策略 |
| `auto` | 模型分类器决定是否批准 |
| `dontAsk` | 不弹确认；未预先批准的操作直接拒绝 |
| `plan` | 只规划，不执行工具 |
| `bypassPermissions` | 绕过所有权限检查 |

`--dangerously-skip-permissions` 等价于 `bypassPermissions`。[A]

`--allow-dangerously-skip-permissions` 只是“允许该选项作为可选”，不会默认启用；适合需要让子进程/恢复会话能够选择 bypass 的场景。[B]

### 6.2 本机别名

本机 `~/.zshrc` 与 `~/.bashrc`：

```bash
alias claudex='claude --dangerously-skip-permissions'
alias codexx='codex --dangerously-bypass-approvals-and-sandbox'
```

用法：

```bash
claudex
claudex -p 'run the test suite'
```

### 6.3 别名不能保证什么

- **别名只在交互式 shell 展开**。脚本、CI、`subprocess` 不会继承。
- **Claude Code 的 Bash 工具通常是非交互 shell**，不读 `~/.zshrc` / `~/.bashrc`；别名不一定可见。
- **别名不是安全边界**。任何能改 shell 启动文件的人都能改它。
- **`--dangerously-skip-permissions` 在 root/sudo 下会被拒绝**；源码中有明确检查，错误信息为 “cannot be used with root/sudo privileges for security reasons”。[A]
- **`--restricted` 会拒绝 `bypassPermissions`**；托管策略也可能覆盖本地设置。[A]
- **别名不会绕过网关或操作系统权限**。它只改变 Claude Code 的权限检查。

### 6.4 需要非交互使用时：wrapper

```bash
mkdir -p ~/.local/bin
cat > ~/.local/bin/claudex <<'SH'
#!/usr/bin/env bash
set -euo pipefail
exec claude --dangerously-skip-permissions "$@"
SH
chmod +x ~/.local/bin/claudex
```

确认：

```bash
command -v claudex
claudex --version
```

### 6.5 更细粒度的替代方案

如果只是想让某些命令免确认，不要直接全绕过：

```bash
# 只允许特定工具/命令（空格分隔，按 --help 示例）
claude --allowedTools "Bash(git status)" "Bash(git diff)" "Read"

# 明确拒绝危险工具
claude --disallowedTools "Bash(rm *)" "Bash(git push *)"

# 不弹确认，但未预先批准的直接拒绝
claude --permission-mode dontAsk
```

`permissions.allow` 是允许列表，不等于 bypass；未列出的操作仍按模式处理。[B]

### 6.6 推荐策略

| 场景 | 建议 |
|---|---|
| 日常开发 | 默认模式；用 `acceptEdits` 减少编辑确认 |
| 受控容器/一次性 VM | 可用 `claudex` 或 `--permission-mode bypassPermissions` |
| CI | 显式写完整参数；优先容器内运行；不要 root |
| 生产机/共享机 | 不要全绕过；用 `dontAsk` + 允许列表 |
| 只读分析 | `--permission-mode plan` 或 `--restricted` |
| 需要自动审批 | `--permission-mode auto`（若组织允许） |

### 6.7 恢复默认权限

```bash
# 临时：本次会话不加危险参数
claude

# 检查当前设置
claude doctor

# 如果 settings.json 设了默认 bypass，改回
# "permissions": { "defaultMode": "manual" }   # 或删除 defaultMode
```

如果别名来自 `~/.zshrc` / `~/.bashrc`，删除对应行后新开 shell；如果来自 wrapper，删除 `~/.local/bin/claudex`。

`skipDangerousModePermissionPrompt: true` 只抑制“危险模式”启动确认，不等于启用 bypass；它常与别名配合使用，但不改变权限模式本身。[A]

### 6.8 不要做的事

- 不要在 root/sudo 下使用 `--dangerously-skip-permissions`；会被拒绝，且不应尝试绕过该检查。
- 不要把 `claudex` 写进项目 `CLAUDE.md` 当作“授权”；`CLAUDE.md` 是提示词，不是权限系统。
- 不要在共享机上用 `claudex` 跑来源不明的脚本。
- 不要让 `claudex` 继承生产凭据；先清理环境变量。
- 不要把“免确认”误解为“无审计”；会话 JSONL、shell 历史和网关日志仍可能记录操作。

## 7. 最小检查清单

```text
[ ] ANTHROPIC_BASE_URL 指向 Anthropic 兼容网关，路径符合网关文档
[ ] 只设置一种认证：ANTHROPIC_AUTH_TOKEN 或 ANTHROPIC_API_KEY
[ ] settings.json 权限 0600，且不在仓库中
[ ] 本次 `--settings` 没有意外覆盖 settings.json；用户设置确实被加载
[ ] ANTHROPIC_MODEL / ANTHROPIC_DEFAULT_*_MODEL 与网关模型列表一致
[ ] CLAUDE_CODE_MAX_CONTEXT_TOKENS 不超过网关真实能力
[ ] CLAUDE_CODE_EFFORT_LEVEL 是模型支持的档位
[ ] API_TIMEOUT_MS 足够长，且网关空闲超时匹配
[ ] `claude -p 'Reply with exactly: OK'` 能成功
[ ] 再验证 Bash / Edit / Read / MCP 等实际用到的工具
[ ] 高权限 alias 只在受控环境使用，且有恢复默认权限的方法
```

## 8. 相关文档

- [`prompt-design.md`](prompt-design.md)：Claude Code 2.1.322 的请求分层、CLAUDE.md/AGENTS.md/rules、auto memory、Skill、MCP、Hooks、Plugins、Subagents、Compaction 与缓存。
- [`global-instruction/README.md`](global-instruction/README.md)：可移植全局指令包的安装与放置矩阵。
