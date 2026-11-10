---
kind: rule
abstract: warden 分实例：主例 8789 存量不动；路径例 warden-<后缀> 配置 <路径>/warden/、独立 token、端口按路径 AGENTS.md。
entities:
- warden
- systemd
- port-allocation
tags:
- warden
- ops
- machine
tier: procedural
type: Note
generated:
  by: process:ai-memory/3.4.2
  at: 2026-11-09T09:11:16Z
---
# warden 进程守护：按工作路径分实例（本机方案）

- **方案**：主实例 `warden.service`（systemd --user，`127.0.0.1:8789`，配置 `~/.config/warden/services.toml`）托管账户级基础设施与 dongit/safe-bot 存量服务，**存量不迁移**；各工作路径的编译产物/联调服务用独立实例 `warden-<后缀>`，API 端口自 8791 起顺排（分配前 `ss -ltn` 查重；8790 已被 safebot-agentd 占用勿复用）。
- **专属实例布局**：配置 `<路径>/warden/config/services.toml`（data/、logs/ 同目录锚点落盘；服务注册用绝对路径，相对锚点=warden/ 目录）；二进制统一复用 `~/.local/bin/warden` 保版本一致（测试新构建才临时指新路径）；每实例独立 `auth_token`（`openssl rand -hex 24`，配置 chmod 600，只绑 127.0.0.1）；systemd user 单元 enable（本机 Linger=yes，跨会话常驻）。
- **业务端口**：各路径在自己名下划定连续空闲大块，记录于该路径 AGENTS.md「端口分配」节（例：iot-git = 20000–20099，rs-iot 用 20000/20001/20002）。被托管程序的配置也放路径 `warden/config/` 做覆盖，不改仓库自身默认配置。
- **操作纪律**（手册 `~/dongit/warden/docs/AGENT-GUIDE.md` §8）：start 非幂等（运行中 409 → 用 restart）；daemon 运行时勿手编 services.toml（走 API 写回，或先 stop 单元再改）；配置加载失败退出码仍为 0（判输出文本不判码）；401 body 是纯文本。
- **已部署示例**：`~/iot-git` → `warden-iot.service` @ `127.0.0.1:8791`，操作指南 `~/iot-git/docs/warden-guide.md`。