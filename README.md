# viccom-agent-skills

> 一套可移植的 AI Agent 技能集合，适用于 ZCode、Reasonix、Claude Code 等支持 `SKILL.md` 约定的 Agent。
> A collection of portable AI agent skills following the `SKILL.md` convention.

---

## 中文

### 这是什么

本仓库收集可直接扔进 Agent 技能目录使用的技能包。每个技能都是**自包含**的：把对应子目录拷走就能用，不依赖仓库里的其它内容。

仓库现有 **141 个技能**：

- **1 个自有技能**：`1panel-ops`
- **126 个许可明确的第三方技能**：来自 15 个开源项目，按原样收录。来源、版本固定与许可见 [`third-party/SOURCES.md`](third-party/SOURCES.md)；完整许可文本在 [`third-party/licenses/`](third-party/licenses/)。
- **14 个来源/许可未确认的技能**：按仓库所有者要求收录，清单与风险说明见 [`third-party/UNVERIFIED.md`](third-party/UNVERIFIED.md)。
- 未收录的技能及原因见 [`third-party/EXCLUDED.md`](third-party/EXCLUDED.md)。

> ⚠️ 上述 14 个技能没有明确许可。仓库是公开的，公开分发/再发布前请自行评估版权风险。
>
> 📁 另含 [`zcode/global-instruction/`](zcode/global-instruction/)：**可移植**的 ZCode 全局策略包（`AGENTS.md`、`SEDS.md`、`templates/`、`guides/`、`validate.sh`），供复制到其他机器使用；`archive/` 保留原始机器快照，非可移植。**不是可安装技能**，不含密钥。
>
> 📁 另含 [`claude-code/global-instruction/`](claude-code/global-instruction/)：**可移植**的 Claude Code 全局策略包（`CLAUDE.md`、`SEDS.md`、`templates/`、`guides/`、`validate.sh`），与 zcode 包同源异构（策略一致，发现规则与模板按 Claude Code 机制适配）；`archive/` 保留改写前本机快照，非可移植。**不是可安装技能**，不含密钥。
>
> 📖 ZCode 提示词体系设计见 [`zcode/prompt-design.md`](zcode/prompt-design.md)：内置提示词、指令文件、记忆、Skill、MCP 的分层与预算，以及 harness 映射与指令放置矩阵。
>
> 📖 Claude Code 提示词体系设计见 [`claude-code/prompt-design.md`](claude-code/prompt-design.md)：2.1.322 的请求分层、内置提示词、CLAUDE.md/AGENTS.md/rules、auto memory、Skill、MCP、Hooks、Plugins、Subagents、Compaction 与缓存，并附本机快照与复现命令。

设计目标：

- **可移植** —— 自有技能不写死某台机器的 IP、域名、端口、路径。环境相关的参数由探测脚本或配置文件提供。
- **可验证** —— 脚本里嵌入了真实环境的实测结论（哪些接口必须、哪些参数必填、哪些做法会踩坑）。
- **安全默认** —— 危险操作（删除、停机、覆盖）在 SKILL.md 里明确要求先向用户确认。

### 技能列表

| 分组 | 数量 | 来源 / 说明 |
|---|---:|---|
| Go 工程 | 46 | `samber/cc-skills-golang`（MIT） |
| Spring Boot 4 | 33 | `rrezartprebreza/spring-boot-skills`（MIT） |
| Java 架构与工程实践 | 18 | `decebals/claude-code-java`（MIT） |
| Node / TypeScript / Vue | 7 | `antfu/skills`（5）+ `mcollina/skills`（2），MIT |
| 设计 / 前端 | 9 | `ui-ux-pro-max-skill`、`anydesign`、`taste-skill`、`anthropics/skills` frontend-design、`hallmark`、`image-manipulation-image-magick`、`web-design-guidelines`、`type-styles-and-radius` |
| 研发流程 | 16 | `obra/superpowers`（MIT）派生的计划/调试/TDD/评审技能 + `code-review-skill`、`code-reviewer`、`software-architecture-design`、`writing-clearly-and-concisely` |
| Rust | 5 | `leonardomso/rust-skills`（MIT）+ `m01-ownership`、`m06-error-handling`、`rust-best-practices`、`rust-router` |
| 工具与运维 | 5 | `1panel-ops`、`ruff`、`open-code-review`、`agent-reach`、`find-skills` |
| Python | 1 | `modern-python` |
| 文档 / 办公 | 1 | `officecli` |
| **合计** | **141** | |

