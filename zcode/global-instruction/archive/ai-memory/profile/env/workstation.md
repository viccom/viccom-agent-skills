---
kind: environment
abstract: 本机 Ubuntu 24.04 共享 KVM：Bash 只读 ~/.zshenv；体检/坑录在 ~/.jcode/env/；中文字体 Noto Sans SC；CHROME_PATH=~/.local/bin/chromium；技能源 ~/.agents/skill-srcs/；ai-memory :49374 需人工批准。
entities:
- workstation
- shell
- fonts
- chromium
- skill-srcs
tags:
- env
- machine
tier: semantic
type: Note
generated:
  by: process:ai-memory/3.4.2
  at: 2026-11-09T09:16:50Z
---
# 本机工作站环境（yhpc-acloud）

> 由 ~/.zcode/AGENTS.md 迁入（2026-11-09）。机器级事实与纪律；做工具链/浏览器/环境相关工作前读本页。

## 机器与系统

- Ubuntu 24.04 LTS，主机名 yhpc-acloud；16 核 / 31 GiB KVM 虚拟机，多人共用（编译资源纪律另见 `profile/env/build-resources.md`）。
- 交互式 TUI（lazygit/broot/fzf 默认交互）不调用；确需终端复用时 `tmux new-session -d` 后台模式。

## Shell 与 PATH

- **Agent 的 Bash 工具是非交互 zsh，只读 `~/.zshenv`**——需全局生效的 env 必须写 `.zshenv`，写 `.zshrc`/`.profile` 对工具 shell 无效。
- apt 装的在 /usr/bin（Ubuntu 的 bat 二进制名为 batcat，已在 `~/.local/bin/bat` 建软链）；GitHub 预编译二进制装 `~/.local/bin`（PATH 首位）；不用源码编译。
- git 全局已配置 delta 为 pager（core.pager / interactive.diffFilter）。
- 现代 CLI 齐备（2026-09 验证）：fd/rg/bat/delta/eza/dust/procs/jq/yq（Go 版）/gh/tmux/fzf/lazygit；优先现代替代——列目录 fd、看文件 bat/Read、搜索 rg、结构化数据 jq/yq、磁盘 dust、进程 procs。

## 机器体检与坑录

- 体检脚本：`bash ~/.jcode/env/env-check.sh`（开始构建/部署/工具链工作前、反常失败时跑）。
- 机器级填坑录：`~/.jcode/env/pitfalls.md`（个案记一次，第二次出现必须升级为模板/门禁/体检）。已知约束：Rust 构建 openssl-sys 开箱即用（libssl-dev 已装）；**不要设置 `OPENSSL_*` 环境变量**（会遮蔽系统发现）；openssl 相关另见全局页 `env-openssl-rust`。

## 浏览器（前端自检）

- `CHROME_PATH` 已在 `~/.zshenv` 指向 `~/.local/bin/chromium`（动态解析 Playwright Chromium）；本机内核下 headless 必须 `--no-sandbox`，包装脚本只在 headless 调用时注入。

## 中文字体

- `~/.local/share/fonts/NotoSansSC-VF.otf`（15MB 变量字体，覆盖 100–900 字重）已安装并 fc-cache。装新字体后需 `fc-cache -f ~/.local/share/fonts`。
- 本机原本只有 `Droid Sans Fallback`，Web UI 中文会被它接管（字体栈写 Noto Sans SC 也没用——没装就没有）。
- 行为规则（保留在 AGENTS.md）：CSS 字体栈显式写中文字族且排在 `system-ui` 之前。
- 自托管控制台若要求中文跨机一致，只能自托管 Noto Sans SC 的 unicode-range 分片（202 个 woff2，约 +10MB 二进制），本机未采用。

## 技能源布局

- 各语言与前端技能共用技能源 `~/.agents/skill-srcs/`（git clone，`git pull` 即更新）。
- 已装 Agent 的技能目录为指向它的符号链接：ZCode `~/.zcode/skills`、Claude Code `~/.claude/skills`、Reasonix `~/.reasonix/skills`（2026-09-20 铺设；**只给已装 Agent 铺，未装不预铺**；新装技能：克隆到 skill-srcs → 逐已装 Agent `ln -sfn`）。

## ai-memory 本机部署

- 服务端 `127.0.0.1:49374`，data_dir `~/.local/share/ai-memory`。
- 每小时 scheduler 自动复盘新完成会话（auto-improve），`require_approval=true`——提案落 `_pending/auto-improve` 需人工批准。
- 每 5 个已完成会话做一次跨会话经验蒸馏（唯一能发现"反复出现的工作流与偏好"的通道）。