---
kind: environment
abstract: 本机共享 KVM（16C/31GiB）：cargo build/test/clippy/install 一律 --jobs 6（OOM 降 4），已固化 ~/.cargo/config.toml；mvnd 不常驻（30s 空闲自杀，堆 512m）。
entities:
- cargo
- mvnd
- resources
tags:
- env
- machine
- rust
tier: semantic
type: Note
generated:
  by: process:ai-memory/3.4.2
  at: 2026-11-09T09:16:51Z
---
# 共享机编译资源纪律

> 由 ~/.zcode/AGENTS.md 迁入（2026-11-09）。本机 16C/31GiB 为多人共用 KVM，编译类命令前读本页。

- **所有 `cargo build/test/clippy/install` 必须加 `--jobs 6`**（或 `CARGO_BUILD_JOBS=6`），OOM 时降到 `--jobs 4`。已在 `~/.cargo/config.toml` 全局固化，`cargo install` 需显式传参。
- 原因：本机为 16 核 / 31 GiB KVM 虚拟机，多人共用、常驻高负载进程（ffmpeg/node/gnome 等），Rust 默认吃满 16 核会把整台机器拖垮。
- mvnd **不常驻**：调用时自动拉起 daemon、30s 空闲自杀（`~/.m2/mvnd.properties`，勿调长 idle；堆限 512m）——连续迭代用 mvnd（热 daemon ~0.3s/次 vs mvn 3.4s），单次/低频直接 mvn。
- 编译缓存纪律：debuginfo 用 `[profile.dev] debug = "line-tables-only"`（rs-iot/lux/simulator/tsink_fork 已配，单二进制约降 3.5×）；过期缓存清理用 cargo-sweep（`cargo sweep --time N` / `--maxsize`，装于 `~/.cargo/bin`）。