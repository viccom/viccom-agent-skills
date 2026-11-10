# viccom-agent-skills

> 一套可移植的 AI Agent 技能集合，适用于 Reasonix、Claude Code 等支持 `SKILL.md` 约定的 Agent。
> A collection of portable AI agent skills following the `SKILL.md` convention.

---

## 中文

### 这是什么

本仓库收集可直接扔进 Agent 技能目录使用的技能包。每个技能都是**自包含**的：把对应子目录拷走就能用，不依赖仓库里的其它内容。

设计目标：

- **可移植** —— 不写死某台机器的 IP、域名、端口、路径。环境相关的参数由探测脚本或配置文件提供。
- **可验证** —— 脚本里嵌入了真实环境的实测结论（哪些接口必须、哪些参数必填、哪些做法会踩坑）。
- **安全默认** —— 危险操作（删除、停机、覆盖）在 SKILL.md 里明确要求先向用户确认。

### 技能列表

| 技能 | 说明 | 依赖 |
|---|---|---|
| [`1panel-ops`](skills/1panel-ops/) | 1Panel v2 面板运维：建站/反向代理、SSL 证书、计划任务、进程守护、容器、数据库、文件、应用商店 | Python 3.8+、1Panel v2 |

### 快速开始

```bash
git clone https://github.com/viccom/viccom-agent-skills.git
cd viccom-agent-skills

# Reasonix（全局技能目录）
cp -r skills/1panel-ops ~/.reasonix/skills/

# Claude Code（用户级技能目录）
cp -r skills/1panel-ops ~/.claude/skills/
```

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

本仓库的技能遵循以下约定，你在写新技能时可以参考：

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

---

## English

### What is this

A collection of self-contained AI agent skills following the `SKILL.md` convention. Drop a subdirectory into your agent's skills folder and it works — no dependency on the rest of this repo.

Design goals:

- **Portable** — no hardcoded IPs, domains, ports, or paths. Environment-specific values come from detection scripts or config files.
- **Evidence-based** — scripts and docs embed findings verified against real deployments: which endpoints exist, which parameters are mandatory, which approaches break.
- **Safe by default** — destructive operations (delete, stop, overwrite) are explicitly gated behind user confirmation.

### Skills

| Skill | Description | Requires |
|---|---|---|
| [`1panel-ops`](skills/1panel-ops/) | 1Panel v2 panel ops: websites/reverse proxy, SSL certs, cron jobs, supervisor, containers, databases, files, app store | Python 3.8+, 1Panel v2 |

### Quick start

```bash
git clone https://github.com/viccom/viccom-agent-skills.git
cd viccom-agent-skills

# Reasonix (global skills dir)
cp -r skills/1panel-ops ~/.reasonix/skills/

# Claude Code (user-level skills dir)
cp -r skills/1panel-ops ~/.claude/skills/
```

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

1. **Detect, don't assume** — every machine-dependent value needs a lookup path. Use placeholders like `<install_dir>`, never a literal `/opt/1panel`.
2. **API over generated files** — if the target system exposes an API, use it. Editing files it generates desynchronizes the panel from reality.
3. **State the boundaries** — mark what the API supports and what requires human action (e.g. session-authenticated admin calls).
4. **Record verified pitfalls** — "endpoint X requires parameter Y, returns 400 otherwise" beats "mind the parameters".
5. **Guard destructive operations** — delete/stop/overwrite must require user confirmation.

---

## 许可 / License

MIT
