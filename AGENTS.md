# AGENTS.md — 仓库工作指南

本文件面向在此仓库工作的 AI Agent 与贡献者。**它是仓库本地的约定，不随单个技能分发。**

---

## 仓库是什么

一个可移植 AI Agent 技能集合。根目录**不是**一个技能，而是技能的容器。

```
viccom-agent-skills/
├── README.md           # 面向使用者：是什么、怎么装
├── AGENTS.md           # 面向贡献者/Agent：怎么改、怎么加
├── LICENSE
├── third-party/        # 第三方技能来源、许可与未收录清单
│   ├── SOURCES.md      # 126 个许可明确的第三方技能
│   ├── UNVERIFIED.md   # 14 个来源/许可未确认技能（所有者授权收录）
│   ├── EXCLUDED.md
│   └── licenses/
├── zcode/              # ZCode 提示词体系文档与可移植全局指令
│   ├── prompt-design.md
│   └── global-instruction/
│       ├── AGENTS.md                      # 可移植策略（不改本机源文件）
│       ├── SEDS.md
│       ├── README.md
│       ├── validate.sh                    # 包自检（JSON/shell/链接/密钥/门禁回归）
│       ├── templates/                     # 机器 profile/记忆/MCP/hooks/门禁/体检
│       ├── guides/                        # 工作流/反理性化/skill 编写/交叉编译/镜像/编译资源/坑
│       └── archive/                       # 原始机器记忆快照（非可移植）
├── claude-code/         # Claude Code 提示词体系文档与可移植全局指令
│   ├── prompt-design.md # Claude Code 2.1.322 提示词体系设计（版本相关，非可移植）
│   ├── custom-provider-and-privileged-shell.md  # 自定义接入与高权限 shell（机器相关，非可移植）
│   └── global-instruction/
│       ├── CLAUDE.md                      # 可移植策略（本机 live 是适配版，勿覆盖）
│       ├── SEDS.md
│       ├── README.md
│       ├── validate.sh                    # 包自检（含预算与跨宿主引用检查）
│       ├── templates/                     # machine-profile/auto-memory/MCP/hooks/plugins/门禁/体检
│       ├── guides/                        # 与 zcode 包同源 6 篇（spec 工作流已适配 Claude 机制）
│       └── archive/                       # 改写前本机 CLAUDE.md 快照（非可移植）
├── codex/               # Codex 提示词体系文档与可移植全局指令
│   ├── prompt-design.md # Codex 0.167.1 提示词体系设计（版本相关，非可移植）
│   ├── custom-provider-and-privileged-shell.md  # 自定义 provider/模型目录与高权限 shell（机器相关，非可移植）
│   └── global-instruction/
│       ├── AGENTS.md                      # 可移植策略（本机 live 由包安装）
│       ├── SEDS.md
│       ├── README.md
│       ├── validate.sh                    # 包自检（JSON/TOML/shell/链接/密钥/预算/门禁回归）
│       ├── templates/                     # machine-profile/Memories/MCP/hooks/plugins/skill-routing/门禁/体检
│       ├── guides/                        # 共享 8 篇 + Codex harness 观测
│       └── archive/                       # 建立前状态说明（非可移植）
└── skills/
    └── <skill-name>/   # 每个子目录 = 一个独立可分发的技能
        ├── SKILL.md
        ├── references/
        └── scripts/
```

## 自有技能与第三方技能

