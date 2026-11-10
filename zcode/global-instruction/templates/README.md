# Templates

本目录是**模板**，不是可直接使用的配置。复制后替换 `<...>` 占位符，按目标机器/项目调整。

| 文件 | 用途 | 复制到 |
|---|---|---|
| `machine-profile.example.md` | 机器事实（OS/CPU/RAM/工具链/网络/浏览器/字体/技能根/MCP/守护） | 本机 `machine-profile.md`（不进仓库） |
| `MEMORY.example.md` | ZCode 原生持久记忆格式（`MEMORY.md` + 主题文件） | `<memoryRoot>/MEMORY.md` 与主题文件 |
| `mcp.example.json` | MCP servers 配置结构（http/stdio） | `~/.zcode/cli/config.json` 的 `mcp.servers` |
| `hooks.example.json` | hooks 事件配置结构（6 个事件） | `~/.zcode/cli/config.json` 的 `hooks` |
| `plugins.example.json` | 插件启用清单结构 | `~/.zcode/cli/config.json` 的 `plugins.enabledPlugins` |
| `quality.just` | 项目 `justfile` 可导入的质量门禁（secrets/shellcheck/git） | 项目可访问路径，`justfile` 里 `import` |
| `env-check.example.sh` | 通用环境体检脚本骨架 | 本机脚本目录，按机器增删检查项 |

## 使用规则

- `<REDACTED>`、`<path-to-...>`、`<capture-command>` 等占位符**必须替换**；不要原样运行。
- 真实 token/API key 只放在 `~/.zcode/cli/config.json` 或环境变量；配置文件 `chmod 600`。
- `machine-profile.md` 含主机名/路径/端口，**不要提交到公共仓库**；仓库只保留 `*.example.md`。
- `machine-profile.md` 解析顺序：先找与 `AGENTS.md` 同目录的那份，再找 `~/.zcode/machine-profile.md`。
- `quality.just` 的 `secrets` 只扫暂存区（先 `git add`），失败即失败；**不会**回退到更宽的全量历史扫描。工具缺失默认失败，临时放宽用 `QUALITY_LENIENT=1`。
- 若项目已有同名 `quality` recipe，把模板里的 `quality` 改名（如 `quality-common`）再 import，避免 just 重复 recipe 报错。
- `hooks.example.json` 是**命令执行配置**，安装前审查命令与参数；示例里 `PostToolUseFailure` 沿用 `post-tool-use` 是某些 hook 实现的兼容写法，其他 hook 实现按自己的参数调整。
- 项目级 MCP 声明需要 workspace trust；不要把 clone 来的仓库默认信任。
- `plugins.example.json` 的启用/禁用变化对新会话生效。
- `env-check.example.sh` 只把硬失败计入 `FAIL`；工具缺失/未设置多为 `WARN`，按本机要求增删。
- `mcp.example.json` / `hooks.example.json` 只展示结构；ZCode 的实际 schema 以当前版本为准。

## 校验

```bash
cd ..
bash validate.sh                     # 包级自检（JSON/shell/链接/密钥/门禁回归）
cd templates
python3 -m json.tool mcp.example.json >/dev/null
python3 -m json.tool hooks.example.json >/dev/null
python3 -m json.tool plugins.example.json >/dev/null
bash -n env-check.example.sh
# 若安装了 just：
just --justfile quality.just --list
```
