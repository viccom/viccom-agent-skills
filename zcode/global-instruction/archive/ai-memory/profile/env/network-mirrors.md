---
kind: environment
abstract: 本机在中国大陆：升级/安装一律走国内镜像（rustup TUNA、crates rsproxy、Go goproxy.cn、npm npmmirror、PyPI tuna、Maven 阿里云、apt cn.archive）；临时直连与官方校验见正文。
entities:
- mirrors
- network
- china
tags:
- env
- machine
- network
tier: semantic
type: Note
generated:
  by: process:ai-memory/3.4.2
  at: 2026-11-09T09:16:52Z
---
# 本机网络环境：中国大陆（国内镜像策略）

> 由 ~/.zcode/AGENTS.md 迁入（2026-11-09）。本机访问境外站点慢、常超时或被限流：凡升级/安装开发环境，一律优先走国内镜像或加速站，不要直连官方源把时间耗在超时上。

| 生态 | 镜像 | 配置位置 | 备注 |
|------|------|----------|------|
| rustup 发行版 | `mirrors.tuna.tsinghua.edu.cn/rustup` | `~/.zshenv` 的 `RUSTUP_DIST_SERVER` / `RUSTUP_UPDATE_ROOT` | 1.98.1→1.99.1 升级全程走镜像；TUNA 清单与官方逐字一致（实测） |
| crates.io 包 | `sparse+https://rsproxy.cn/index/`（源替换，checksum 不变） | `~/.cargo/config.toml` | `cargo fetch --locked` 显示 `registry rsproxy-sparse` |
| Go 模块 | `https://goproxy.cn,direct` | `~/.config/go/env` | 长期生效 |
| npm | `https://registry.npmmirror.com/` | `~/.npmrc` | `npm view lodash version` 0.37s |
| Python 包 | `https://pypi.tuna.tsinghua.edu.cn/simple` | `~/.config/uv/uv.toml`（本机**无 pip**，包管理走 uv 0.12.11） | uv 解析 URL 落在 tuna |
| Python 解释器 | `mirrors.tuna.../python-build-standalone` | 同上 `python-install-mirror` | — |
| Docker | `docker.1panel.live` 等 | `/etc/docker/daemon.json` | 已配 |
| Maven | `maven.aliyun.com/repository/public` | `~/.m2/settings.xml` | 已配 |
| apt | `cn.archive.ubuntu.com` | `/etc/apt/sources.list.d` | 已配 |

补充约定：

- GitHub release 资产：优先 `releases/latest/download/<asset>` 直链或 `gh`；api.github.com 匿名易限流，取列表改用 releases 页面解析；实在拉不动再用 `ghproxy` 类加速前缀。
- 临时直连官方：`UV_DEFAULT_INDEX=https://pypi.org/simple uv pip install ...`、`npm --registry=https://registry.npmjs.org/ ...`、删 `~/.zshenv` 里 `RUSTUP_DIST_SERVER` 两行、或 `cargo --config 'source.crates-io.replace-with="crates-io"'`。
- 镜像滞后时以官方为准：判断"最新版本"用官方源（`go.dev/dl`、Rust `channel-rust-stable.toml`），**下载**才用镜像——Go 用 `go.dev/dl/?mode=json` 公布的 sha256 校验镜像包。