- **自有技能**：`1panel-ops`。本文件的全部约定都适用于它。
- **第三方技能（许可明确）**：126 个目录。按上游原样收录，只做必要的加载适配（目前仅 `ruff` 调整了 frontmatter）。**不要改写其正文**，不要套用「禁止写死环境参数」检查，也不要删除其中的品牌名、示例域名或第三方工具引用。
- **来源/许可未确认技能**：14 个目录，按仓库所有者明确授权收录，清单与风险见 [`third-party/UNVERIFIED.md`](third-party/UNVERIFIED.md)。这些技能**不得**当作可再分发内容对待；公开推送前需所有者再次确认。
- 来源、固定版本与许可：[`third-party/SOURCES.md`](third-party/SOURCES.md)；完整许可文本：[`third-party/licenses/`](third-party/licenses/)；未收录清单：[`third-party/EXCLUDED.md`](third-party/EXCLUDED.md)。
- **新增第三方技能**：优先确认 MIT/Apache-2.0 等宽松许可 → 拷贝到 `skills/<name>/` → 更新 `SOURCES.md`、复制 LICENSE 到 `third-party/licenses/` → 更新 README 索引。来源或许可不明的技能默认不收录；如所有者明确要求，记入 `UNVERIFIED.md`，不得直接放进 `SOURCES.md`。
- **更新第三方技能**：以上游仓库为准手动同步，并同步更新 `SOURCES.md` 中的 commit；不要把上游文件改成仓库自有风格。

## ZCode 全局指令与模板

`zcode/global-instruction/` 是**可移植**的 ZCode 全局策略包，用于复制到其他机器，**不是技能**，不参与 `skills/` 索引，也不随技能安装：

- `AGENTS.md` —— 跨项目行为约束；已去除机器路径与技能目录，可在未安装 ai-memory 的机器上独立使用。**本机源文件 `~/.zcode/AGENTS.md` 保持原样，不要用仓库副本覆盖它。**
- `SEDS.md` —— 项目级 `AGENTS.md` 十四段式模板。
- `README.md` —— 安装/复制/维护说明。
- `validate.sh` —— 包自检：JSON/shell/链接/密钥/质量门禁回归。
- `templates/` —— 机器 profile、原生记忆、MCP/hooks、质量门禁、体检脚本模板。
- `guides/` —— spec 工作流、workflow 约定、反理性化表、skill 编写规范、交叉编译、国内镜像、共享机编译策略、通用坑（8 篇）。
- `archive/` —— 原始 ai-memory/jcode 机器快照，**非可移植**，仅供追溯。

维护规则：

- **本机源文件保持原样**；仓库副本是可移植策略，不能用源文件直接覆盖。
- **ZCode 只加载全局 `~/.zcode/AGENTS.md` + 会话 workspace 最近一个 `AGENTS.md`**；项目规则放 workspace 根，子目录规则并入根文件或把子目录作为 workspace 打开。`CLAUDE.md` 默认不读。
- 机器事实放 `machine-profile.md`（每台机器自己的，不进仓库）；项目事实放项目级 `AGENTS.md`；跨项目规则才放 `AGENTS.md`。
- 不把技能目录、主机名、端口、token 写进 `AGENTS.md`；原始机器事实放 `archive/`。
- 更新流程：从源文件/记忆页提取可移植内容 → 去掉机器事实与凭据 → 用 `grep` 检查本机路径 → 更新 `AGENTS.md`/`guides`/`templates`。
- 改动本包后跑 `bash zcode/global-instruction/validate.sh`；它检查 JSON/shell/链接/密钥，并回归测试质量门禁是否会漏掉暂存区密钥。
- 公开可见；**不得放入密钥、token 或凭据**。

## ZCode 提示词体系文档

[`zcode/prompt-design.md`](zcode/prompt-design.md) 记录本机 ZCode 3.17.2 的提示词装配：内置提示词、`AGENTS.md` 发现规则、原生记忆与 ai-memory、Skill、MCP、Hooks、Plugins、Subagents 与 compaction，并给出 harness 映射与指令放置矩阵。文档区分已确认/推断/未知，并给出关键常量与复现命令。

## Claude Code 提示词体系文档

[`claude-code/prompt-design.md`](claude-code/prompt-design.md) 记录本机 Claude Code 2.1.322 的提示词装配：内置提示词、`CLAUDE.md`/`AGENTS.md`/rules 发现规则、auto memory、Skill、MCP、Hooks、Plugins、Subagents、Compaction 与 Prompt Caching，并给出本机请求快照、harness 映射、常量与复现命令。文档区分已确认/推断/未知；版本相关、机器相关，不属于可移植包。

## Claude Code 全局指令与模板

