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
│       ├── guides/                        # 工作流/交叉编译/镜像/编译资源/坑
│       └── archive/                       # 原始机器记忆快照（非可移植）
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
- `guides/` —— spec 工作流、workflow 约定、交叉编译、国内镜像、共享机编译策略、通用坑。
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
- `zcode/global-instruction/` is a **portable** ZCode global-policy package: `AGENTS.md` (cross-project rules, no machine paths or exhaustive skill catalog), `SEDS.md`, `templates/` (machine profile, memory, MCP/hooks, quality gate, health check), `guides/` (spec workflow, worktree/binary conventions, cross-compile, mirrors, shared-machine builds, pitfalls), `validate.sh` (package self-check and quality-gate regression), and `archive/` (raw machine-specific ai-memory/jcode snapshots, not portable). The live `~/.zcode/AGENTS.md` is left unchanged and must not be overwritten by the repo copy. Machine facts belong in a per-machine `machine-profile.md`, not in the repo policy.
- `zcode/prompt-design.md` documents the ZCode prompt architecture: built-in prompts, instruction-file discovery, native/ai-memory, skills, MCP, hooks, plugins, subagents and compaction, with evidence levels and reproduction commands.
- `skills/` currently holds 1 first-party skill (`1panel-ops`), 126 licensed vendored third-party skills, and 14 skills with unconfirmed provenance/license (included at the owner's explicit request; see `third-party/UNVERIFIED.md`). Keep vendored content as upstream wrote it; provenance/versions/licenses live in `third-party/SOURCES.md` and `third-party/licenses/`. Never add a skill whose license or upstream is unclear without the owner's explicit approval.
- **Never hardcode** machine-specific values (IPs, domains, ports, install paths) in **first-party** skills. Use placeholders resolved by detection scripts.
- **Prefer APIs over generated files.** Document which files are generated and must not be hand-edited.
- Mark capability boundaries: what the API supports, what needs human action.
- Destructive operations require explicit user confirmation in the skill docs.
- Scripts: stdlib-only Python 3.8+, executable bit set, read-only detection separate from write operations, credentials at `0600`.
- Run the self-check block before committing. Never commit `__pycache__` or credentials.
