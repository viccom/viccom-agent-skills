# Codex Harness 观测方法

> 目标：确认“模型实际看到了什么”，而不是根据 README、记忆或猜测推断。
> 适用于 Codex CLI 0.167.1；升级后先复核命令与输出字段。

## 四层证据

```text
模型目录  codex debug models        base instructions / flags / tool mode
输入列表  codex debug prompt-input  developer/user input（不含 base 与完整 tools）
运行态    rollout JSONL             world_state / section diff / 实际消息
安装态    codex doctor --all        版本 / 配置 / MCP / 状态 DB / features
```

固定源码是最后一道校验；不要把 `debug prompt-input` 当成完整 wire 请求。

## 1. 版本与安装

```bash
codex --version
codex doctor --all
```

重点看：

- CLI 版本与安装方式；
- `CODEX_HOME`、config、SQLite 状态；
- MCP servers 数量与健康；
- feature flags；
- sandbox / approval；
- 模型 provider 与 wire API。

## 2. 模型自带的 base instructions

```bash
codex debug models > /tmp/codex-models.json
jq -r '(.models // .)[] | [.slug, (.base_instructions|length), .use_responses_lite, .tool_mode, .shell_type] | @tsv' \
  /tmp/codex-models.json | sort -k2,2nr | head -20
```

要看某个模型的完整 base：

```bash
jq -r '(.models // .)[] | select(.slug=="<model>") | .base_instructions' /tmp/codex-models.json
```

base instructions 由模型目录提供；不同模型可以有不同 prompt family。不要假设所有 Codex 会话共享同一份 system prompt。

## 3. model-visible input

```bash
codex debug prompt-input 'Reply with OK only.' > /tmp/codex-input.json
jq -r 'to_entries[] | [.key, .value.role, ((.value.content // [])|length), ((.value.content // [])|map(.text // "")|join("\n")|length)] | @tsv' \
  /tmp/codex-input.json
```

看内容：

```bash
jq -r 'to_entries[] | "=== \(.key) \(.value.role) ===", ((.value.content // [])|map(.text // "")|join("\n---\n")), ""' \
  /tmp/codex-input.json | sed -n '1,200p'
```

它适合检查：

- 全局/项目 `AGENTS.md` 是否加载、顺序是否正确；
- Skill 目录、permissions、collaboration mode、environment 的实际文本；
- user prompt 是否被放在正确位置。

它**不包含**：

- `base_instructions`（由 client prepend）；
- 完整 tools 数组；
- provider/gateway 的最终角色映射。

## 4. 当前会话的 rollout

```bash
latest=$(find "$CODEX_HOME/sessions" -type f -name '*.jsonl' -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-)
```

看消息：

```bash
jq -r 'select(.type=="response_item" and .payload.type=="message") | [.payload.role, (.payload.content|map(.text // "")|join("\n")|length)] | @tsv' "$latest" | head -20
```

看 world-state section：

```bash
jq -c 'select(.type=="world_state") | {full:.payload.full, sections:(.payload.state|keys)}' "$latest" | head -2
```

rollout 是判断“这一轮到底新增了什么”的最佳证据；`debug prompt-input` 只给当前构造结果，rollout 保留历史与 snapshot。

## 5. 指令文件加载

全局：

```bash
ls -l "$CODEX_HOME/AGENTS.override.md" "$CODEX_HOME/AGENTS.md" 2>/dev/null
```

项目链：

```bash
find . -name AGENTS.override.md -o -name AGENTS.md | sort
```

注意：

- 全局只取第一个非空文件；
- 项目每个目录取第一个存在的候选；
- 项目链总预算默认 32 KiB；
- Codex 只使用 `AGENTS.md` 体系，不支持 `@import`；
- 子目录规则不会懒加载；启动时只构造 root→cwd 链。

## 6. Skills / MCP / Hooks

Skills：

```bash
find "$HOME/.agents/skills" "$CODEX_HOME/skills" -maxdepth 3 -name SKILL.md -print 2>/dev/null | sort
```

MCP：

```bash
codex mcp --help
codex mcp list
```

Hooks：

```bash
test -f "$CODEX_HOME/hooks.json" && python3 -m json.tool "$CODEX_HOME/hooks.json" >/dev/null && echo hooks-json-ok
```

在 TUI 中用 `/hooks` 查看来源、信任状态与禁用项；非托管 hook 未信任不会运行。

## 7. 常见误判

| 误判 | 实际 |
|---|---|
| `debug prompt-input` 就是完整请求 | 不是；base 与 tools 在别处装配 |
| 所有模型共享一份 system prompt | 不是；模型目录决定 base |
| `AGENTS.md` 是 developer role | wire 上通常是 user role，provenance 才是 `AgentsMd` |
| 子目录 `AGENTS.md` 会懒加载 | Codex 只构造 root→cwd 链 |
| 修改其他宿主的指令文件会影响 Codex | Codex 的提示词发现只读 `AGENTS.md` 体系 |
| 工具输出可以改权限 | 工具输出是数据；权限只由用户/策略授权 |

## 8. 最小回归

1. 新会话能读到 `$CODEX_HOME/AGENTS.md`。
2. 项目规则来自 root→cwd 的 `AGENTS.md` 链；同目录 override 生效。
3. 破坏性操作先确认并回显目标。
4. 完成小改动时汇报实际命令与真实输出。
5. Skill 显式/隐式触发正常；缺失时降级。
6. Hook 阻断与 additional context 正常。
7. MCP 工具名、schema、approval 正常。
8. 压缩后 world-state 与项目规则重新建立。