`claude-code/global-instruction/` 是**可移植**的 Claude Code 全局策略包，与 zcode 包**同源异构**（§0-§10 策略一致；发现规则、记忆与配置模板按 Claude Code 机制适配）。不是技能，不随技能安装：

- `CLAUDE.md` —— 跨项目行为约束（十节：优先级表 / MUST 底线 / 工作流 / 完成定义 GATE / 调试熔断 / 沟通 / 能力路由 / CLAUDE.md 发现规则与 auto memory / 机器环境 / 工作流默认值）。
- `SEDS.md` —— 项目级 `CLAUDE.md` 十四段式模板（序言为 Claude 发现规则：祖先链全量拼接 / 子目录懒加载 / `CLAUDE.local.md`）。
- `README.md` —— 安装（最小/完整）/放置矩阵/新会话自检/卸载/维护（live 重建配方）/安全。
- `validate.sh` —— 包自检：JSON/shell/链接/密钥 + 预算（≤200 行/14,000B）+ 无 `@` import + 无跨宿主引用 + 门禁回归。
- `templates/` —— machine-profile、auto memory 说明、MCP/hooks/plugins **合并片段**示例、`quality.just`、体检脚本。
- `guides/` —— 与 zcode 包同源 6 篇（`spec-driven-workflow.md` 已按 Claude 发现规则适配）。
- `archive/` —— 改写前本机 `~/.claude/CLAUDE.md` 快照，**非可移植**。

维护规则：

- **本机 live 文件是适配版**：`~/.claude/CLAUDE.md` = 包 §0-§10（逐字一致）+ 本机头部声明 + §11 本机适配（`@RTK.md` import、编码团队情况、工作环境、落地物路径、Agent Comms）。**不要用仓库副本直接覆盖 live 文件**；改全局策略先改包，再同步 live 的 §0-§10。
- **基线 Claude Code 2.1.322**（本机当前；包最低验证版本仍为 2.1.259）：2.1.322 已直读 `AGENTS.md`（2.1.277+），并有 `/doctor prompt-audit`（2.1.283+）。仓库根 `AGENTS.md` 会被注入，可能与项目 `CLAUDE.md` 叠加；改动指令布局时按 [`claude-code/prompt-design.md`](claude-code/prompt-design.md) §3 复核。
- Claude Code 加载机制与 ZCode 不同：cwd 到根**全链拼接**、子目录懒加载、`CLAUDE.local.md`、`~/.claude/rules/`（含 `paths:`）、auto memory 每仓库目录——放置规则见包 `README.md`，不要照搬 zcode 的"最近一个"结论。
- 机器事实与技能路由放本机 `machine-profile.md` / `skill-routing.md`，不进包；`~/.claude/skill-routing.md` 与 `~/.zcode/skill-routing.md` 按宿主各自维护。
- 改动本包后跑 `bash claude-code/global-instruction/validate.sh`。
- 公开可见；**不得放入密钥、token 或凭据**；不要把 live `settings.json`（含真实 token）复制进包或模板。

## Codex 提示词体系文档

[`codex/prompt-design.md`](codex/prompt-design.md) 记录本机 Codex 0.167.1 的提示词装配：模型目录提供的 base instructions、WorldState 增量上下文、`AGENTS.md` root→cwd 指令链、Skill、MCP、Hooks、Plugins、Subagents、Memories、Compaction 与 Prompt Caching，并给出本机快照、harness 映射、常量与复现命令。文档区分已确认/推断/未知；版本相关、机器相关，不属于可移植包。

## 自定义接入与高权限 Shell

[`codex/custom-provider-and-privileged-shell.md`](codex/custom-provider-and-privileged-shell.md) 记录 Codex 的非官方 API 接入：`[model_providers.*]`、`base_url`/`env_key`/`wire_api`、`model_catalog_json` 目录字段、本机模型列表、验证与故障排查，以及 `codexx`（`--dangerously-bypass-approvals-and-sandbox`）别名能做什么、不能保证什么。含脱敏本机配置，不含 token；版本/机器相关，不属于可移植包。

