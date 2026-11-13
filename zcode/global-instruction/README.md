# ZCode 全局指令与模板

本目录是一套**可移植**的 ZCode 全局指令包：策略、模板与指南分开，复制到其他电脑时只取需要的部分。

- 基线：ZCode 3.17.2；升级大版本后复核 ZCode 的指令发现规则与预算。
- 不依赖 MCP、ai-memory 或任何记忆服务；没有它们也能工作。
- 不含 token、API key、密码。
- `~/.zcode` 指 ZCode 用户配置目录；Windows 通常为 `%USERPROFILE%\.zcode`。
- 安装命令以 Linux/macOS（或 WSL/Git Bash）为例；`validate.sh`、`templates/env-check.example.sh`、`templates/quality.just` 依赖 Bash/just，Windows 原生环境可只用文本文件。

> ⚠️ 覆盖前确认：`~/.zcode/AGENTS.md` 若已按本机改过（记忆服务路由、机器路径、技能目录等），**不要**用本包的 `AGENTS.md` 直接覆盖它。本包给的是可移植策略；本机适配请自行合并，或把本包放在独立目录只作参考。

## 目录

```text
global-instruction/
├── AGENTS.md                 # 可移植全局策略（装到 ~/.zcode/AGENTS.md）
├── SEDS.md                   # 项目级 AGENTS.md 十四段式模板
├── README.md                 # 本文件
├── validate.sh               # 包自检：JSON/shell/链接/密钥/门禁回归
├── guides/                   # 可移植流程与排查指南
│   ├── spec-driven-workflow.md
│   ├── workflow-conventions.md
│   ├── anti-rationalizations.md
│   ├── skill-authoring.md
│   ├── cross-compile-windows-rust.md
│   ├── network-mirrors-cn.md
│   ├── shared-machine-build-policy.md
│   └── pitfalls-generic.md
└── templates/                # 可复制/可填写的模板
    ├── machine-profile.example.md
    ├── MEMORY.example.md
    ├── mcp.example.json
    ├── hooks.example.json
    ├── plugins.example.json
    ├── quality.just
    └── env-check.example.sh
```

## 安装到另一台电脑

### 最小安装（只要行为约束）

```bash
mkdir -p ~/.zcode
cp AGENTS.md ~/.zcode/AGENTS.md
cp SEDS.md ~/.zcode/SEDS.md          # 可选；项目级模板
```

`AGENTS.md` 不依赖 `SEDS.md` 也能工作；`SEDS.md` 只在生成项目级 `AGENTS.md` 时参考。

### 完整安装（策略 + 模板 + 指南）

把包内容复制到 `~/.zcode/`，这样 `AGENTS.md` 里的 `guides/...`、`templates/...` 与 `AGENTS.md` 所在目录一致：

```bash
mkdir -p ~/.zcode/guides ~/.zcode/templates
cp AGENTS.md SEDS.md validate.sh ~/.zcode/
cp -r guides/. ~/.zcode/guides/
cp -r templates/. ~/.zcode/templates/
```

> 用 `cp -r guides/. dest/` 明确复制目录内容；不同 `cp` 实现对已存在目标目录的处理可能不同。
> 目标目录已有同名文件会被覆盖，先备份或改用独立目录。
>
> 不想污染 `~/.zcode/` 时，只复制 `AGENTS.md` 到 `~/.zcode/AGENTS.md` 即可；第 10 节的
> `guides/`、`templates/` 是可选项，缺失时对应引用按“可选扩展”处理。

然后：

1. 复制 `templates/machine-profile.example.md` 为 `~/.zcode/machine-profile.md`，填入本机事实；**不要提交含主机名/凭据的版本**。
2. 按需把 `templates/quality.just` 复制到项目可访问的位置，在 `justfile` 里 `import`。
3. 按需复制 `templates/mcp.example.json` / `hooks.example.json` 的结构到 `~/.zcode/cli/config.json`，替换占位符，配置文件 `chmod 600`。
4. 运行 `bash ~/.zcode/templates/env-check.example.sh` 做一次环境体检（按本机情况增删检查项）。

## 规则放哪里

ZCode 只加载 `~/.zcode/AGENTS.md` + **会话 workspace** 向上最近的**一个** `AGENTS.md`（到仓库根为止；无 git 时到文件系统根），不会叠加仓库根与子目录；`CLAUDE.md` 默认不读。

| 规则类型 | 放置位置 | 是否自动进入上下文 |
|---|---|---|
| 跨项目行为底线 | `~/.zcode/AGENTS.md` | 是，所有项目 |
| 项目构建/测试/架构 | workspace 根 `AGENTS.md` | 是，最近一个 |
| 子目录模块规则 | 并入 workspace 根 `AGENTS.md`，或把该子目录作为 workspace 打开 | 单独的子目录 `AGENTS.md` 不会与根叠加 |
| 机器事实 | `~/.zcode/machine-profile.md` | 由 `AGENTS.md` 指示按需读取 |
| 长期项目决策 | 仓库 `docs/` / ADR | 由项目 `AGENTS.md` 指示按需读取 |
| 一次性要求 | 当前用户消息 | 是，当前轮 |

判断标准：这条规则如果放错层，Agent 会更容易犯错吗？会就放对；不会就不写。

## 安装后自检

完整安装：

```bash
bash ~/.zcode/validate.sh          # 包结构/JSON/shell/链接/密钥/门禁回归
bash ~/.zcode/templates/env-check.example.sh
```

最小安装只需：

```bash
test -s ~/.zcode/AGENTS.md && echo "AGENTS.md installed"
```

新开一个 ZCode 会话，确认：

1. 上下文里出现 `Contents of ~/.zcode/AGENTS.md`。
2. 项目规则只来自最近一个 workspace `AGENTS.md`；仓库根/子目录没有叠加。
3. 放入一个 `CLAUDE.md` 不会被加载（ZCode 默认只认 `AGENTS.md`）。

## 卸载/回滚

```bash
rm -f  ~/.zcode/AGENTS.md ~/.zcode/SEDS.md
rm -rf ~/.zcode/guides ~/.zcode/templates ~/.zcode/validate.sh
# ~/.zcode/machine-profile.md 是否删除由你决定
```

删除前先确认这些路径没有你自己的内容；本包不覆盖 `~/.zcode/AGENTS.md` 之外的全局配置。

## 不要安装

- `templates/*.example.*`：它们是模板，不是可直接运行的配置；必须替换占位符。

## 维护

- `AGENTS.md` 是跨项目策略，**不要**把机器路径、技能目录、API key 写进去。
- 机器事实放 `machine-profile.md`（每台机器自己的，不进仓库）。
- 项目事实放项目级 `AGENTS.md`。
- 技能/流程细节放 `guides/`；可复制骨架放 `templates/`。
- 变更后跑 `validate.sh`；再跑 4 个代表任务：读取全局规则、拒绝越权、完成门禁并报告证据、项目规则只来自最近一个 `AGENTS.md`。

## 安全

- 本目录不含 token、API key、密码。
- `mcp.example.json` / `hooks.example.json` 只有结构占位符；真实配置写 `~/.zcode/cli/config.json`（`0600`）。
- hook 会执行本地命令；从仓库复制 hook 配置前先审查命令与参数。
- 插件可贡献 skills/MCP/hooks；启用前审查来源与权限。
- 项目级 MCP 声明需要 workspace trust；不要因为 clone 了仓库就自动信任并连接。
