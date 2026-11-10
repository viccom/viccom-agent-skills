---
kind: environment
abstract: Rust stable 1.99.1（rustup）、Java Temurin 25+Maven 3.9.16+mvnd 1.0.6、Go 1.27.3（GOTOOLCHAIN=local）；路径/升级流程/交叉编译见正文与 env/cross-compile 页。
entities:
- rust
- java
- go
- toolchain
tags:
- env
- machine
- toolchain
tier: semantic
type: Note
generated:
  by: process:ai-memory/3.4.2
  at: 2026-11-09T09:16:51Z
---
# 本机工具链（Rust / Java / Go）

> 由 ~/.zcode/AGENTS.md 迁入（2026-11-09）。升级/安装前读本页；镜像配置见 `profile/env/network-mirrors.md`。

## Rust

- 默认 toolchain **stable = rustc 1.99.1**（2026-10-13），rustup 1.29.2；profile=minimal 但 stable 已装 rustfmt+clippy+rust-std；项目可用 `rust-toolchain.toml` 钉版本（如 ai-memory 钉 1.95.0，互不影响）。
- 升级走国内镜像（`rustup update stable`，镜像配置见 network-mirrors 页）。
- 附加工具：cargo-nextest 0.9.144（预编译装 `~/.local/bin`；`cargo install` 源码编译依赖 openssl-sys，libssl-dev 已装走 pkg-config 系统发现，无需任何 env）、cargo-flamegraph 0.6.14、cargo-insta 1.48.0（`~/.cargo/bin`）、cargo-sweep 0.8.0（`~/.cargo/bin`，2026-11-09）。
- perf 非特权采样已开（`kernel.perf_event_paranoid=1`，持久化 `/etc/sysctl.d/99-perf-dev.conf`；回滚删该文件并 `sysctl -w kernel.perf_event_paranoid=4`）。剖析约定：软件事件 `-e cpu-clock` 兜底可用；硬件 cycles 实测 record 可用但 `perf stat` 显示 not supported；内核帧 [unknown] 属正常（kptr_restrict 未放开，用户态剖析不需要）。
- **Windows 交叉编译**：本机可直接产出 .exe（2026-11-04 实测）。完整方案见 `profile/env/cross-compile-windows-rust.md`（ai-memory）与 `~/.jcode/env/cross-compile-windows-rust.md`（本机文档）。要点：`cargo install cargo-xwin --locked` + `rustup component add llvm-tools` +（Tauri 或有 C 依赖时）`apt-get download llvm-18 clang-18` 解包补 `llvm-rc`/`clang-cl` → `XWIN_ARCH=x86_64 cargo xwin build --release --target x86_64-pc-windows-msvc --jobs 6`。**易误判**：check 通过 ≠ 能产出 exe（check 不链接）；子命令是 `cargo xwin build`；`XWIN_ARCH=x86_64` 必加（默认下两套架构 SDK）。

## Java

- Temurin JDK 25.0.4.1 LTS（`~/.local/jdk-25.0.4.1`，`jdk-current` 软链）+ Maven 3.9.16（阿里云镜像）+ mvnd 1.0.6；新项目口径 **Java 25 + Spring Boot 4.x**。
- 环境经 `~/.zshenv` 全 shell 可见；守护/CI 场景 `source ~/.local/java-env.sh`。
- mvnd 不常驻（纪律见 `profile/env/build-resources.md`）。
- 卸载 = 删 `~/.local/{jdk-25.0.4.1,jdk-current,maven-3.9.16,mvnd-1.0.6,java-env.sh}` + `~/.m2` + `~/.zshenv` 相关行。

## Go

- 当前 `go1.27.3`（2026-10-19 发布），tarball 装在 `~/.local/go`，PATH 由 `~/.profile` 注入；`~/.config/go/env` 设 `GOTOOLCHAIN=local`（不自动拉取 toolchain），临时切版本用 `GOTOOLCHAIN=go1.25.10 go test ...`（已验证）。
- **硬规则：必须是官方最新稳定版**。升级流程：① 取 `https://go.dev/dl/?mode=json` 最新稳定版号与官方 sha256；② `curl -fsSLo /tmp/goX.Y.Z.linux-amd64.tar.gz https://mirrors.aliyun.com/golang/goX.Y.Z.linux-amd64.tar.gz`（国内镜像，dl.google.com 同源同大小）；③ `sha256sum` 逐字符比对；④ 解压替换 `~/.local/go`（旧版改名留作 `~/.local/go<旧版本号>-backup` 便于回滚）；⑤ `go version` 验证。体检脚本会比对官方最新版，落后判 ❌。
- **跨主版本升级（如 1.27→1.28）前先跑 Go 版本敏感的仓库测试**：Go 1.27 起 `compress/flate` 换新实现（提速），小载荷 gzip 退化为 stored block，明文会出现在压缩流里。