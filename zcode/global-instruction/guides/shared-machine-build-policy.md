# 共享机编译资源策略

> 适用于多人共用、常驻高负载进程的 Linux 机器；私有独享机器可以放宽。

## 先探测

```bash
nproc
free -h
uptime           # load average
ps -eo pcpu,pmem,comm --sort=-pcpu | head
```

## 并发默认值

从保守值起步：

```text
jobs = min(6, max(1, cores / 3))
```

- 共享 16C 机器：`min(6, 5) = 5`；实测稳定后可升到 6。
- 2C/2GiB 小机器：`max(1, 0) = 1`；优先用预编译二进制，避免源码编译。
- OOM 或 load 持续高于核数：减半。
- 机器空闲且任务可中断：可逐步加一，观察 load/内存。
- 链接/Java 编译的内存峰值高于编译本身；按 `free -h` 的可用内存估，不只看核数（每个 rustc/cargo 预留约 1–2GiB）。

Rust 项目可在 `~/.cargo/config.toml` 固定默认 jobs；`cargo install` 需显式 `--jobs`。Go/Java/Node 的构建也按同一原则限制并发。

## 内存与缓存

- Rust debuginfo 用 `[profile.dev] debug = "line-tables-only"`，可显著降二进制体积与链接内存。
- 过期构建缓存用 `cargo sweep --time N` / `--maxsize` 清理；不要手动删整个 `target/` 除非确认。
- Java：`mvnd` 不常驻；调用时拉起 daemon，30s 空闲退出，堆限 512m。连续迭代用 mvnd，单次/低频用 mvn。
- Node：避免多个 `pnpm install`/`vite build` 同时跑；CI 并发按内存配额设。

## 共享纪律

- 编译前看 `uptime`、`free -h` 和 `df -h .`；机器已经很忙或磁盘将满时先等、清理或降并发。
- 不要用 `-j$(nproc)` 默认吃满所有核。
- 大构建/测试不要与浏览器自动化、视频转码等内存大户并行。
- 后台长任务用 `nice -n 10 ionice -c3 <cmd>` 降低 CPU/IO 优先级；需要硬上限时用 `systemd-run --user --scope -p MemoryMax=...`。
- OOM 后先降并发、清缓存、拆分任务；不要反复重试同一命令。
- 长时间任务放后台/独立会话，避免阻塞交互。
