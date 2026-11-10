# 在本机（Linux）交叉编译 Rust → Windows 二进制

> 机器级资产：yhpc-acloud（Ubuntu 24.04 LTS，x86_64，16 核 / 31 GiB，共享机）。
> 适用：任何需要在**这台开发机**上产出 `.exe` / Windows PE 的 Rust 项目
> （Tauri 桌面应用、Rust CLI 的 Windows 版、含 C 依赖的 crate 等）。
> 首次验证：2026-11-04，oc-sync-app（Tauri 2.12.5）交叉编译出 12.6 MB 的 PE32+ GUI 可执行文件。
> 索引：ai-memory profile 页 `env/cross-compile-windows-rust`（每个项目会话启动即注入）。

---

## 0. 一句话结论

**本机默认缺 3 样东西，但都能零 sudo 补齐；用 `cargo-xwin` 路线，1–2 分钟出包。**

```
cargo install cargo-xwin --locked     # 装交叉构建器（走 rsproxy 镜像，秒级）
rustup component add llvm-tools       # 补 llvm-ar / llvm-dlltool
# 零 sudo 补 llvm-rc + clang-cl（只有需要 Windows 资源/图标或 C 依赖时才要）
XWIN_ARCH=x86_64 cargo xwin build --release --target x86_64-pc-windows-msvc --jobs 6
```

---

## 1. 本机默认有什么、缺什么

### 1.1 已有（无需处理）

| 项 | 状态 | 证据 |
|---|---|---|
| Rust 工具链 | stable = rustc 1.99.1 / cargo 1.99.1 | `rustc -V` |
| Windows 标准库 | `x86_64-pc-windows-msvc` target 已装 | `rustup target list --installed` |
| **链接器 `lld-link`** | rustup 自带 `rust-lld`（在 `~/.rustup/toolchains/stable-*/lib/rustlib/x86_64-unknown-linux-gnu/bin/`） | `ls .../rustlib/x86_64-unknown-linux-gnu/bin/` → `rust-lld` |
| 静态库工具 | `llvm-ar`（llvm-tools 组件）、`llvm-dlltool` | 同上目录 |
| crates.io 源 | rsproxy 稀疏镜像（国内） | `~/.cargo/config.toml` |
| 磁盘 | 根分区剩余 295 GB | `df -h ~` |

### 1.2 默认缺（Linux 侧）

| 缺什么 | 后果 | 是否必需 |
|---|---|---|
| **Windows SDK + MSVC CRT 的 `.lib`**（kernel32.lib / user32.lib / advapi32.lib / libcmt.lib / vcruntime.lib …） | 链接期报 `cannot find kernel32.lib` 之类 | **必需**（cargo-xwin 会自动下载） |
| **系统 `lld-link`** | rustc 的 msvc target 默认找 `link.exe`（MSVC 自带），Linux 上没有 | **必需**，但 cargo-xwin 会把 `rust-lld` 软链成 `lld-link` |
| **`llvm-rc` / `windres`** | 编译 `.rc` 资源（Windows 图标、应用清单、版本信息） | **仅当项目要嵌资源**（Tauri 几乎必需） |
| **`clang-cl`** | `cc-rs` 探测 C 编译器驱动（目标侧有 C/C++ 代码时必需） | **仅当依赖树里有 cc-rs**（Tauri 的 `embed-resource` 走这条） |
| Windows SDK 头文件 | 目标侧要编 C/C++ 时需要 | 同上 |

> `cargo check --target x86_64-pc-windows-msvc` **不需要上面任何一项**——它只做类型检查，不链接、不找库。
> 所以「交叉 check 通过」≠「能产出 exe」，这是本主题最常见的误判。

---

## 2. 最终正确方案（照做即可）

### 2.1 一次性环境（全部零 sudo）

```bash
# ① 交叉构建器：自动下载 MS SDK/CRT、装配 lld-link、设置 CARGO_TARGET_*_LINKER
cargo install cargo-xwin --locked          # 走 rsproxy，实测几分钟内完成

# ② 静态库工具（rustup 自带 rust-lld 的配套）
rustup component add llvm-tools            # 提供 llvm-ar / llvm-dlltool

# ③ 零 sudo 补 Windows 资源编译器与 C 编译器驱动（仅 Tauri / 有 C 依赖时需要）
#    技巧：apt-get download 只下载不安装，dpkg -x 解包到用户目录
mkdir -p ~/.local/bin && cd /tmp
apt-get download llvm-18                   # 含 llvm-rc、llvm-dlltool（注意：llvm-18-tools 包里没有 llvm-rc）
dpkg -x llvm-18_*.deb /tmp/llvm-ext
install -m0755 /tmp/llvm-ext/usr/lib/llvm-18/bin/llvm-rc       ~/.local/bin/
install -m0755 /tmp/llvm-ext/usr/lib/llvm-18/bin/llvm-dlltool  ~/.local/bin/

apt-get download clang-18                  # 提供 clang 驱动（cc-rs 探测用）
apt-get download libclang-cpp18            # clang 的运行时依赖，一并解包到同一目录
dpkg -x clang-18_*.deb /tmp/clang-ext && dpkg -x libclang-cpp18_*.deb /tmp/clang-ext
install -m0755 /tmp/clang-ext/usr/lib/llvm-18/bin/clang-18 ~/.local/bin/clang-18
ln -sf ~/.local/bin/clang-18 ~/.local/bin/clang-cl            # clang 以 cl 模式运行
ln -sf ~/.local/bin/clang-cl ~/.local/bin/clang
```