[`claude-code/custom-provider-and-privileged-shell.md`](claude-code/custom-provider-and-privileged-shell.md) 记录 Claude Code 2.1.322 的 Anthropic 兼容网关接入：`ANTHROPIC_BASE_URL`/`ANTHROPIC_AUTH_TOKEN`、模型别名映射、上下文/推理/超时变量、本机实测的环境变量优先级，以及 `claudex`（`--dangerously-skip-permissions`）的边界（root/sudo 会被拒绝、`--restricted` 会拒绝 bypass）。含脱敏配置，不含 token。

两篇文档都记录了会话历史（Codex rollout / Claude JSONL）可能落明文凭据的风险、检测脚本与轮换/清理顺序。

## Codex 全局指令与模板

`codex/global-instruction/` 是**可移植**的 Codex 全局策略包，与 zcode/claude-code 包同源异构（核心行为策略一致；发现规则、记忆与配置模板按 Codex 机制适配）。不是技能，不随技能安装：

- `AGENTS.md` —— 跨项目行为约束（优先级 / MUST 底线 / 工作流 / 完成定义 GATE / 调试熔断 / 沟通 / 能力路由 / Codex 指令发现 / 机器环境 / 工作流默认值）。
- `SEDS.md` —— 项目级 `AGENTS.md` 十四段式模板（序言为 Codex 发现规则：全局 + root→cwd 拼接 / 同目录 override / 32 KiB 预算 / 不读 CLAUDE.md / 不懒加载）。
- `README.md` —— 安装（最小/完整）/放置矩阵/新会话自检/卸载/维护/安全。
- `validate.sh` —— 包自检：JSON/TOML/shell/链接/密钥 + 预算（≤240 行/20,000B）+ 无 `@` import + 无跨宿主引用 + 门禁回归。
- `templates/` —— machine-profile、Memories、MCP TOML、hooks JSON、plugins TOML、skill-routing、精选技能安装脚本、`quality.just`、体检脚本。
- `guides/` —— 共享 8 篇 + `codex-harness-inspection.md`（共 9 篇）。
- `archive/` —— 建立本包前的状态说明，**非可移植**。

维护规则：

- **live 文件由包安装**：`~/.codex/AGENTS.md` 是包内 `AGENTS.md` 的副本；`~/.codex/global-instruction/` 保存完整包，`SEDS.md`/`guides`/`templates`/`validate.sh` 用软链。改全局策略先改包，再同步 live 副本。
- **本机事实分离**：`~/.codex/machine-profile.md` 与 `~/.codex/skill-routing.md` 是本机文件，**不进仓库**；不要把主机、端口、token 写进 `AGENTS.md`。
- **Codex 发现机制与 ZCode/Claude Code 不同**：全局 `AGENTS.override.md` → `AGENTS.md`；项目根→cwd 逐目录拼接；同目录 override 替换；项目链默认 32 KiB；提示词发现不读 `CLAUDE.md`、不支持 `@import`、子目录不懒加载。
- 改动本包后跑 `bash codex/global-instruction/validate.sh`，再跑 8 个代表任务：全局规则、项目链/override、越权拒绝、完成门禁证据、Skill 触发、Hook 门禁、MCP 路由、压缩后重定位。
- 公开可见；**不得放入密钥、token 或凭据**；不要把 live `config.toml`（可能含 provider 凭据配置）或 `machine-profile.md` 复制进包。

## 添加一个新技能

1. **建目录**：`skills/<skill-name>/`，名字用 kebab-case，与 `SKILL.md` 的 `name` 一致。
2. **写 frontmatter**：

   ```yaml
   ---
   name: skill-name
   description: 触发场景 + 能力概述，一句话，≤120 字符为佳
   ---
   ```

   `description` 是 Agent 决定是否加载的唯一依据。**写清楚「什么时候用」，不只是「能做什么」。**

3. **按需建子目录**：
   - `references/` —— 长文档、API 契约、字段表。SKILL.md 里用相对路径引用。
   - `scripts/` —— 可执行辅助脚本。**必须加执行位**（`chmod +x`）。