#### 完整索引

**Go 工程（46）**

`golang-benchmark`、`golang-cli`、`golang-code-style`、`golang-concurrency`、`golang-context`、`golang-continuous-integration`、`golang-data-structures`、`golang-database`、`golang-dependency-injection`、`golang-dependency-management`、`golang-design-patterns`、`golang-documentation`、`golang-error-handling`、`golang-google-wire`、`golang-gopls`、`golang-graphql`、`golang-grpc`、`golang-how-to`、`golang-lint`、`golang-modernize`、`golang-naming`、`golang-observability`、`golang-performance`、`golang-pkg-go-dev`、`golang-popular-libraries`、`golang-project-layout`、`golang-refactoring`、`golang-safety`、`golang-samber-do`、`golang-samber-hot`、`golang-samber-lo`、`golang-samber-mo`、`golang-samber-oops`、`golang-samber-ro`、`golang-samber-slog`、`golang-security`、`golang-spf13-cobra`、`golang-spf13-viper`、`golang-stay-updated`、`golang-stretchr-testify`、`golang-structs-interfaces`、`golang-swagger`、`golang-testing`、`golang-troubleshooting`、`golang-uber-dig`、`golang-uber-fx`

**Spring Boot 4（33）**

`ai-observability`、`api-versioning`、`configuration-properties`、`container-native-deployment`、`domain-driven-design`、`event-driven-messaging`、`flyway-migrations`、`hateoas`、`hexagonal-architecture`、`http-interface-clients`、`idempotency-patterns`、`layered-architecture`、`mcp-server`、`multi-module-maven`、`multi-tenancy`、`null-safety`、`oauth2-resource-server`、`openapi-first`、`problem-details-rfc9457`、`production-observability`、`resilience-retry`、`rest-api-conventions`、`spring-ai-integration`、`spring-batch`、`spring-boot-migration`、`spring-cloud-gateway`、`spring-data-jpa`、`spring-data-redis`、`spring-modulith`、`spring-security-jwt`、`testing-pyramid`、`transactional-patterns`、`webflux-reactive-patterns`

**Java 架构与工程实践（18）**

`api-contract-review`、`architecture-review`、`changelog-generator`、`clean-code`、`concurrency-review`、`design-patterns`、`git-commit`、`issue-triage`、`java-code-review`、`java-migration`、`jpa-patterns`、`logging-patterns`、`maven-dependency-audit`、`performance-smell-detection`、`security-audit`、`solid-principles`、`spring-boot-patterns`、`test-quality`

**Node / TypeScript / Vue（7）**

`pinia`、`unocss`、`vite`、`vitest`、`vue`、`node`、`typescript-magician`

**设计 / 前端（9）**

`design-system`、`ui-ux-pro-max`、`anydesign`、`design-taste-frontend`、`frontend-design`、`type-styles-and-radius`、`hallmark`、`image-manipulation-image-magick`、`web-design-guidelines`

**研发流程（16）**

`brainstorming`、`dispatching-parallel-agents`、`executing-plans`、`finishing-a-development-branch`、`receiving-code-review`、`requesting-code-review`、`subagent-driven-development`、`systematic-debugging`、`test-driven-development`、`using-git-worktrees`、`verification-before-completion`、`writing-plans`、`code-review-skill`、`code-reviewer`、`software-architecture-design`、`writing-clearly-and-concisely`

**Rust（5）**

`rust-skills`、`m01-ownership`、`m06-error-handling`、`rust-best-practices`、`rust-router`

**工具与运维（5）**

`1panel-ops`、`ruff`、`open-code-review`、`agent-reach`、`find-skills`

**Python（1）**

`modern-python`

**文档 / 办公（1）**

`officecli`

### 快速开始

```bash
git clone https://github.com/viccom/viccom-agent-skills.git
cd viccom-agent-skills

# 安装单个技能（以 1panel-ops 为例；目标目录换成 ~/.zcode/skills 或 ~/.claude/skills 亦可）
ln -sfn "$PWD/skills/1panel-ops" ~/.reasonix/skills/1panel-ops
```

**安装全部技能**（软链，`git pull` 后自动生效）：

```bash
SKILLS_DIR=~/.zcode/skills   # 或 ~/.claude/skills、~/.reasonix/skills
for d in skills/*/; do
  name=$(basename "$d")
  ln -sfn "$PWD/$d" "$SKILLS_DIR/$name"
done
```