要点：
- **`llvm-rc` 在 `llvm-18` 主包里**，不在 `llvm-18-tools`（后者只有 FileCheck/lit 等测试工具）。踩过这个坑。
- 解包出来的 `llvm-rc` 直接可用：本机已有系统 `libLLVM.so.18.1`，`ldd` 无缺失项。
- `clang-cl` 只是 `clang` 的 cl 模式前端，**软链即可**，不必找真 `clang-cl` 二进制。

### 2.2 构建

```bash
cd <项目>            # 若项目在子目录，cd 进去再跑
XWIN_ARCH=x86_64 cargo xwin build --release --target x86_64-pc-windows-msvc --jobs 6
# 产物：target/x86_64-pc-windows-msvc/release/<bin>.exe
```

- `XWIN_ARCH=x86_64` **必加**：cargo-xwin 默认下 `x86_64 + aarch64` 两套 SDK，只做 x86_64 时省一半下载量。
- `--jobs 6`：本机共享，Rust 构建一律限并发（见全局 AGENTS.md「资源占用」）。
- 子命令是 **`cargo xwin build`**；`cargo xwinbuild` 不存在（会报 `no such command`）。
- SDK 缓存目录 `~/.cache/cargo-xwin`（x86_64 单架构约 817 MB），**只下一次**，后续构建复用。

### 2.3 产物自检（不必上 Windows 就能查）

```bash
B=~/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/lib/rustlib/x86_64-unknown-linux-gnu/bin
file out.exe                                   # PE32+ executable (GUI) x86-64, for MS Windows
$B/llvm-readobj --coff-resources out.exe       # ICON / GROUP_ICON / VERSIONINFO（资源是否嵌进去）
$B/llvm-readobj --coff-imports  out.exe        # 依赖的 DLL：应全是系统 DLL
```

判读：
- 出现 `WebView2Loader.dll` → 该项目用了 WebView2 动态加载，需要随包分发该 DLL；
  用 `webview2-com-sys` 时它自带 `WebView2LoaderStatic.lib`（静态），一般不会出现。
- 出现 `msvcp140.dll` / `vcruntime140.dll` → 需要 VC++ 运行库（纯 Rust 项目通常只有
  `api-ms-win-crt-*`，那是 Win10+ 自带的 UCRT，无需额外安装）。
- `LNK4099 ... failed to load reference 'xxx.pdb'` 警告：微软 CRT 没带调试符号，**release 产物无影响**。

---

## 3. 过程中实际遇到的问题（现象 → 根因 → 解法）

| # | 现象（真实报错） | 根因 | 解法 |
|---|---|---|---|
| 1 | `cargo check --target x86_64-pc-windows-msvc` 成功，但 `cargo build` 链接失败找不到 `kernel32.lib` 之类 | check 不链接；msvc target 只带 Rust 标准库，不带 Windows SDK 的导入库 | 用 cargo-xwin 拉 SDK（见 §2.1①） |
| 2 | `thread 'main' panicked at tauri-winres-0.3.7/src/lib.rs:543: called Result::unwrap() on an Err value: NotAttempted("llvm-rc")` | Tauri 的 `tauri-build` 在 windows target 上要编 `.rc` 资源，Linux 上没有 rc 工具 | 交叉 check 阶段在 `build.rs` 里按「是否跨编译且无 rc 工具」跳过 `tauri_build::build()`；有 rc 工具时走完整流程 |
| 3 | `` `/…/src-tauri/icons/icon.ico` not found; required for generating a Windows Resource file `` | 即便 `bundle.active=false`，tauri-build 仍要图标编资源 | 生成 `icons/icon.ico`（ImageMagick：`magick icon.png -define icon:auto-resize=256,128,64,48,32,16 icon.ico`）；PNG 必须 8 位（`-depth 8`，否则 tauri 的 PNG 解码报错） |
| 4 | Docker 镜像 `messense/cargo-xwin` 拉了 25 分钟无进展（1panel 镜像加速也慢） | 该镜像的价值是内含 wine（跑 Windows 测试），**不解决 SDK 下载**——SDK 仍走微软 CDN | 放弃镜像，改本机 `cargo install cargo-xwin`（rsproxy 镜像，分钟级） |
| 5 | `error: no such command: xwinbuild` | cargo-xwin 的子命令是 `cargo xwin build` | 用 `cargo xwin build` |
| 6 | `error occurred in cc-rs: failed to find tool "clang-cl"` | 依赖树里 `embed-resource`（tauri-winres 的资源编译器）用 `cc-rs` 探测 C 驱动 | 提供 `clang-cl`（软链 clang-18）；查谁要 C 编译器：`cargo tree -i cc --target x86_64-pc-windows-msvc` |
| 7 | 第一次 `apt-get download llvm-18-tools` 里找不到 `llvm-rc` | `llvm-18-tools` 只含 FileCheck/lit 等测试工具 | 改下 `llvm-18` 主包（`llvm-rc`、`llvm-dlltool` 都在里面） |
| 8 | `cargo xwin build` 首次运行时 SDK 下载慢/中断 | 微软 CDN 无国内镜像 | 实测直连可用（缓存 817MB，分钟级）；失败可重跑（缓存断点续用），或换 `XWIN_CACHE_DIR` 指向大盘 |
| 9 | `cargo clippy`/门禁脚本因新增 `~/.local/bin` 工具而行为变化 | 本机 PATH 里多了 `llvm-rc`/`clang-cl` → Tauri 的 build.rs 门控判定变了 | 门控改成「PATH 有 rc 工具就走完整流程」，两条路径都正确；验证过两条路径都通过 |

