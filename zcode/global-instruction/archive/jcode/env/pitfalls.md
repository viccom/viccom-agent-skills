# 机器级填坑录 —— 跨项目工具链坑与解法
# 规则: 个案记一次; 第二次出现必须升级为模板/门禁/体检。升级去向见 linux-ai-agent-environment.md §3.3

## 2026-08-25 本机盘点(首次审计录入)

### 工具与环境
- **crates.io 主页 HTTP 403 属正常**: 裸 GET 根路径返回 403, 不代表不可达; cargo 用 API 端点判断
- **go 版本检测**: `go version` 而非 `go --version`(flag 报错)
- **fd 命令名**: Ubuntu 的 fd 包叫 `fd-find`, 二进制是 `fdfind`, 需 `ln -s` 或 shell alias

### 老 Claude Code 环境(~/.claude)
- 20 个启用插件中, **gopls/pyright/typescript LSP 三个插件引用缺失二进制**(静默失败病灶)——装对应 LSP 或禁用插件, 二选一; 已按 2026-08-25 改造禁用了三个 LSP 插件(settings.json 有 .pre-jcode-transform 备份可回滚)
- 全局 CLAUDE.md 缺失: 老环境只有 settings.json 与插件, 无行为约束文件

### 密钥与仓库
- **AI-Agent-Reasearch 历史含 DeepSeek 旧 key**(Codex/config.toml): 当前工作区已换 `${DEEPSEEK_API_KEY}` 占位符(commit 4e8d330), 历史旧值不可回捞——绝不 reintroduce
- gitleaks 对教学示例(sk_live_12345 等)会误报: fingerprint 进 .gitleaksignore 而非改门禁

### jcode 特性(本机安装)
- jcode 全局指令在 **`~/AGENTS.md`**(不是 ~/.jcode/CLAUDE.md); 项目级在 `./AGENTS.md`; 覆盖层在 `~/.jcode/prompt-overlay.md`
- 改 AGENTS.md 只对新会话生效, 运行中的会话保留启动时的提示词
- jcode 服务由 pid 1258111(`serve`)承载, 用 `jcode server status` 查; 内存语义记忆在 `~/.jcode/logs/memory-*.jsonl`
- 本机 2C/1.9G 内存: go install 编译慢, 优先 GitHub release 二进制; 全套 LSP 按需装

### 网络
- 直连 GitHub/npm/pypi/goproxy 均通; 大文件下载统一 `--retry 3`, 失败通道告警可重跑续传

## 阅后即焚原则
本文件是活文档。新坑记入后, 如果第二次出现, 立即升级: 工作流模板 / quality.just / env-check.sh / AGENTS.md 四选一。

## 2026-10-27 OpenSSL/Rust 构建环境(yhpc-acloud 机器, zcode 环境)

### 现象
warden 等依赖 reqwest(默认 native-tls)的 Rust 项目 `cargo build/test/clippy` 报
openssl-sys: "Could not find directory of OpenSSL installation"; 已在 warden(≥3 次, 跨会话)与
cargo install 源码编译(cargo-nextest 等)反复出现。每次新 Agent 会话都重新踩坑。

### 根因(三层叠加)
- 本机**从未安装 libssl-dev**(dpkg 历史可证), 且 sudo 需密码 → pkg-config 找不到 openssl;
- 唯一的 OpenSSL 头文件在**用户级 GCC-14 工具链解包根** `~/.local/toolchain-root/`
  (2026-08-18 为 argus 项目/旧名 vision-ext 解包, 内含 libssl-dev 的 include+lib;
  注意其 `.so` 是悬空链接, 链接期实际落 `libssl.a` 静态库);
- 指向它的 `OPENSSL_DIR/OPENSSL_LIB_DIR/OPENSSL_INCLUDE_DIR` **只存在于
  `~/dongit/argus/.env.build`**, 从未进入任何 shell 初始化文件; zcode 全局 AGENTS.md
  引用的还是改名前的旧路径 `vision-ext/.env.build`(已失效)。
- 关键机制: **Agent 的 Bash 工具是非交互 zsh, 只读 `~/.zshenv`**(不读 .zshrc/.profile),
  所以没写进 .zshenv 的 env 对 Agent 永远不可见——除非会话内手动 export(不可持续)。

### 修复(2026-10-27, 按本文件升级规则: 多次出现 → 升级为体检 + 全局固化)
- `~/.zshenv` + `~/.profile` 双写三个 OPENSSL_* 变量(机器惯例: 重要 env 双写, 参照 node PATH);
- `env-check.sh` 新增 openssl-sys 构建可发现性检查(❌ 时附修复指引);
- ai-memory profile 页 `env-openssl-rust`(跨项目注入) + zcode 全局 AGENTS.md 修正失效引用。

### 排查技巧
- openssl-sys 实际用的发现路径看 `target/<profile>/build/openssl-sys-*/output`(grep OPENSSL_LIB_DIR);
- 重建验证: `cargo clean -p openssl-sys && cargo check`(不开手动 env, 冷启动复现)。

