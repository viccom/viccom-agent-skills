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
└── skills/
    └── <skill-name>/   # 每个子目录 = 一个独立可分发的技能
        ├── SKILL.md
        ├── references/
        └── scripts/
```

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
4. **更新 `README.md`** 的技能列表表格。
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

**检查方法**：

```bash
grep -rnE '([0-9]{1,3}\.){3}[0-9]{1,3}|[a-z0-9-]+\.(com|top|cn|net|org)' \
  skills/*/SKILL.md skills/*/references/ 2>/dev/null | grep -v example
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
# 1. 语法检查
python3 -m py_compile skills/*/scripts/*.py && echo "py_compile OK"

# 2. 执行位
find skills/*/scripts -name '*.py' ! -perm -u+x -print

# 3. 本机标识残留（应无输出）
grep -rnE '([0-9]{1,3}\.){3}[0-9]{1,3}|\.(com|top|cn|net|org)\b' \
  skills/*/SKILL.md skills/*/references/ | grep -vE 'example\.(com|test)'

# 4. frontmatter 完整
head -n 5 skills/*/SKILL.md | grep -E '^(---|name:|description:)'

# 5. 清理构建产物
find . -name '__pycache__' -o -name '*.pyc'
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
- **Never hardcode** machine-specific values (IPs, domains, ports, install paths). Use placeholders resolved by detection scripts.
- **Prefer APIs over generated files.** Document which files are generated and must not be hand-edited.
- Mark capability boundaries: what the API supports, what needs human action.
- Destructive operations require explicit user confirmation in the skill docs.
- Scripts: stdlib-only Python 3.8+, executable bit set, read-only detection separate from write operations, credentials at `0600`.
- Run the self-check block before committing. Never commit `__pycache__` or credentials.