> 警告：上面的循环会用仓库版本覆盖目标目录中的同名技能（包括你本地改过的版本）。先确认没有同名自定义技能，或只对需要的技能逐个建链。
> 若你的 Agent 会跳过 symlink，退回 `cp -r` 方式即可。

装好后先跑一次环境探测（`1panel-ops` 专有步骤）：

```bash
python3 ~/.reasonix/skills/1panel-ops/scripts/p1detect.py
```

探测输出会告诉你：1Panel 装在哪、API 端口是多少、openresty 监听什么端口、现有证书与站点、以及 API Key 是否已就绪。

### 单个技能的通用结构

```
skills/<skill-name>/
├── SKILL.md            # 必需。frontmatter 含 name / description
├── references/         # 可选。详细文档、API 契约、字段说明
└── scripts/            # 可选。可直接执行的辅助脚本
```

`SKILL.md` 的 frontmatter：

```yaml
---
name: skill-name
description: 一句话说明触发场景与能力（Agent 靠它决定是否加载）
---
```

### 设计约定

自有技能（当前为 `1panel-ops`）遵循以下约定：

1. **参数靠探测，不靠假设**
   任何随机器变化的量（路径、端口、域名、ID）都要有获取方式：探测脚本、配置文件、或 API 查询。SKILL.md 里用 `<install_dir>` 这类占位符，而不是写死 `/opt/1panel`。

2. **优先 API，不改生成物**
   如果目标系统提供 API，一律走 API。直接改它生成的配置文件会导致「面板显示与实际运行不一致」。

3. **写明能力边界**
   明确标注哪些操作 API 支持、哪些只能人工做（比如需要会话登录的管理操作），避免 Agent 反复试错。

4. **坑要写实测结论**
   「接口 X 需要参数 Y，缺了报 400」比「注意参数」有用得多。

5. **危险操作要护栏**
   删除、停机、覆盖类操作必须在文档里声明「先向用户确认」。

第三方技能按上游原样收录，不适用上述可移植性改造；其质量与维护状态由上游负责。许可明确的来源见 [`third-party/SOURCES.md`](third-party/SOURCES.md)；来源/许可未确认的 14 个技能见 [`third-party/UNVERIFIED.md`](third-party/UNVERIFIED.md)（公开分发前请评估版权风险）。

---

## English

### What is this

A collection of self-contained AI agent skills following the `SKILL.md` convention. Drop a subdirectory into your agent's skills folder and it works — no dependency on the rest of this repo.