### 收尾（同日 2026-10-27，用户手动 `sudo apt install libssl-dev`）
- **根治落地**：libssl-dev 3.0.13-0ubuntu3.16 装好，pkg-config 可发现；已验证无 env 下
  openssl-sys 走系统发现、warden `cargo check` 冷启动通过。
- 按本条目既定约定**移除** `~/.zshenv` 与 `~/.profile` 的 OPENSSL_* 注入段——env 会遮蔽
  系统发现，且 toolchain-root 的头文件不随 apt 升级；env-check.sh 检查项同步改为
  "系统包优先 + 检测 env 残留遮蔽（warn）"。
- `~/.local/toolchain-root` **保留**（argus 的 GCC 工具链仍依赖它，见其 `.env.build` 的
  PATH/LD_LIBRARY_PATH）；日后删它只影响 argus，不再影响 openssl-sys。
- 原"头文件漂移"风险随注入移除消失——头文件与库现同源于系统包，随 apt 升级。


## 2026-08-26 ai-memory 接入(nodeApp 机器, jcode 环境)

### 工具与环境
- **Go 1.26 `go install` 需要 `@version`**: 旧 install-extra.sh 写 `go install github.com/foo/bar` 在 Go 1.26 上必败, 必须 `go install github.com/foo/bar@latest`。修复后的正确包路径: gitleaks=`github.com/zricethezav/gitleaks/v8`, just=`github.com/casey/just`(无 cmd 子包, 但需要手动从 release tarball 装), sd=`github.com/chmln/sd`@latest(不是 v2)
- **tokei v14.0.0 release 无 binary**: assets 数组空, 用 v13.0.0-alpha.0 或 v12.1.2 的 `tokei-x86_64-unknown-linux-gnu.tar.gz` 才能装
- **fd-find 包名**: Ubuntu 22.04 的 apt 包叫 `fd-find`, 二进制是 `/usr/bin/fd`(不是 `fdfind`); 但 env-check.sh 仍检 `fdfind`, 可能要 symlink 或修改体检脚本

### ai-memory(jcode 适配)
- **jcode 不在 ai-memory 官方 agent 列表**: 支持 claude-code / codex / cursor / gemini-cli / open-code / pi / omp / openclaw / grok / zero / devin / kimi / kiro 等, **无 jcode**
- **jcode hooks ≠ Claude Code hooks**: jcode 的 `turn_end` / `session_start` 都是 **observer-only**(fire-and-forget, 不能返回 context 给模型), 仅 `pre_tool` 可门控。Claude Code 的 Stop + `additionalContext` 注入路径在 jcode 上**不存在**——这是模板 2 必须重写的根本原因
- **jcode 适配后的模板 2**: turn_end 钩子启发式检测"solved + tried"信号, 命中后 append JSONL 到 `~/.jcode/state/gotcha-pending.jsonl`, 让下轮 session_start 或主动 `memory_query "pending gotcha reminder"` 拾起(漏报率约 10%, 接近 Claude Code Stop + 软提示的水平)
- **MCP stdio transport**: jcode mcp.json 只支持 stdio(command-based); ai-memory 默认 stdio, 直接用。HTTP 入口被 jcode 识别但跳过(README 注明)
- **LLM provider 配置**: ai-memory 用 `LLM_BASE_URL` + `LLM_API_KEY` 环境变量(openai-compat 模式); Anthropic 模式需 `ANTHROPIC_API_KEY`。本机用 minimaxi OpenAI 端点 → `LLM_BASE_URL=https://api.minimaxi.com/v1` + `LLM_API_KEY=$MINIMAX_API_KEY`
- **密钥集中管理**: 用 `ai-memory-stdio.sh` wrapper source `ai-memory.env`, mcp.json 的 env 段只放路径(API key 不入 json); 占位符 `__PLACEHOLDER__` 哨兵防止未替换的 env 被泄露
- **ai-memory 写盘带 git 自动**: `~/.local/share/ai-memory/wiki/.git` 每次 write_page 提交一次, 配合 `ai-memory checkpoints` / `restore-page` 可回滚单页
- **jcode 自身 memory vs ai-memory 边界**: jcode memory 是会话级语义记忆(向量), ai-memory 是跨会话工程经验沉淀(git-versioned markdown + FTS5), 两者并存不重复
- **grep -cE 是行计数不是命中数**: 写启发式信号检测时 `grep -ciE pattern | wc` 给的是**匹配行数**(单行文本永远是 0 或 1), 不是模式命中次数。要数多次出现必须 `grep -oiE pattern | wc -l`。本钩子的 solved/tried 双信号阈值用此写法
- **ai-memory HTTP server 415 if 缺 Content-Type**: curl 探活或 Python urllib 必须显式 `Content-Type: application/json`, 否则服务器报 415; MCP 协议虽然希望 Accept 含 `text/event-stream`, 但 Content-Type 才是 POST 必需
- **ai-memory HTTP MCP 不需要 session-id 跟踪**: 本机 `ai-memory serve --transport http` 响应头**无** `mcp-session-id`, initialize + tools/call 可以独立 POST(无需 session_id 字段)。`memory_consolidate` 仍要求 `session_id`, 但 `memory_write_page` 不需要——这正是 L3 fire-and-forget 的可行性前提
- **dedup 文件用 TSV 而非 JSONL**: 1h 内同 signature 去重, 用 `ts<TAB>sha256` 一行一条, 比 JSONL 省一个解析器开销, 配合 `cutoff` 阈值方便就地清理过期项

