# Skill 编写规范

> 适用范围：宿主技能目录下（Codex 为 `$CODEX_HOME/skills/` 或 `~/.agents/skills/`，其他宿主用各自技能目录）**新建或大改**的 skill；存量 skill 不强制迁移。
> 与 `AGENTS.md` 冲突时以 `AGENTS.md` 为准；本文件只管“怎么写 skill”，不重复全局行为约束。

## 1. 目录与命名

- 位置：`skills/<kebab-case>/SKILL.md`；`name` 必须等于目录名。
- 目录名只用小写字母、数字、连字符；不用空格、下划线、大写。
- 一个 skill 一个内聚能力；不要为“以后可能用”建空目录。

## 2. Frontmatter

最小必需：

```yaml
---
name: my-skill
description: What it does. Use when ...
---
```

- `description`：第三人称；写“做什么”+ 至少一个正向触发（`Use when ...`）；不写负向（负向放正文 `When NOT to use`）；≤1024 字符。
- 可选字段按宿主支持：`license`、`compatibility`、`metadata`、`user-invocable`。
- 宿主/vendor 专属字段放 `metadata`，不要新增顶层键；顶层键以宿主实际支持为准。
- 不写 `version`：版本由安装源/仓库管理，skill 内容变更用提交记录表达。
- 不写机器路径、端口、token、个人凭据；机器事实放 `machine-profile.md`（与 `AGENTS.md` 同目录，每台机器各自一份）。

## 3. 章节模板（推荐）

```markdown
## Overview
## When to Use        （含 When NOT to use）
## Process            （步骤编号，每步有退出条件）
## Common Rationalizations  （借口 | 现实）
## Red Flags          （可观察的失败信号）
## Verification       （- [ ] 证据清单）
```

- 元 skill（路由/索引类）可豁免 `When to Use` / `Verification`，但要在开头说明它是元 skill。
- 步骤里写了 `Step N` 就要有对应小节；不要只列口号。
- 新建 skill 至少含 `Overview` / `When to Use` / `Process` / `Verification`；`Common Rationalizations` 推荐引用 `guides/anti-rationalizations.md`（本包内），不复制全文。

## 4. 篇幅与渐进披露

- `SKILL.md` ≤500 行；超过时把细节外移到同目录 `references/`，主文件保留入口与决策路径。
- 参考资料只放一层：`skills/<name>/references/*.md`；跨 skill 共享的内容放本包 `guides/`，用绝对路径引用。
- 不跨 skill 目录互相引用；需要共享就上移，不要复制。
- Codex 技能目录只占上下文约 2%、上限 10k tokens；不要一次软链整个 `skills/` 仓库。

## 5. 内容原则

- **写流程，不写 workaround**：不把“某个模型/CLI 版本的临时绕过”写成 skill 正文；版本事实写 `compatibility`/`metadata`，或开 issue。
- **写能力，不写机制**：写“跑聚焦测试”，不写死某个工具的内部命令；工具选择留给项目约定。
- **可验证**：每条规则尽量有可观察的完成信号（命令、文件、输出），不写“要注意质量”这类空话。
- **最小**：只写引导 Agent 必需的内容；不写百科、不写与任务无关的背景。
- **安全边界**：skill 不得要求绕过 `AGENTS.md` 的安全/授权/不谎报条款；示例中不出现真实密钥、内部地址、个人数据。

## 6. 验证

新建/大改后至少检查：

- [ ] `name` 与目录名一致，`description` 含正向触发。
- [ ] 必备章节存在，步骤编号与小节对应。
- [ ] 所有相对链接可解析（`references/` 文件存在）。
- [ ] 行数 ≤500；超出部分已外移。
- [ ] 无密钥、无机器路径、无 vendor 顶层字段。
- [ ] 如改了路由相关描述，检查是否与现有 skill 的触发语高度重叠（避免抢触发）。

当前 `validate.sh` 不检查 skills；以上为人工检查清单，后续可加 lint 脚本。
