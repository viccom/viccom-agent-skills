# Templates

本目录是**模板**，不是可直接使用的配置。复制后替换 `<...>` 占位符，按目标机器/项目调整。

| 文件 | 用途 | 复制到 |
|---|---|---|
| `machine-profile.example.md` | 机器事实（OS/CPU/RAM/工具链/网络/浏览器/字体/Codex 布局/MCP/hooks/plugins/memories） | 本机 `machine-profile.md`（不进仓库） |
| `MEMORY.example.md` | Codex Memories 结构、读取路径与写入纪律（默认关闭） | 仅参考；启用后按说明审计 |
| `mcp.example.toml` | MCP servers 配置结构（stdio/http） | `$CODEX_HOME/config.toml` 的 `[mcp_servers.<id>]` |
| `hooks.example.json` | hooks 事件配置结构 | `$CODEX_HOME/hooks.json`，或合并为 `config.toml` 的 `[hooks]` |
| `plugins.example.toml` | 插件启用与 MCP 工具策略结构 | `$CODEX_HOME/config.toml` 的 `[plugins.*]` |
| `skill-routing.example.md` | 机器本地技能路由快照 | `$CODEX_HOME/skill-routing.md` |
| `skill-install.example.sh` | 从本仓库安装精选编程技能（软链，幂等） | 直接运行；`--dry-run` 先预览 |
| `quality.just` | 项目 `justfile` 可导入的质量门禁（secrets/shellcheck/git） | 项目可访问路径，`justfile` 里 `import` |
| `env-check.example.sh` | 通用环境体检脚本骨架 | 本机脚本目录，按机器增删检查项 |

## 使用规则

- `<REDACTED>`、`<path-to-...>`、`<command>` 等占位符**必须替换**；不要原样运行。
- 真实 token/API key 只放在环境变量或 `0600` 文件；不写进 `config.toml` 的明文值，不提交到仓库。
- `machine-profile.md` 含主机名/路径/端口，**不要提交到公共仓库**；仓库只保留 `*.example.md`。
- `machine-profile.md` 解析顺序：先找与全局 `AGENTS.md` 同目录的那份，再找 `$CODEX_HOME/machine-profile.md`。
- `env-check.example.sh` 会检查自定义模型目录的 `include_skills_usage_instructions`；该字段不是 `true` 时，Codex 只列技能目录，不注入 `### How to use skills`。
- `hooks.example.json` 是**命令执行配置**：安装前审查命令与参数；非托管 hook 需要审查/信任，项目级 hook 需项目 trust。
- 项目级 MCP 配置（`.codex/config.toml`）需要项目 trust；不要因为 clone 了仓库就自动信任。
- `plugins.example.toml` 的启用/禁用变化通常对新会话生效；插件可贡献 Skill、MCP、App、hooks。
- `quality.just` 的 `secrets` 只扫暂存区（先 `git add`），失败即失败；**不会**回退到更宽的全量历史扫描。工具缺失默认失败，临时放宽用 `QUALITY_LENIENT=1`。
- `skill-routing.md` 只记录本机快照；运行时 Skills 元数据优先。
- `skill-install.example.sh` 只软链精选集合，不删除现有技能；遇到同名但指向不同路径的目标会报 `CONFLICT` 并停止。Codex 技能目录默认只占上下文约 2%，不要一次装完整仓库。

## 校验

```bash
cd ..
bash validate.sh                     # 包级自检（JSON/TOML/shell/链接/密钥/预算/门禁回归）
cd templates
python3 -m json.tool hooks.example.json >/dev/null
python3 - <<'PY'
import tomllib
for f in ("mcp.example.toml", "plugins.example.toml"):
    with open(f, "rb") as fh:
        tomllib.load(fh)
    print(f, "ok")
PY
bash -n env-check.example.sh
# 若安装了 just：
just --justfile quality.just --list
```
