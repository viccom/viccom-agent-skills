---
kind: reference
abstract: 本机（Ubuntu 24.04）交叉编译 Rust→Windows 的完整方案：默认缺 Windows SDK/CRT 导入库、系统 lld-link、llvm-rc、clang-cl；用 cargo-xwin（rsproxy 装）+ rustup llvm-tools + apt download 解包补齐，XWIN_ARCH=x86_64 cargo xwin build --release --target x86_64-pc-windows-msvc --jobs 6，1-2 分钟出 exe。含真实报错根因与解法，长文 ~/.jcode/env/cross-compile-windows-rust.md
applies_to:
- rust
tags:
- rust
- cross-compile
- windows
- cargo-xwin
- toolchain
pinned: true
tier: semantic
type: Note
generated:
  by: process:ai-memory/3.2.5
  at: 2026-11-04T04:40:22Z
---
# 在本机交叉编译 Rust → Windows 二进制

**在本机（Ubuntu 24.04，yhpc-acloud）需要产出 Windows `.exe` 时，直接用本文方案；长文与完整报错清单在 `~/.jcode/env/cross-compile-windows-rust.md`。**

## 一句话方案

```bash
cargo install cargo-xwin --locked              # ① 交叉构建器（走 rsproxy 镜像）
rustup component add llvm-tools                # ② llvm-ar / llvm-dlltool
# ③ 零 sudo 补 llvm-rc + clang-cl（仅 Tauri / 有 C 依赖时需要，见下）
cd <项目> && XWIN_ARCH=x86_64 cargo xwin build --release --target x86_64-pc-windows-msvc --jobs 6
```

产物在 `target/x86_64-pc-windows-msvc/release/<bin>.exe`。SDK 缓存在 `~/.cache/cargo-xwin`（x86_64 约 817MB，只下一次）。

## 本机默认缺什么

| 缺 | 必需性 | 补法 |
|---|---|---|
| Windows SDK + MSVC CRT 的 `.lib`（kernel32.lib 等） | 必需 | cargo-xwin 自动从微软 CDN 下载（国内实测可用） |
| 系统 `lld-link` | 必需 | **rustup 自带 `rust-lld`**，cargo-xwin 自动软链成 `lld-link`（源码 `compiler/common.rs:100,116`） |
| `llvm-rc`（Windows 资源：图标/清单/版本） | Tauri 必需 | `apt-get download llvm-18` + `dpkg -x` 取 `usr/lib/llvm-18/bin/llvm-rc` → `~/.local/bin`（**注意：llvm-18-tools 包里没有 llvm-rc**） |
| `clang-cl`（cc-rs 探测 C 驱动） | 依赖树含 cc-rs 时 | `apt-get download clang-18 libclang-cpp18` 解包，`clang-18` 软链成 `clang-cl` |

零 sudo 补包套路：`apt-get download <pkg>`（只下载不安装）+ `dpkg -x pkg.deb /tmp/ext` + `install` 到 `~/.local/bin`。

## 关键认知（最易误判）

- **`cargo check --target x86_64-pc-windows-msvc` 通过 ≠ 能产出 exe**：check 不链接，不需要任何 Windows 库。
- **纯 Rust 项目不需要 clang**：cargo-xwin 找不到 clang 时静默跳过（源码 `compiler/clang_cl.rs:592`）。
- **子命令是 `cargo xwin build`**，不是 `cargo xwinbuild`。
- **`XWIN_ARCH=x86_64` 必加**：默认会下 x86_64 + aarch64 两套 SDK。
- `cargo tree -i cc --target <target>` 查谁在目标侧编 C。
- 产物自检（不必上 Windows）：`file out.exe`、`llvm-readobj --coff-resources out.exe`（看图标嵌没嵌）、
  `llvm-readobj --coff-imports out.exe`（看依赖 DLL 是否都是系统 DLL）。
- `LNK4099 ... failed to load reference 'xxx.pdb'` 是微软 CRT 无调试符号，release 产物无影响。

## 踩过的坑（现象 → 解法）

1. `tauri-winres` panic `NotAttempted("llvm-rc")` → 交叉 check 阶段在 `build.rs` 里按「跨编译且无 rc 工具」跳过 `tauri_build::build()`（只 emit `cfg(desktop)`）；有 rc 工具时走完整流程。
2. `icons/icon.ico not found` → 即便 `bundle.active=false` 也要图标；ImageMagick 生成多尺寸 ico，PNG 须 `-depth 8`（8 位）。
3. Docker 镜像 `messense/cargo-xwin` 拉不动且无用 → 它的价值是 wine 跑测试，SDK 那步两边一样；改走本机 cargo-xwin。
4. `cc-rs: failed to find tool "clang-cl"` → 提供 clang-cl 软链（多见于 Tauri 的 `embed-resource`）。
5. `cargo xwin build` 首次要下 SDK → 慢时重跑，缓存断点续用。

## 分发形态建议

纯 Rust + 动态 UCRT 的 exe 只依赖 Win10+ 自带的 `api-ms-win-crt-*`，无需随包带运行库；WebView2 项目若用 `webview2-com-sys` 则静态链接，无需带 `WebView2Loader.dll`。

## 边界

只验证过 x86_64-pc-windows-msvc；windows-gnu 路线未走（Tauri/wry 不支持、依赖 MinGW 运行库）；静态 CRT 未验证。