### 3.1 为什么最后选 cargo-xwin 而不是 Docker 镜像

读 `cargo-xwin 0.23.1` 源码确认（`~/.cargo/registry/src/*/cargo-xwin-0.23.1/`）：

- `src/compiler/common.rs:100` `setup_llvm_tools()`：把 rustup 的 **`rust-lld` 软链成 `lld-link`**、
  `llvm-ar` 软链成 `llvm-lib` / `llvm-dlltool` → **不需要额外装 lld**；
- `src/compiler/common.rs:116` `setup_target_compiler_and_linker_env()`：设
  `CARGO_TARGET_X86_64_PC_WINDOWS_MSVC_LINKER=lld-link` → **不需要 MSVC 的 link.exe**；
- `src/compiler/clang_cl.rs:592` `setup_clang_cl_symlink()`：找不到 clang 时**静默跳过**（`return Ok(())`）
  → 纯 Rust 项目（目标侧无 C 代码）**连 clang 都不需要**；
- `src/options.rs:25`：`XWIN_ARCH` 默认 `x86_64,aarch64` → 单架构要显式指定以省下载量。

Docker 镜像提供的是 wine（用于在 Linux 上**运行** Windows 二进制做测试），与「产出二进制」无关，
而 SDK 那一步两边完全一样 → 走本机路线。

---

## 4. 面向 Tauri 2.x 项目的额外要点

| 项 | 要求 |
|---|---|
| `tauri.conf.json` | `bundle.active = false` 可跳过打包器；**但图标仍必需**（资源编译独立于 bundler） |
| `build.rs` | 交叉构建要有 `llvm-rc`/`windres`；纯 `cargo check` 可在无 rc 工具时跳过 `tauri_build::build()`（只 emit `cfg(desktop)` 等关键输出） |
| WebView2 | `webview2-com-sys` 自带 `WebView2LoaderStatic.lib`（静态链接），无需分发 DLL；运行时依赖系统 WebView2 Runtime（Win11 自带） |
| 目标侧 C 依赖 | `cargo tree -i cc --target <target>` 查谁在编 C；`cc-rs` 需要 `clang-cl` 或 `clang` + `CL_FLAGS` |
| 交叉 check 门禁 | `cargo check --target x86_64-pc-windows-msvc` 只做类型检查，**不能证明能链接**；真正的门禁是 `cargo xwin build` |

---

## 5. 机器上已经落地的可复用脚本

`oc-sync-app/scripts/build-windows-portable.sh`（该项目仓库内，可照抄模式）：
自动补 llvm-rc/clang-cl → 构建前端 → `cargo xwin build --release` → 下载引擎资产 →
组装便携目录 + zip。零 sudo、可重复执行。

---

## 6. 检查清单（下次直接照抄）

```bash
# 环境自检
command -v cargo-xwin            # ① 交叉构建器
rustup component list --installed | grep llvm-tools   # ② llvm-ar
command -v llvm-rc               # ③ 资源编译器（Tauri 必需）
command -v clang-cl              # ④ C 驱动（有 C 依赖时必需）

# 构建
XWIN_ARCH=x86_64 cargo xwin build --release --target x86_64-pc-windows-msvc --jobs 6

# 产物自检
file target/x86_64-pc-windows-msvc/release/*.exe
```

---

## 7. 边界与已知风险

- **只验证过 x86_64-pc-windows-msvc**；aarch64 Windows（ARM 设备）未验证（`XWIN_ARCH=aarch64`）。
- **windows-gnu 路线未走**：Rust 的 windows-gnu target 自带 MinGW 导入库，看似省事，但
  Tauri/wry 官方不支持该组合，且产物依赖 MinGW 运行库，不适合「单 exe 便携分发」。
- **未在 Windows 真机运行过**该产物（当时的验证方式是「用户真机验收」）；
  本次由用户在 Windows 上解压测试通过（功能正常）。
- 静态 CRT（`+crt-static`）可进一步去掉 UCRT 依赖，未在本机验证。
- xwin 下载的 SDK 受微软许可约束（Windows SDK EULA），**只用于构建，不随产物分发**。
