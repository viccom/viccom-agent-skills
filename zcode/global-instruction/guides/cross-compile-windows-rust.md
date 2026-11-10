# Linux → Windows Rust 交叉编译

> 在 Linux（Ubuntu/Debian 系）上产出 Windows `.exe`/PE，不需要 Windows 机器，通常也不需要 sudo。
> 版本号（`llvm-18`、`clang-18`）是示例；按你的发行版调整。只验证过
> `x86_64-pc-windows-msvc`；`windows-gnu`、静态 CRT 未验证。

## 一句话方案

```bash
cargo install cargo-xwin --locked
rustup component add llvm-tools
# Tauri / 含 C 依赖时，补 llvm-rc + clang-cl（见下）
XWIN_ARCH=x86_64 cargo xwin build --release \
  --target x86_64-pc-windows-msvc --jobs <N>
```

产物：`target/x86_64-pc-windows-msvc/release/<bin>.exe`。

## 依赖

| 缺什么 | 何时需要 | 补法 |
|---|---|---|
| Windows SDK + MSVC CRT `.lib` | 必需 | cargo-xwin 自动下载（缓存 `~/.cache/cargo-xwin`） |
| `lld-link` | 必需 | rustup 自带 `rust-lld`；cargo-xwin 自动软链 |
| `llvm-rc` | Tauri（图标/清单/版本资源） | `apt-get download llvm-<ver>` + `dpkg -x` 取 `usr/lib/llvm-<ver>/bin/llvm-rc` |
| `clang-cl` | 依赖树含 `cc-rs` | `apt-get download clang-<ver> libclang-cpp<ver>` 解包，软链 `clang-<ver>` → `clang-cl` |

零 sudo 补包套路：

```bash
apt-get download <pkg>
dpkg -x <pkg>.deb /tmp/extract
install /tmp/extract/usr/bin/<tool> ~/.local/bin/
```

## 关键认知（最易误判）

- `cargo check --target x86_64-pc-windows-msvc` 通过 **不等于** 能产出 exe：check 不链接，不需要 Windows 库。
- 纯 Rust 项目不需要 clang；cargo-xwin 找不到会跳过。Tauri 的 `embed-resource` 需要 `clang-cl`。
- 子命令是 `cargo xwin build`，不是 `cargo xwinbuild`。
- `XWIN_ARCH=x86_64` 必加；默认会下 x86_64 + aarch64 两套 SDK。
- `llvm-rc` 在 `llvm-<ver>` 主包里，`llvm-<ver>-tools` 里没有。
- `cargo tree -i cc --target <target>` 查谁在目标侧编 C。
- 不需要 Windows 机器验证：`file out.exe`、`llvm-readobj --coff-resources out.exe`、`llvm-readobj --coff-imports out.exe`。
- `llvm-readobj` 可能不在 PATH；用 rustup 工具链下的完整路径：`$(rustc --print sysroot)/lib/rustlib/$(rustc -vV | sed -n 's/^host: //p')/bin/llvm-readobj`。
- `LNK4099 ... failed to load reference 'xxx.pdb'` 是微软 CRT 无调试符号；release 产物无影响。

## 常见报错

| 现象 | 处理 |
|---|---|
| `tauri-winres` panic `NotAttempted("llvm-rc")` | 装 `llvm-rc`；或在 `build.rs` 里按“跨编译且无 rc 工具”跳过 `tauri_build::build()` |
| `icons/icon.ico not found` | 即便 `bundle.active=false` 也要图标；ImageMagick 生成多尺寸 ico，PNG 用 `-depth 8` |
| `cc-rs: failed to find tool "clang-cl"` | 提供 `clang-cl` 软链（Tauri 的 `embed-resource` 常见） |
| 首次 `cargo xwin build` 很慢 | 下载 SDK；重跑可断点续用缓存 |
| Docker 镜像拉不动 | 本机 cargo-xwin 与镜像的 SDK 步骤一样，直接本机跑 |

## 分发

- 纯 Rust + 动态 UCRT 的 exe 只依赖 Win10+ 自带的 `api-ms-win-crt-*`，无需随包带运行库。
- WebView2 项目若用 `webview2-com-sys` 则静态链接，无需带 `WebView2Loader.dll`。

## 边界

- 只验证 `x86_64-pc-windows-msvc`；`windows-gnu` 未走（Tauri/wry 不支持、依赖 MinGW 运行库）。
- 静态 CRT 未验证。
- 版本号随发行版变化；先 `apt-cache policy` 确认包名。
