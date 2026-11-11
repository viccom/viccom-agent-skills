# 中国大陆网络镜像策略

> 适用于中国大陆网络环境；其他地区可忽略，或按同样结构换成当地镜像。
> 镜像不是权威源：**版本判断用官方源，下载用镜像，校验用官方 sha256/checksum。**

## 常用镜像

| 生态 | 镜像 | 典型配置位置 | 备注 |
|---|---|---|---|
| rustup | `https://mirrors.tuna.tsinghua.edu.cn/rustup` | `~/.zshenv` 的 `RUSTUP_DIST_SERVER` / `RUSTUP_UPDATE_ROOT` | 清单与官方一致 |
| crates.io | `sparse+https://rsproxy.cn/index/` | `~/.cargo/config.toml` | 源替换，checksum 不变 |
| Go 模块 | `https://goproxy.cn,direct` | `~/.config/go/env` | `GOPROXY` |
| npm | `https://registry.npmmirror.com/` | `~/.npmrc` | — |
| PyPI | `https://pypi.tuna.tsinghua.edu.cn/simple` | `~/.config/uv/uv.toml` 或 pip 配置 | 用 uv 时配 `default-index` |
| Python 解释器 | `python-build-standalone` 镜像 | `uv.toml` | — |
| Maven | `https://maven.aliyun.com/repository/public` | `~/.m2/settings.xml` | — |
| apt | 就近的 `cn.archive.ubuntu.com` 等 | `/etc/apt/sources.list.d` | — |
| Docker | 可用的 registry mirror | `/etc/docker/daemon.json` | 以实际可用为准 |

## 临时直连官方

需要判断“最新版本”或镜像滞后时：

```bash
UV_DEFAULT_INDEX=https://pypi.org/simple uv pip install ...
npm --registry=https://registry.npmjs.org/ ...
# 删掉/注释 RUSTUP_DIST_SERVER、RUSTUP_UPDATE_ROOT
# 把 replace-with 指回 crates-io，等价于临时关闭源替换；离线时会报无法更新 registry，属预期
cargo --config 'source.crates-io.replace-with="crates-io"' ...
```

## GitHub release

- 优先 `releases/latest/download/<asset>` 直链或 `gh`。
- `api.github.com` 匿名易限流；取列表可解析 releases 页面。
- 大文件下载加 `--retry 3`；失败可重跑续传。
- 实在拉不动再用加速前缀；加速站不可作为校验源。

## 校验

- Go：用 `https://go.dev/dl/?mode=json` 公布的 sha256 校验镜像包。
- Rust：镜像清单与官方 `channel-rust-stable.toml` 对照。
- 其他：优先官方 checksum/signature；没有就至少比对文件大小与版本号。
- 手工校验示例：

```bash
curl -fLO https://example.com/tool.tar.gz
curl -fLO https://example.com/tool.tar.gz.sha256
sha256sum -c tool.tar.gz.sha256
```

## 注意

- 镜像配置写进 Agent 实际读取的启动文件（非交互 shell 通常只读 `.zshenv`，不读 `.zshrc`）。
- 不要把镜像地址写死进项目代码或 CI；项目应能通过环境变量切换官方源。
- 镜像滞后时不要降级依赖来“适配镜像”；用官方源确认版本。
- 代理环境用 `HTTPS_PROXY`/`HTTP_PROXY`/`NO_PROXY`；不要把它们写进仓库配置。
- 只使用可信镜像；镜像本身也可能被替换，checksum/signature 必须来自官方源。
