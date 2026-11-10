# 第三方技能来源与许可

本文件记录 **126 个许可明确的第三方技能**。收录方式为**原样拷贝**（`ruff` 仅调整 frontmatter 以适配 ZCode；`type-styles-and-radius` 为 MIT 改编；`obra/superpowers` 系为本地旧版/变体），未对正文做改写。

另有 **14 个来源/许可未确认**的技能，按仓库所有者要求收录，单独记录在 [`UNVERIFIED.md`](UNVERIFIED.md)，不计入下表。

完整许可文本见 [`third-party/licenses/`](licenses/)。新增或更新第三方技能时，请同步更新本文件与许可文件。

| 分组 | 来源 | 版本固定 | 许可 | 数量 |
|---|---|---|---|---:|
| Go 工程 | [samber/cc-skills-golang](https://github.com/samber/cc-skills-golang) | d68d80aec298（2026-11-10 上游 HEAD；各技能 metadata.version 1.2.x） | MIT | 46 |
| Spring Boot 4 | [rrezartprebreza/spring-boot-skills](https://github.com/rrezartprebreza/spring-boot-skills) | f0c06a0 | MIT | 33 |
| Java 架构与工程实践 | [decebals/claude-code-java](https://github.com/decebals/claude-code-java) | 0d98fe9 | MIT | 18 |
| Node / TypeScript / Vue | [antfu/skills](https://github.com/antfu/skills) | 7de210b | MIT | 5 |
| Node / TypeScript / Vue（续） | [mcollina/skills](https://github.com/mcollina/skills) | 856efd2 | MIT | 2 |
| 设计 / 前端 | [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) | 3a13158 | MIT | 2 |
| 设计 / 前端（续） | [uxKero/anydesign](https://github.com/uxKero/anydesign) | d81bd89 | MIT | 1 |
| 设计 / 前端（续） | [Leonxlnx/taste-skill](https://github.com/Leonxlnx/taste-skill) | 12af471 | MIT | 1 |
| 设计 / 前端（续） | [anthropics/skills — frontend-design](https://github.com/anthropics/skills) | dbd4588 | Apache-2.0 | 1 |
| 设计 / 前端（续） | [elayadesign/ai-design-skills（本地 MIT 改编）](https://github.com/elayadesign/ai-design-skills) | 456d9e0d3e2d（上游 HEAD；本地为改编版，非逐字一致） | MIT | 1 |
| 研发流程 | [obra/superpowers（派生）](https://github.com/obra/superpowers) | 22f0b46（2026-11-03 上游 HEAD；本地副本为旧版/变体，非逐字一致） | MIT | 12 |
| Rust | [leonardomso/rust-skills](https://github.com/leonardomso/rust-skills) | fd2a861 | MIT | 1 |
| 工具 | [astral-sh/claude-code-plugins — ruff](https://github.com/astral-sh/claude-code-plugins) | f3ce88a（本地仅调整 ruff frontmatter 以适配 ZCode） | MIT OR Apache-2.0 | 1 |
| 工具（续） | [Panniantong/Agent-Reach](https://github.com/Panniantong/Agent-Reach) | c70ae6da5d39（上游 HEAD） | MIT | 1 |
| 工具（续） | [alibaba/open-code-review](https://github.com/alibaba/open-code-review) | f15c6dbb575d（上游 HEAD） | Apache-2.0 | 1 |

合计：**126** 个许可明确的第三方技能；另有 14 个来源/许可未确认技能见 [`UNVERIFIED.md`](UNVERIFIED.md)。

## Go 工程

- 上游：https://github.com/samber/cc-skills-golang
- 版本/固定：d68d80aec298（2026-11-10 上游 HEAD；各技能 metadata.version 1.2.x）
- 许可：MIT — `third-party/licenses/samber-cc-skills-golang-LICENSE`
- 技能（46）：`golang-stay-updated`、`golang-dependency-injection`、`golang-dependency-management`、`golang-code-style`、`golang-samber-do`、`golang-samber-hot`、`golang-samber-lo`、`golang-design-patterns`、`golang-project-layout`、`golang-how-to`、`golang-gopls`、`golang-troubleshooting`、`golang-pkg-go-dev`、`golang-benchmark`、`golang-refactoring`、`golang-continuous-integration`、`golang-popular-libraries`、`golang-spf13-cobra`、`golang-spf13-viper`、`golang-naming`、`golang-swagger`、`golang-samber-slog`、`golang-stretchr-testify`、`golang-grpc`、`golang-observability`、`golang-documentation`、`golang-structs-interfaces`、`golang-samber-mo`、`golang-uber-fx`、`golang-lint`、`golang-error-handling`、`golang-data-structures`、`golang-samber-ro`、`golang-context`、`golang-concurrency`、`golang-safety`、`golang-uber-dig`、`golang-performance`、`golang-google-wire`、`golang-security`、`golang-graphql`、`golang-testing`、`golang-cli`、`golang-modernize`、`golang-samber-oops`、`golang-database`

## Spring Boot 4

- 上游：https://github.com/rrezartprebreza/spring-boot-skills
- 版本/固定：f0c06a0
- 许可：MIT — `third-party/licenses/spring-boot-skills-LICENSE`
- 技能（33）：`ai-observability`、`api-versioning`、`configuration-properties`、`container-native-deployment`、`domain-driven-design`、`event-driven-messaging`、`flyway-migrations`、`hateoas`、`hexagonal-architecture`、`http-interface-clients`、`idempotency-patterns`、`layered-architecture`、`mcp-server`、`multi-module-maven`、`multi-tenancy`、`null-safety`、`oauth2-resource-server`、`openapi-first`、`problem-details-rfc9457`、`production-observability`、`resilience-retry`、`rest-api-conventions`、`spring-ai-integration`、`spring-batch`、`spring-boot-migration`、`spring-cloud-gateway`、`spring-data-jpa`、`spring-data-redis`、`spring-modulith`、`spring-security-jwt`、`testing-pyramid`、`transactional-patterns`、`webflux-reactive-patterns`

## Java 架构与工程实践

- 上游：https://github.com/decebals/claude-code-java
- 版本/固定：0d98fe9
- 许可：MIT — `third-party/licenses/claude-code-java-LICENSE`
- 技能（18）：`api-contract-review`、`architecture-review`、`changelog-generator`、`clean-code`、`concurrency-review`、`design-patterns`、`git-commit`、`issue-triage`、`java-code-review`、`java-migration`、`jpa-patterns`、`logging-patterns`、`maven-dependency-audit`、`performance-smell-detection`、`security-audit`、`solid-principles`、`spring-boot-patterns`、`test-quality`

## Node / TypeScript / Vue

- 上游：https://github.com/antfu/skills
- 版本/固定：7de210b
- 许可：MIT — `third-party/licenses/antfu-skills-LICENSE`
- 技能（5）：`pinia`、`unocss`、`vite`、`vitest`、`vue`

## Node / TypeScript / Vue（续）

- 上游：https://github.com/mcollina/skills
- 版本/固定：856efd2
- 许可：MIT — `third-party/licenses/mcollina-skills-LICENSE`
- 技能（2）：`node`、`typescript-magician`

## 设计 / 前端

- 上游：https://github.com/nextlevelbuilder/ui-ux-pro-max-skill
- 版本/固定：3a13158
- 许可：MIT — `third-party/licenses/ui-ux-pro-max-skill-LICENSE`
- 技能（2）：`design-system`、`ui-ux-pro-max`

## 设计 / 前端（续）

- 上游：https://github.com/uxKero/anydesign
- 版本/固定：d81bd89
- 许可：MIT — `third-party/licenses/anydesign-LICENSE`
- 技能（1）：`anydesign`

## 设计 / 前端（续）

- 上游：https://github.com/Leonxlnx/taste-skill
- 版本/固定：12af471
- 许可：MIT — `third-party/licenses/taste-skill-LICENSE`
- 技能（1）：`design-taste-frontend`

## 设计 / 前端（续）

- 上游：https://github.com/anthropics/skills
- 版本/固定：dbd4588
- 许可：Apache-2.0 — `third-party/licenses/anthropic-skills-frontend-design-LICENSE.txt`
- 技能（1）：`frontend-design`

## 设计 / 前端（续）

- 上游：https://github.com/elayadesign/ai-design-skills
- 版本/固定：456d9e0d3e2d（上游 HEAD；本地为改编版，非逐字一致）
- 许可：MIT — `third-party/licenses/elayadesign-ai-design-skills-LICENSE`
- 技能（1）：`type-styles-and-radius`

## 研发流程

- 上游：https://github.com/obra/superpowers
- 版本/固定：22f0b46（2026-11-03 上游 HEAD；本地副本为旧版/变体，非逐字一致）
- 许可：MIT — `third-party/licenses/obra-superpowers-LICENSE`
- 技能（12）：`brainstorming`、`dispatching-parallel-agents`、`executing-plans`、`finishing-a-development-branch`、`receiving-code-review`、`requesting-code-review`、`subagent-driven-development`、`systematic-debugging`、`test-driven-development`、`using-git-worktrees`、`verification-before-completion`、`writing-plans`

## Rust

- 上游：https://github.com/leonardomso/rust-skills
- 版本/固定：fd2a861
- 许可：MIT — `third-party/licenses/leonardomso-rust-skills-LICENSE`
- 技能（1）：`rust-skills`

## 工具

- 上游：https://github.com/astral-sh/claude-code-plugins
- 版本/固定：f3ce88a（本地仅调整 ruff frontmatter 以适配 ZCode）
- 许可：MIT OR Apache-2.0 — `third-party/licenses/astral-claude-code-plugins-LICENSE-MIT / -LICENSE-APACHE`
- 技能（1）：`ruff`

## 工具（续）

- 上游：https://github.com/Panniantong/Agent-Reach
- 版本/固定：c70ae6da5d39（上游 HEAD）
- 许可：MIT — `third-party/licenses/Agent-Reach-LICENSE`
- 技能（1）：`agent-reach`

## 工具（续）

- 上游：https://github.com/alibaba/open-code-review
- 版本/固定：f15c6dbb575d（上游 HEAD）
- 许可：Apache-2.0 — `third-party/licenses/alibaba-open-code-review-LICENSE`
- 技能（1）：`open-code-review`