The repository currently contains **141 skills**: 1 first-party (`1panel-ops`), 126 licensed third-party skills from 15 upstream projects, and 14 skills whose upstream/license could not be confirmed (included at the owner's request; see [`third-party/UNVERIFIED.md`](third-party/UNVERIFIED.md) for the copyright-risk note). Provenance, pinned versions and licenses for the licensed set are in [`third-party/SOURCES.md`](third-party/SOURCES.md); full license texts are in [`third-party/licenses/`](third-party/licenses/). Skills intentionally left out are listed in [`third-party/EXCLUDED.md`](third-party/EXCLUDED.md).

It also contains [`zcode/global-instruction/`](zcode/global-instruction/) — a **portable** ZCode global-policy package (`AGENTS.md`, `SEDS.md`, `templates/`, `guides/`, `validate.sh`) intended for copying to other machines; `archive/` keeps raw machine-specific snapshots and is not portable. It is **not** an installable skill and contains no secrets.

It also contains [`claude-code/global-instruction/`](claude-code/global-instruction/) — a **portable** Claude Code global-policy package (`CLAUDE.md`, `SEDS.md`, `templates/`, `guides`, `validate.sh`), symmetric to the ZCode package (same policy core, discovery rules and templates adapted to Claude Code mechanics); `archive/` keeps the pre-rewrite machine snapshot and is not portable. Not an installable skill; no secrets.

See [`zcode/prompt-design.md`](zcode/prompt-design.md) for the ZCode prompt architecture: built-in prompts, instruction-file discovery, memory, skills, MCP, hooks, plugins, subagents and compaction, plus a harness mapping and instruction-placement matrix.

See [`claude-code/prompt-design.md`](claude-code/prompt-design.md) for the Claude Code 2.1.322 prompt architecture: request layers, built-in prompts, CLAUDE.md/AGENTS.md/rules discovery, auto memory, skills, MCP, hooks, plugins, subagents, compaction and caching, with a machine snapshot and reproduction commands.

Design goals (first-party skills):

- **Portable** — no hardcoded IPs, domains, ports, or paths. Environment-specific values come from detection scripts or config files.
- **Evidence-based** — scripts and docs embed findings verified against real deployments: which endpoints exist, which parameters are mandatory, which approaches break.
- **Safe by default** — destructive operations (delete, stop, overwrite) are explicitly gated behind user confirmation.

### Skills

| Group | Count | Source / notes |
|---|---:|---|
| Go | 46 | `samber/cc-skills-golang` (MIT) |
| Spring Boot 4 | 33 | `rrezartprebreza/spring-boot-skills` (MIT) |
| Java architecture & engineering | 18 | `decebals/claude-code-java` (MIT) |
| Node / TypeScript / Vue | 7 | `antfu/skills` (5) + `mcollina/skills` (2), MIT |
| Design / frontend | 9 | `ui-ux-pro-max-skill`, `anydesign`, `taste-skill`, `anthropics/skills` frontend-design, `type-styles-and-radius`, `hallmark`, `image-manipulation-image-magick`, `web-design-guidelines` |
| Engineering workflow | 16 | Derived from `obra/superpowers` (MIT) + `code-review-skill`, `code-reviewer`, `software-architecture-design`, `writing-clearly-and-concisely` |
| Rust | 5 | `leonardomso/rust-skills` (MIT) + `m01-ownership`, `m06-error-handling`, `rust-best-practices`, `rust-router` |
| Tools & ops | 5 | `1panel-ops`, `ruff`, `open-code-review`, `agent-reach`, `find-skills` |
| Python | 1 | `modern-python` |
| Documents / office | 1 | `officecli` |
| **Total** | **141** | |

See the Chinese section above for the full per-category index.

### Quick start

```bash
git clone https://github.com/viccom/viccom-agent-skills.git
cd viccom-agent-skills

# Install one skill
ln -sfn "$PWD/skills/1panel-ops" ~/.reasonix/skills/1panel-ops

# Install all (symlink; updates with git pull)
SKILLS_DIR=~/.zcode/skills   # or ~/.claude/skills, ~/.reasonix/skills
for d in skills/*/; do
  name=$(basename "$d")
  ln -sfn "$PWD/$d" "$SKILLS_DIR/$name"
done
```

> Warning: the loop overwrites same-named skills in the target directory, including local edits. Check for name conflicts first, or link only the skills you need.

For `1panel-ops`, run detection once after installing:

```bash
python3 ~/.reasonix/skills/1panel-ops/scripts/p1detect.py
```

It reports: where 1Panel is installed, the API port, openresty listen ports, existing certs and sites, and whether an API key is already present.

### Skill layout

```
skills/<skill-name>/
├── SKILL.md            # required; frontmatter carries name / description
├── references/         # optional; detailed docs, API contracts, field tables
└── scripts/            # optional; directly executable helpers
```

### Conventions

First-party skills follow these conventions:

1. **Detect, don't assume** — every machine-dependent value needs a lookup path. Use placeholders like `<install_dir>`, never a literal `/opt/1panel`.
2. **API over generated files** — if the target system exposes an API, use it. Editing files it generates desynchronizes the panel from reality.
3. **State the boundaries** — mark what the API supports and what requires human action (e.g. session-authenticated admin calls).
4. **Record verified pitfalls** — "endpoint X requires parameter Y, returns 400 otherwise" beats "mind the parameters".
5. **Guard destructive operations** — delete/stop/overwrite must require user confirmation.

Vendored third-party skills are kept as-is; upstream owns their content and maintenance.

---

## 许可 / License

本仓库自有内容采用 MIT。126 个第三方技能保留各自上游许可，详见 [`third-party/SOURCES.md`](third-party/SOURCES.md) 与 [`third-party/licenses/`](third-party/licenses/)。另有 14 个来源/许可未确认技能，见 [`third-party/UNVERIFIED.md`](third-party/UNVERIFIED.md)。

The repository's own content is MIT-licensed. The 126 licensed third-party skills retain their upstream licenses; see [`third-party/SOURCES.md`](third-party/SOURCES.md) and [`third-party/licenses/`](third-party/licenses/). The 14 unverified skills are documented in [`third-party/UNVERIFIED.md`](third-party/UNVERIFIED.md).