4. **更新 `README.md`** 的分类索引与技能总数；若是第三方技能，同时更新 `third-party/SOURCES.md` 与许可文件。
5. **自检**（见下）。

## 硬性约定

### 1. 禁止写死环境参数

| 禁止 | 替代 |
|---|---|
| `/opt/1panel` | `<install_dir>`，由探测脚本给出 |
| `192.168.1.10` | `<host>` / 探测结果 |
| `example.com` 之外的真实域名 | 一律用 `example.com` / `example.test` |
| 具体端口（除非是协议固定的） | 从探测结果或 API 查询取 |
| 真实 API Key、密码、token | 绝不出现；只写文件路径与权限要求 |

**检查方法（仅自有技能，第三方技能不适用；允许 `127.0.0.1`/`::1` 回环地址）**：

```bash
grep -rnE '([0-9]{1,3}\.){3}[0-9]{1,3}|[a-z0-9-]+\.(com|top|cn|net|org)' \
  skills/1panel-ops/SKILL.md skills/1panel-ops/references/ 2>/dev/null \
  | grep -vE 'example\.(com|test)|127\.0\.0\.1'
```

### 2. 优先 API，不改生成物

若目标系统有 API：

- 所有状态变更走 API
- 文档里明确标注「这些文件是生成物，不要手改」
- 若某功能确实没有 API，明确写出「只能改配置文件」，并说明为什么

### 3. 能力边界要写清

每个技能必须说明：

- ✅ API 支持什么（已实测）
- ❌ API 不支持什么（需人工介入的）
- ⚠️ 有前提条件的（需要特定权限、特定版本）

### 4. 危险操作要护栏

删除、停机、覆盖、改绑类操作，SKILL.md 里必须写：

> 执行前先向用户确认，并回显目标（id + 名称）

### 5. 脚本规范

- Python 3.8+，仅用标准库（降低依赖门槛）
- 每个脚本有 `--help` 或文档字符串说明用法
- 可执行脚本加执行位
- **只读探测与写操作分开**（如 `p1detect.py` 只读，`p1api.py` 可写）
- 凭据文件权限 `0600`
- 错误信息要可操作：「run scripts/p1detect.py --write」而非「config missing」

## 自检清单

提交前跑一遍：

```bash
# 1. 自有技能语法检查
python3 -m py_compile skills/1panel-ops/scripts/*.py && echo "py_compile OK"

# 2. 自有技能执行位
find skills/1panel-ops/scripts -name '*.py' ! -perm -u+x -print

# 3. 本机标识残留（仅自有技能；允许回环地址，应无输出）
grep -rnE '([0-9]{1,3}\.){3}[0-9]{1,3}|\.(com|top|cn|net|org)\b' \
  skills/1panel-ops/SKILL.md skills/1panel-ops/references/ \
  | grep -vE 'example\.(com|test)|127\.0\.0\.1'

# 4. 全部技能 frontmatter 基本完整
python3 - <<'PY'
import pathlib
bad = [str(sp) for sp in pathlib.Path("skills").glob("*/SKILL.md")
       if not sp.read_text(errors="ignore").startswith("---")
       or "\nname:" not in sp.read_text(errors="ignore")]
print("frontmatter issues:", bad or "none")
PY

# 5. 第三方来源与许可清单存在
test -s third-party/SOURCES.md && test -d third-party/licenses && echo "third-party OK"

# 6. 清理构建产物
find . -name '__pycache__' -o -name '*.pyc'

# 7. zcode 可移植策略包自检（JSON/shell/链接/密钥/质量门禁回归）
bash zcode/global-instruction/validate.sh

# 8. claude-code 可移植策略包自检（JSON/shell/链接/密钥/预算/跨宿主引用/门禁回归）
bash claude-code/global-instruction/validate.sh

# 9. codex 可移植策略包自检（JSON/TOML/shell/链接/密钥/预算/门禁回归）
bash codex/global-instruction/validate.sh
```

## 提交约定