### 上游仓库策略
- **故意不 git push 到 viccom 的 origin**: 仓库 `origin` = `git.metme.top/viccom/AI-Agent-Reasearch.git`,本机 agent 改造后的 3 个 commit(92ca198 / 5d34f3d / cc8eda2)的 author 是 `jcode-bootstrap <jcode@local>`,`git push` 需要:
  1. 用户凭据(我们没)
  2. 推送身份是 jcode-bootstrap 而非 viccom <3520845@qq.com>(就算有凭据也不能冒充原作者)
  3. 推送策略选择(直推 master vs PR vs fork)只能由人决定
  **结论**: agent 在 source of truth 是**本机 local master** 而非 origin;他机部署先 bootstrap.sh 拉到本机 master 后再考虑推送
- **`git push --dry-run` 不暴露凭据**: 是验证"会推什么"的快速手段,失败信息("branch has no upstream")也足以判断当前是否需要 set-upstream
## 2026-11-04 Rust 交叉编译 Windows 二进制(yhpc-acloud 机器, zcode 环境)

### 结论(先看这个)
本机可直接产出 Windows `.exe`/PE,无需 Windows 机器、无需 sudo:
`cargo install cargo-xwin --locked` + `rustup component add llvm-tools`
+ (Tauri/有 C 依赖时)`apt-get download llvm-18 clang-18` 解包补 `llvm-rc`/`clang-cl`
→ `XWIN_ARCH=x86_64 cargo xwin build --release --target x86_64-pc-windows-msvc --jobs 6`。
**完整方案、长文与全部报错清单: `~/.jcode/env/cross-compile-windows-rust.md`**
**全局记忆索引: ai-memory `_global` scope 页 `env/cross-compile-windows-rust.md`(每个项目默认检索都会命中)。**

### 关键误区
- `cargo check --target x86_64-pc-windows-msvc` 通过 **不等于** 能产出 exe(check 不链接、不需要 Windows 库)。
- 链接器不用装: rustup 自带 `rust-lld`,cargo-xwin 自动软链成 `lld-link`。
- 纯 Rust 项目不需要 clang(cargo-xwin 找不到就跳过);Tauri 的 `embed-resource` 需要 `clang-cl`。
- `llvm-rc` 在 `llvm-18` 主包里,`llvm-18-tools` 包里没有(只含 FileCheck/lit)。
- 子命令是 `cargo xwin build`;`XWIN_ARCH=x86_64` 必加(默认会下 x86_64+aarch64 两套 SDK)。
- Docker 镜像 `messense/cargo-xwin` 只为 wine 跑测试,SDK 那步两边一样,且本机实测拉不动。

### 零 sudo 补包套路
`apt-get download <pkg>`(只下载不安装) + `dpkg -x <pkg>.deb /tmp/x` + `install` 到 `~/.local/bin`。

### 升级去向
本条目已升级为「全局记忆索引 + 机器资产长文」;若后续再出现第二次(其他项目交叉编译失败),
应把 `llvm-rc`/`clang-cl`/`cargo-xwin` 的存在性检查加进 `env-check.sh` 体检项。

## 2026-11-04 ai-memory 跨项目 profile 正式启用(yhpc-acloud 机器)

- **状态**: `ai-memory profile status` → `Profile: on (global; multi-user server)`;
  配置在 `~/.local/share/ai-memory/config.toml` 的 `[profile]` 段(`enabled = true` + `share = "global"`),
  改动前备份 `config.toml.bak-20261104-124006-before-profile-enable`。
- **为何是 share="global"**: 本机 server 是多用户(ncpe=user, viccom=root), 而 ZCode 的 MCP 客户端
  用的是 **root token**(`~/.local/share/ai-memory/auth-token`, 与 `~/.zcode/cli/config.json` 的
  Authorization 一致)。按上游语义 root 请求**没有私有 profile**, 故 `share` 必须为
  `global`(团队 profile, 位于 `default/_global/profile/`), 否则 `scope: "profile"` 写入被拒。
- **重启方式**: `systemctl --user restart ai-memory.service`(unit 由 `ai-memory setup` 生成,
  不要手改 unit 文件); 重启后 MCP 连接短暂断开,客户端会自动重连。
- **写入权限**: `scope: "profile"` 的条目需 root 或该 scope 的 write 授权; 本机为 root,直写即可。
- **副作用**: profile 是**团队级**——同机其他使用者(viccom)的会话启动也会收到这份 digest。
  若要改为仅本人可见,需 `share = "user"` 并把 MCP 客户端换成 ncpe 用户的 API key(root 令牌无私有 profile)。
- **profile 条目**: `profile/env/cross-compile-windows-rust.md`(本机交叉编译 Windows 的完整方案,
  `applies_to = ["rust"]`); `_global` 域保留同名指针页便于 global 检索。
