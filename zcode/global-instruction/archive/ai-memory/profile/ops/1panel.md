---
tags:
- 1panel
- ops
- warden
- supervisor
tier: semantic
type: Note
generated:
  by: process:ai-memory/3.4.2
  at: 2026-11-09T04:14:30Z
---
# 本机运维入口：1Panel

网站发布/反代、SSL 证书申请、计划任务一律走 1Panel（skill：`1panel-ops`）；Agent 进程守护用各自 warden，1Panel 的 supervisor 仅系统级场景用。

- 不要手改 `/opt/1panel/www/` 下的 openresty 生成物——面板看不到也管不了，走 API 面板会自动 nginx -t + reload。
- 入口脚本：`~/.agents/skill-srcs/1panel-ops/scripts/p1api.py`；凭据 `~/.config/1panel/api_key`（0600，仅限 127.0.0.1）；API 基址 `http://127.0.0.1:55055`。
- 证书走 DNS-01（腾讯云 DNSPod 账号 id=1）；HTTP-01 因域名解析内网 IP 不可用。
- Agent 工作路径下的常驻进程由各 Agent 独立的 warden 托管，不要顺手塞进 1Panel 的 supervisord。
- 契约与 13 条实测坑见 skill 内 SKILL.md 与 references/api.md。
