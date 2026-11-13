# Machine Profile（示例模板）

> 复制为 `$CODEX_HOME/machine-profile.md`（或与全局 `AGENTS.md` 同目录），填入本机事实。
> **不要提交含真实凭据、内部地址或主机名的版本。** 本文件只描述机器事实，不放行为规则。

## 0. 元信息

- 主机名/用途：`<hostname>` / `<shared KVM | private workstation | CI runner>`
- OS：`<Ubuntu 24.04 LTS | ...>`
- 最后核对：`<YYYY-MM-DD>`
- 维护者：`<name or team>`

## 1. 硬件与资源

| 项 | 值 | 检测命令 |
|---|---|---|
| CPU 核数 | `<n>` | `nproc` |
| 内存 | `<GiB>` | `free -h` |
| 磁盘余量 | `<GiB>` | `df -h <workdir>` |
| 是否共享 | `<yes/no; who else>` | — |

编译并发默认值：

```text
jobs = <n>            # 共享机建议 min(6, max(1, cores / 3))
OOM 时降到 jobs = <n>
```

## 2. Shell 与 PATH

- 交互 shell：`<zsh | bash>`
- Codex shell 工具实际读取的启动文件：`<~/.zshenv | ~/.bashrc>`
- PATH 首位：`<~/.local/bin | ...>`
- 包管理器：`<apt | dnf | pacman | brew>`
- 版本管理器：`<rustup | go toolchain | nvm | uv | mise | ...>`

> 非交互 shell 通常不读 `.zshrc`/`.bashrc`；需要全局生效的 env 写入 Codex 实际读取的启动文件，或写进 `config.toml` 的受支持配置。

## 3. 工具链

| 工具 | 版本 | 路径 | 检测命令 |
|---|---|---|---|
| rustc / cargo | `<version>` | `<path>` | `rustc --version` |
| go | `<version>` | `<path>` | `go version` |
| java | `<version>` | `<JAVA_HOME>` | `java -version` |
| maven / mvnd | `<version>` | `<path>` | `mvn -v` |
| node / pnpm | `<version>` | `<path>` | `node --version` |
| python / uv | `<version>` | `<path>` | `python3 --version` |
| just | `<version>` | `<path>` | `just --version` |
| gitleaks / shellcheck | `<version>` | `<path>` | `gitleaks version` / `shellcheck --version` |

补充：

- Rust 附加组件：`<rustfmt, clippy, llvm-tools, ...>`
- Go 工具链策略：`<GOTOOLCHAIN=local | auto>`
- Python 包管理：`<uv | pip>`
- 交叉编译：见包内 `guides/cross-compile-windows-rust.md`（完整安装后 `$CODEX_HOME/guides/...`）

## 4. 网络与镜像

- 区域：`<中国大陆 | 其他>`
- 代理：`<http_proxy or none>`
- 镜像策略：

| 生态 | 镜像/源 | 配置文件 | 备注 |
|---|---|---|---|
| rustup | `<...>` | `<~/.zshenv>` | — |
| crates.io | `<...>` | `<~/.cargo/config.toml>` | — |
| Go | `<...>` | `<~/.config/go/env>` | — |
| npm | `<...>` | `<~/.npmrc>` | — |
| PyPI | `<...>` | `<~/.config/uv/uv.toml>` | — |
| Maven | `<...>` | `<~/.m2/settings.xml>` | — |
| apt | `<...>` | `<...>` | — |

- 镜像滞后时：版本判断用官方源，下载用镜像，并用官方 sha256 校验。
- 详见包内 `guides/network-mirrors-cn.md`（完整安装后 `$CODEX_HOME/guides/...`）。

## 5. 浏览器与字体

- `CHROME_PATH`：`<path-to-chromium-or-chrome>`
- headless 额外参数：`<--no-sandbox | none>`
- 浏览器版本：`<version>`
- 中文字体：`<font path or package>`；安装后执行 `fc-cache -f <font-dir>`
- 字体栈要求：CSS 显式写中文字族，并排在 `system-ui` 等通用别名之前。

## 6. Codex 安装与模型

- `CODEX_HOME`：`<~/.codex>`
- 安装方式：`<npm | brew | standalone>`
- CLI 版本：`<codex --version>`
- 模型 provider：`<provider id>`
- `wire_api`：`<responses | chat>`
- 当前模型：`<model slug>`
- 模型目录：`<~/.codex/models_catalog.json | none>`
- `base_instructions` 来源：`<model catalog | model_instructions_file | session history>`
- 技能使用说明：`include_skills_usage_instructions = <true | false>`（`true` 才会追加 `### How to use skills`）
- 已知模型限制：`<tool_mode, responses_lite, context window, truncation policy>`

## 7. Skills / MCP / Hooks / Plugins / Memories

### Skills

- 用户技能根：`<~/.agents/skills>`、`<~/.codex/skills>`
- 项目技能根：`<repo>/.agents/skills`（root→cwd）
- 技能源仓库：`<git clone path or URL>`；安装方式：`<symlink | copy>`；更新：`<git pull | ...>`
- 技能路由索引：`<~/.codex/skill-routing.md>`（机器本地；运行时 Skills 元数据为权威）

### MCP

| 名称 | transport | 地址/命令 | 认证方式 | 备注 |
|---|---|---|---|---|
| `<server>` | `<stdio/http>` | `<url or command>` | `<env var name; never the token>` | `<enabled/required>` |

- 配置位置：`$CODEX_HOME/config.toml` 的 `[mcp_servers.<id>]`；项目级 `.codex/config.toml` 需项目 trust。
- 凭据只放环境变量或 `0600` 文件，不写进仓库。

### Hooks

- Hook 配置：`$CODEX_HOME/hooks.json` 或 `$CODEX_HOME/config.toml` 的 `[hooks]`。
- 已启用事件：`<SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, Stop, ...>`
- 非托管 hook 需要审查/信任；项目级 hook 需项目 trust。

### Plugins

- 插件配置：`$CODEX_HOME/config.toml` 的 `[plugins."<id>@<marketplace>"]`。
- 已启用插件：`<list>`；插件可贡献 Skill、MCP、App、hooks。
- 插件来源与市场：`<marketplace>`；只启用审查过的插件。

### Memories

- `features.memories`：`<true|false>`（默认 false）。
- 记忆目录：`<~/.codex/memories>`；`memories.generate_memories` / `use_memories`：`<true|false>`。
- 记忆是生成状态，不手改；规则优先放 `AGENTS.md`。

## 8. 进程守护与运维

- 进程守护：`<warden | systemd --user | supervisor>`
- 端口分配：`<range>`；分配前用 `ss -ltn` 查重。
- 健康检查命令：`<command>`

## 9. 已知限制

- `<e.g. no passwordless sudo>`
- `<e.g. 2C/1.9G, avoid source builds>`
- `<e.g. shared KVM, don't saturate cores>`
- `<e.g. headless browser requires --no-sandbox>`

## 10. 最后核对记录

| 日期 | 核对人 | 变更 |
|---|---|---|
| `<YYYY-MM-DD>` | `<name>` | `<initial profile>` |
