# Machine Profile（示例模板）

> 复制为 `~/.zcode/machine-profile.md`（或与 `AGENTS.md` 同目录的 `machine-profile.md`），填入本机事实。
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
jobs = <n>            # 共享机建议 1/3 核数或 ≤6，取较小值
OOM 时降到 jobs = <n>
```

## 2. Shell 与 PATH

- 交互 shell：`<zsh | bash>`
- Agent 的 Bash 工具读取的启动文件：`<~/.zshenv | ~/.bashrc>`
- PATH 首位：`<~/.local/bin | ...>`
- 包管理器：`<apt | dnf | pacman | brew>`
- 版本管理器：`<rustup | go toolchain | nvm | uv | mise | ...>`

> 注意：非交互 shell 通常不读 `.zshrc`/`.bashrc`；需要全局生效的 env 写入 Agent 实际读取的启动文件。

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
- 交叉编译：见包内 `guides/cross-compile-windows-rust.md`（完整安装后 `~/.zcode/guides/...`）

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
- 详见包内 `guides/network-mirrors-cn.md`（完整安装后 `~/.zcode/guides/...`）。

## 5. 浏览器与字体

- `CHROME_PATH`：`<path-to-chromium-or-chrome>`
- headless 额外参数：`<--no-sandbox | none>`
- 浏览器版本：`<version>`
- 中文字体：`<font path or package>`；安装后执行 `fc-cache -f <font-dir>`
- 字体栈要求：CSS 显式写中文字族，并排在 `system-ui` 等通用别名之前。

## 6. 技能根与插件

- 用户技能根：`<~/.zcode/skills>`、`<~/.agents/skills>`
- 项目技能根：`<repo>/.zcode/skills`、`<repo>/.agents/skills`
- 技能源仓库：`<git clone path or URL>`
- 安装方式：`<symlink | copy>`；更新方式：`<git pull | ...>`
- 插件根/缓存：`<path>`；启用项：`<list>`

## 7. MCP 与 Hooks

- MCP servers：

| 名称 | transport | 地址/命令 | 认证方式 |
|---|---|---|---|
| `<server>` | `<http/stdio/sse>` | `<url or command>` | `<env var name; never the token>` |

- Hook 事件：`<SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, PostToolUseFailure, Stop>`
- Hook 捕获命令：`<command>`
- 配置文件权限：`0600`；token 不进入仓库。

## 8. 进程守护与运维

- 进程守护：`<warden | systemd --user | supervisor>`
- 端口分配：`<range>`；分配前用 `ss -ltn` 查重。
- 每个工作路径独立实例/独立 token（如适用）。
- 面板/证书：`<1Panel endpoint, certificate method>`；凭据放独立文件，权限 `0600`。
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