- 提交信息用中文或英文均可，说明「改了什么、为什么」
- 一个提交只做一件事
- **不提交**：`__pycache__`、`*.pyc`、凭据文件、环境探测生成的 `profile.json`
- 不加 AI 署名尾注

## 版本与兼容

- 技能内部的破坏性变更（改脚本参数、改 SKILL.md 结构）在提交信息里标注 `BREAKING`
- `SKILL.md` 的 frontmatter `name` 一旦发布**不要改名**——使用者可能已装到本地目录

## English summary

Repository conventions for agents and contributors:

- Root is a **container**, not a skill. Each `skills/<name>/` is independently distributable.
- `zcode/global-instruction/` is a **portable** ZCode global-policy package: `AGENTS.md` (cross-project rules, no machine paths or exhaustive skill catalog), `SEDS.md`, `templates/` (machine profile, memory, MCP/hooks, quality gate, health check), `guides/` (spec workflow, worktree/binary conventions, anti-rationalizations, skill authoring, cross-compile, mirrors, shared-machine builds, pitfalls), `validate.sh` (package self-check and quality-gate regression), and `archive/` (raw machine-specific ai-memory/jcode snapshots, not portable). The live `~/.zcode/AGENTS.md` is left unchanged and must not be overwritten by the repo copy. Machine facts belong in a per-machine `machine-profile.md`, not in the repo policy.
- `zcode/prompt-design.md` documents the ZCode prompt architecture: built-in prompts, instruction-file discovery, native/ai-memory, skills, MCP, hooks, plugins, subagents and compaction, with evidence levels and reproduction commands.
- `claude-code/global-instruction/` is a **portable** Claude Code global-policy package symmetric to the zcode one (same §0-§10 policy core; discovery rules, auto memory and config templates adapted to Claude Code mechanics). The live `~/.claude/CLAUDE.md` is the machine adaptation (package §0-§10 + local §11) and must not be overwritten by the repo copy. Claude Code concatenates every ancestor `CLAUDE.md` (not nearest-only), lazy-loads subdirectory files, and reads `CLAUDE.local.md` — see the package README for the placement matrix. Run `bash claude-code/global-instruction/validate.sh` after changes.
- `codex/global-instruction/` is a **portable** Codex global-policy package adapted to Codex mechanics: `AGENTS.override.md`/`AGENTS.md` global precedence, root→cwd project chain, per-directory overrides, a 32 KiB project budget, no `CLAUDE.md` prompt discovery, no `@import`, and no subdirectory lazy loading. Its `guides/` add anti-rationalizations and skill authoring alongside the shared workflow guides and `codex-harness-inspection`. The live `~/.codex/AGENTS.md` is a copy of the package policy; machine facts live in `~/.codex/machine-profile.md` and `~/.codex/skill-routing.md`. Run `bash codex/global-instruction/validate.sh` after changes.
- `codex/prompt-design.md` documents the Codex 0.167.1 prompt architecture: model-owned base instructions, incremental WorldState context, AGENTS.md discovery, skills, MCP, hooks, plugins, subagents, memories, compaction and prompt caching, with evidence levels and reproduction commands.
- `skills/` currently holds 1 first-party skill (`1panel-ops`), 126 licensed vendored third-party skills, and 14 skills with unconfirmed provenance/license (included at the owner's explicit request; see `third-party/UNVERIFIED.md`). Keep vendored content as upstream wrote it; provenance/versions/licenses live in `third-party/SOURCES.md` and `third-party/licenses/`. Never add a skill whose license or upstream is unclear without the owner's explicit approval.
- **Never hardcode** machine-specific values (IPs, domains, ports, install paths) in **first-party** skills. Use placeholders resolved by detection scripts.
- **Prefer APIs over generated files.** Document which files are generated and must not be hand-edited.
- Mark capability boundaries: what the API supports, what needs human action.
- Destructive operations require explicit user confirmation in the skill docs.
- Scripts: stdlib-only Python 3.8+, executable bit set, read-only detection separate from write operations, credentials at `0600`.
- Run the self-check block before committing. Never commit `__pycache__` or credentials.
