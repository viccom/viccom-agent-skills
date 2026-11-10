# 来源/许可未确认的技能（19 个）

这 19 个技能**没有可确认的上游来源或明确许可**，是按仓库所有者的明确要求收录的（14 个于 2026-11-10，另 5 个 claude-office-skills 系于 2026-11-11 自本机 `~/.agents/skills` 散置目录收编并经所有者再次授权）。它们不享受 `third-party/SOURCES.md` 中的许可声明，**公开分发前请自行评估版权风险**。

| 技能 | 已知线索 | 质量备注 |
|---|---|---|
| `code-review-skill` | 无 | 232 行 + 42 个参考文件，内容完整 |
| `code-reviewer` | 无 | 130 行；与 `code-review-skill`、`open-code-review` 功能重叠 |
| `excel-automation` | frontmatter 自称 claude-office-skills（MIT），上游 URL 未记录 | xlwings 操作手册；需 Python 包 `xlwings`（Linux 上还依赖 LibreOffice），本机未装 |
| `find-skills` | 正文提到 `vercel-labs/agent-skills`、`ComposioHQ/awesome-claude-skills` | 134 行；用于发现/安装其他技能 |
| `hallmark` | 无 | 559 行 + 112 个文件；引用 `../../site/css/tokens.css`、`../../docs/recipes.md`、`../../docs/study-examples.md` 三个缺失文件 |
| `html-slides` | 同 `excel-automation`（claude-office-skills / MIT，URL 未记录） | frontmatter `description: ">"` 畸形（技能清单因此不显示描述）；HTML 演示文稿生成手册 |
| `image-manipulation-image-magick` | 无 | 253 行；ImageMagick 操作手册 |
| `m01-ownership` | 疑似 actionbook/rust-skills（该仓库未声明 license） | 135 行 + 7 个文件 |
| `m06-error-handling` | 同上 | 167 行 + 5 个文件 |
| `modern-python` | 正文基于 trailofbits/cookiecutter-python（Apache-2.0），但副本未附许可 | 334 行 + 18 个文件 |
| `officecli` | 无 | 418 行；OfficeCLI 使用手册 |
| `pdf` | frontmatter 无 author/license 字段 | 依赖 `reportlab`/`pdfplumber`/`pypdf`（本机未装）；与 zcode 官方插件技能 `pdf:pdf` 同名易混 |
| `pdf-extraction` | 同 `excel-automation`（claude-office-skills / MIT，URL 未记录） | 仅 SKILL.md 单文件；依赖 `pdfplumber`/`Pillow`（本机未装） |
| `ppt-visual` | 同 `excel-automation`（claude-office-skills / MIT，URL 未记录） | 设计建议类手册，无外部工具依赖 |
| `rust-best-practices` | 无 | 95 行 + 11 个文件 |
| `rust-router` | 无 | 241 行；引用 m01–m15 技能族，本仓库仅含 m01/m06 |
| `software-architecture-design` | 无 | 167 行 + 20 个文件；引用 13 个未随附的兄弟技能（`software-backend`、`dev-api-design` 等） |
| `web-design-guidelines` | 上游 vercel-labs/agent-skills 无 LICENSE | 40 行；运行时从 GitHub 拉取最新规则，需要网络 |
| `writing-clearly-and-concisely` | 无 | 63 行 + `elements-of-style.md`（约 12k tokens） |

## 维护约定

- 这 19 个技能保持原样，不做内容改写；`hallmark` 与 `software-architecture-design` 的悬空引用、`html-slides` 的畸形 description 属已知问题。
- 若将来找到明确上游与许可，请把它们移入 `third-party/SOURCES.md` 并补充 LICENSE。
- 新增来源/许可不明的技能需仓库所有者再次明确授权。
