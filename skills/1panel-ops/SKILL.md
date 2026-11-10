---
name: 1panel-ops
description: 操作 1Panel v2 面板时使用——建站/反向代理、SSL 证书申请与管理、计划任务、进程守护(supervisor)、容器与镜像、数据库、文件、进程、应用商店、备份、监控，以及读写 1Panel 自身的 MCP 配置。通过 1Panel REST API + API Key 签名调用，部署参数自动探测。当用户提到「1Panel」「面板」「反向代理建站」「openresty 站点」「SSL 证书」「计划任务」「定时任务」「进程守护」「supervisor」「应用商店」「MCP 面板配置」时使用。
---

# 1Panel v2 运维（REST API）

**可移植版**：适用于任何安装 1Panel v2 的 Linux 主机。本机参数不写死，由
`scripts/p1detect.py` 探测，或通过环境变量/profile 覆盖。

## 何时用这个 skill

任何要通过 **1Panel 面板**完成的动作。不要直接改 `<install_dir>/www/conf.d/` 或
`<install_dir>/www/sites/` 下的文件——那些是 1Panel 的**生成物**，手改后：
- 面板界面看不到、也管不了（网站列表完全来自数据库 `websites` 表）
- 面板下次改同 alias 的站点会覆盖你的手改
- 删除站点时不会清理你的手改，可能留下悬空 vhost

**唯一正确姿势：走 API。** 面板会自己生成 vhost、跑 `nginx -t`、`nginx -s reload`，
失败自动回滚。

> 例外：确需 1Panel 不提供的裸 nginx 指令（如某些 SSE 参数），用
> `POST /api/v2/websites/proxies/file` 覆写 `proxy/root.conf`——**仍然走 API**，
> 这样 1Panel 依然认得这个站点。

## 第一步：探测本机参数

**每次在新主机上使用前，先跑一次探测：**

```bash
python3 <skill_dir>/scripts/p1detect.py            # 只打印，不落盘
python3 <skill_dir>/scripts/p1detect.py --write    # 写入 ~/.config/1panel/profile.json
```

输出示例（字段含义见下）：

```json
{
  "schema": 1,
  "install_dir": "/opt/1panel",
  "api": { "base": "http://127.0.0.1:5000", "port": 5000,
           "entrance": "1panel", "admin": "admin" },
  "openresty": { "http": 80, "https": 443 },
  "certs": [ { "id": 5, "domain": "*.example.com", "provider": "dnsAccount",
               "status": "ready", "expire": "2027-02-07 14:18:25+00:00" } ],
  "websites": [ { "id": 14, "alias": "aa.example.com",
                  "proxy": "http://127.0.0.1:8080", "status": "Running",
                  "sslId": 5, "domains": "aa.example.com:80,*.example.com:80" } ],
  "credential": { "api_key": true, "api_key_id": true, "profile": true },
  "ready": true,
  "notes": []
}
```

探测能力与局限：

| 字段 | 来源 | 探测失败时 |
|---|---|---|
| `install_dir` | 依次尝试 `/opt/1panel`、`/usr/local/1panel`、`/usr/share/1panel` | 需手工指定 |
| `api.port` | `ss -tlnp` 找 `1panel-core`；退化到 `core.db` 的 `ServerPort`；再退化 `9999` | 手工设 `P1_URL` |
| `api.entrance` | `core.db` 的 `SecurityEntrance` | 空（仅影响 Web 路径） |
| `api.admin` | `core.db` 的 `UserName` | 空 |
| `openresty.http/https` | `agent.db` 的 `app_installs`（**vhost listen 的真实依据**） | `null` |
| `certs` / `websites` | `agent.db`（只读，不含私钥） | `[]` |
| `credential` | 检查 `~/.config/1panel/{api_key,api_key_id}` 是否存在 | `false` |

> 探测**只读**，不改任何系统状态。数据库用 `mode=ro` 打开，不会触发 WAL 写回。

## 配置解析顺序

`p1api.py` 按以下优先级取值（高的覆盖低的）：

| 优先级 | 来源 | 用途 |
|---|---|---|
| 1 | 环境变量 `P1_URL` / `P1_SECRET` / `P1_KEY_ID` | 临时覆盖 / CI |
| 2 | `~/.config/1panel/profile.json` | `api.base` |
| 3 | `~/.config/1panel/api_key`、`api_key_id` | 凭据 |
| 4 | 自动探测（`ss` 找 1panel-core 端口） | `api.base` 兜底 |
| 5 | 内置默认 `http://127.0.0.1:9999` | 最后兜底 |

`profile.json` 的 `api.base` **只是默认值来源**，随时可用 `P1_URL` 覆盖。

## 首次配置（Agent 可自动完成的部分）

```
1. 跑 p1detect.py                          → 得到 install_dir / port / openresty 端口
2. 若 ready=false，缺 API Key：
   a. 告知用户需要人工在面板 UI 创建（无法绕过，见下）
   b. 用户给出明文后，Agent 写入：
        ~/.config/1panel/api_key      (0600)
        ~/.config/1panel/api_key_id   (0600, UUID)
   c. 跑 p1detect.py --write 刷新 profile
3. 跑一条只读接口自检：p1api.py GET /api/v2/websites/list
```

**API Key 为什么必须人工创建**：1Panel 的 `POST /api/v2/core/auth/api/keys/create`
需要**会话登录**（admin 密码 + 可能的验证码/MFA），而 `core/*` 路由**不接受 API Key**。
明文只在创建那一刻返回一次；`secret_ciphertext` 用面板 `EncryptKey` 加密，**无法离线反解**；
`reveal` 接口同样要 session。Key 丢了只能删掉重建。

创建要点（供指导用户时使用）：
- 面板 → 设置 → **API 接口** → 开启
- 创建独立 Key，**IP 白名单必须填**（如 `127.0.0.1`；留空会被 `IsIPInWhiteList` 拒绝）
- Key 的 `status` 必须为 `Enable`

## 认证

用**独立 API Key**（不是登录 session）。session 路径会被验证码/MFA/密码过期/CSRF 挡住；
API Key 路径跳过这些。

**签名头**（每次请求都要重新签，时间戳有效窗口 ±60 秒）：

```
1Panel-Token: hex(HMAC-SHA256(key, "1panel:" + ts))
1Panel-Timestamp: <unix 秒>
1Panel-Signature-Version: hmac-sha256
1Panel-Key-ID: <独立 Key 的 UUID，可选>
```

旧算法 `md5("1panel" + key + ts)` 也被接受（`1Panel-Signature-Version: md5` 或 `v1`），
但用 hmac-sha256。

**凭据文件**：`~/.config/1panel/api_key`（明文，0600）与 `api_key_id`（UUID）。
`ip_white_list` 限定来源 IP——默认 `127.0.0.1` 表示**只能从本机调**，跨机调用需改白名单。

**调用方式**：

```bash
P=~/.reasonix/skills/1panel-ops/scripts/p1api.py
$P GET  /api/v2/websites/list
$P POST /api/v2/websites/search \
  '{"page":1,"pageSize":20,"orderBy":"created_at","order":"descending","name":""}'
$P detect                     # 等价于 p1detect.py
```

环境变量 `P1_URL` / `P1_SECRET` / `P1_KEY_ID` 可覆盖默认值。

**响应约定**（`references/api.md` 有完整契约）：

- HTTP 状态码**恒为 200**，成功与否看 body 的 `code`（200 成功）
- 统一包装 `{"code":200,"message":"","data":...}`
- 分页请求 `{page, pageSize}`（都必填），响应 `{total, items}`
- 错误码：400 参数、401 未登录、403 越权、313 密码过期、412 RBAC、500 内部错误

## 能力清单

| 能力 | 状态 | 说明 |
|---|---|---|
| 反向代理建站 + 绑证书 + SSE 配置 | ✅ 已实测 | 站点列表、建站、`proxies/file` 覆写片段、HTTPS 绑定全链路 |
| 证书申请（DNS-01）与管理 | ✅ 已实测 | 通配符签发约 40 秒；`dnsAccount` 需服务商凭据 |
| 计划任务（增删改查/立即执行/日志） | ✅ 已实测 | `cronjobs/*` |
| 进程守护（增删改查/启停/日志） | ✅ 已实测 | 路由在 `/hosts/tool/supervisor/*` |
| 容器 / 镜像 | ✅ 已实测（只读） | `containers/search`（需 `state`）、`containers/image/search`（需 `orderBy`+`order`） |
| 文件 / 监控 / 应用商店 | ✅ 已实测（只读） | `files/search`、`hosts/monitor/search`（需 `param`）、`apps/*` |
| 数据库 | ✅ 已实测（只读） | `databases/search`（需 `database`+`orderBy`+`order`） |
| **面板自身（`/api/v2/core/*`）** | ❌ **API Key 不可用** | 只认**会话登录**。返回 HTML「Access Temporarily Unavailable」或「用户未登录」 |
| 面板 MCP 服务 | ⚠️ 视环境 | 需镜像 `1panel/mcp-server`（公网不存在，仅应用商店认证 registry 分发） |

> 改面板设置、建/删 API Key、管理用户这类 `core/*` 操作无法用 API Key 完成——
> 需要网页登录。遇到 core 侧需求先告知用户，不要硬试。

## 通用参数（跨环境变量）

以下值随安装而变，**用前必须从探测结果或 API 查询取，不要假设**：

| 参数 | 获取方式 |
|---|---|
| `install_dir` | `p1detect.py` → `install_dir` |
| API 端口 | `p1detect.py` → `api.port`，或 `P1_URL` |
| 站点 vhost 目录 | `<install_dir>/www/conf.d/`（生成物，勿手改） |
| 站点内容目录 | `<install_dir>/www/sites/<alias>/` |
| 数据库 | `<install_dir>/db/{1Panel,agent,core,monitor,alert,task}.db` |
| openresty 容器名/端口 | `docker ps \| grep -i openresty`；端口见 `app_installs` |
| supervisor ini 目录 | `<install_dir>/tools/supervisord/supervisor.d/` |
| 站点分组 id | `POST /api/v2/groups/search` 或默认 `1` |
| ACME 账号 id | `POST /api/v2/websites/acme/search` |
| DNS 账号 id | `POST /api/v2/websites/dns/search` |
| 证书 id | `POST /api/v2/websites/ssl/list` |
| 站点 id | `GET /api/v2/websites/list` 按 `alias` 匹配 |

**站点端口**：vhost 的 `listen` 由 `agent.db` 的 `app_installs.http_port/https_port`
决定，**不是** `.env` 文件。该字段在已装应用上标记 `edit:false`，**改端口只能卸载重装**
并指定新端口；改 `.env` 无效。

## 常用操作

### 建一个反向代理站点（完整可用序列）

```bash
P=~/.reasonix/skills/1panel-ops/scripts/p1api.py

# 0) 先确认站点端口（多数环境是 80/443；也可能是 8080/8443 等）
python3 ~/.reasonix/skills/1panel-ops/scripts/p1detect.py | grep -A2 openresty

# 1) 建站。appType 必填（即使 type=proxy），webSiteGroupID=1 是默认分组
#    端口要与本机 openresty 的 http_port 一致，否则建站会报「端口已被占用」
$P POST /api/v2/websites '{"type":"proxy","alias":"svc.example.com","appType":"new",
  "webSiteGroupID":1,"proxy":"http://127.0.0.1:8080","IPV6":false,
  "domains":[{"domain":"svc.example.com","port":80}]}'

# 2) 取 site id（create 不返回 id）
$P GET /api/v2/websites/list          # 找到 alias 对应的 id

# 3) 覆写反代片段（SSE / 大包 / 超时）
$P POST /api/v2/websites/proxies/file '{"websiteID":<id>,"name":"root","content":"location ^~ / {\n    proxy_pass http://127.0.0.1:8080;\n    proxy_buffering off;\n    proxy_cache off;\n    proxy_request_buffering off;\n    proxy_http_version 1.1;\n    proxy_set_header Host $host;\n    proxy_set_header X-Forwarded-Proto $scheme;\n    proxy_read_timeout 900s;\n    client_max_body_size 64m;\n}"}'

# 4) 绑定证书（先 list 确认 sslId；通配证书可覆盖其单层子域）
$P POST /api/v2/websites/ssl/list '{}'
$P POST /api/v2/websites/<id>/https '{"websiteId":<id>,"enable":true,"websiteSSLId":<sslId>,
  "type":"existed","httpConfig":"HTTPToHTTPS",
  "SSLProtocol":["TLSv1.3","TLSv1.2"],"algorithm":"ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384",
  "hsts":true,"hstsIncludeSubDomains":true}'
```

**通配站点**：`domains` 里同时给精确域名和 `*.domain` 即可，1Panel 会生成
`server_name a.example.com *.example.com;`：

```bash
$P POST /api/v2/websites '{"type":"proxy","alias":"aa.example.com","appType":"new",
  "webSiteGroupID":1,"proxy":"http://127.0.0.1:8080","IPV6":true,
  "domains":[{"domain":"aa.example.com","port":80},{"domain":"*.example.com","port":80}]}'
```

**默认生成的 proxy 片段没有 `proxy_buffering off`**——SSE（agent 流、MCP Streamable HTTP）
必须自己加，否则浏览器收不到增量事件。

### 证书申请与管理

**HTTP-01 要求域名可从公网访问**；解析到内网 IP 的环境只能用 **DNS-01**（泛域名也只能 DNS-01）。

```bash
P=~/.reasonix/skills/1panel-ops/scripts/p1api.py

# 先查可用的 ACME 账号与 DNS 账号 id
$P POST /api/v2/websites/acme/search '{"page":1,"pageSize":10}'
$P POST /api/v2/websites/dns/search  '{"page":1,"pageSize":10}'

# 申请通配符（primaryDomain 直接写 *.domain；泛域名必须 provider=dnsAccount）
$P POST /api/v2/websites/ssl '{"primaryDomain":"*.example.com","provider":"dnsAccount",
  "acmeAccountId":<acmeId>,"dnsAccountId":<dnsId>,"autoRenew":true,"keyType":"EC256",
  "description":"wildcard example.com"}'
# 实测：立即返回 id，status=applying；约 40 秒后 status=ready
# 签发结果：subject=CN=*.example.com, SAN=DNS:*.example.com（Let's Encrypt）

# 轮询（列表接口过滤出目标 id）
$P POST /api/v2/websites/ssl/list '{}'
```

> **通配符只覆盖单层子域**：`*.example.com` 覆盖 `a.example.com`，但**不覆盖**
> `a.b.example.com`（多一层）。后者需单独签发。

```bash
# 申请单域名
$P POST /api/v2/websites/ssl '{"primaryDomain":"svc.example.com","provider":"dnsAccount",
  "acmeAccountId":1,"dnsAccountId":1,"autoRenew":true,"keyType":"EC256","description":"..."}'

# 绑定到站点 / 列表 / 删除
$P POST /api/v2/websites/<siteId>/https '{"websiteId":<siteId>,"enable":true,
  "websiteSSLId":<sslId>,"type":"existed","httpConfig":"HTTPToHTTPS",
  "SSLProtocol":["TLSv1.3","TLSv1.2"],"algorithm":"...","hsts":true}'
$P POST /api/v2/websites/ssl/del '{"ids":[<sslId>]}'
```

`provider` 取值：`http`（HTTP-01，需 openresty，不支持泛域名）、`dnsAccount`（DNS-01 走
服务商 API 凭据）、`dnsManual`（DNS-01 手工加 TXT，**不支持自动续期**）、`manual`
（导入已有证书，不可用于申请）。

**一个证书可绑多个站点**；但**被站点引用时不可删除**（`ErrSSLCannotDelete`）。
`autoRenew` 只在 `provider=dnsAccount|http` 时保存；内置 cron 每 6 小时检查一次，
剩余 <30 天触发续期。

### 计划任务

```bash
P=~/.reasonix/skills/1panel-ops/scripts/p1api.py

# 新建（type=shell 主机执行；填 containerName 则改为容器内执行）
# user 必须是本机真实存在的系统用户
$P POST /api/v2/cronjobs '{"name":"daily-clean","type":"shell","groupID":1,
  "spec":"0 3 * * *","script":"echo hello","scriptMode":"input","executor":"bash",
  "containerName":"","user":"root","retainCopies":3,"timeout":60,"ignoreErr":true,
  "alertCount":0,"alertTriggerMode":"failed"}'

# 列表（orderBy 只能是 name|status|createdAt）
$P POST /api/v2/cronjobs/search '{"page":1,"pageSize":20,"orderBy":"createdAt","order":"descending"}'

# 立即执行一次（异步）
$P POST /api/v2/cronjobs/handle '{"id":<id>}'

# 执行记录 / 单次日志
$P POST /api/v2/cronjobs/search/records '{"cronjobID":<id>,"page":1,"pageSize":10,
  "status":"","startTime":"<RFC3339>","endTime":"<RFC3339>"}'
$P POST /api/v2/cronjobs/records/log '{"id":<recordId>}'

# 启停 / 改 / 删
$P POST /api/v2/cronjobs/status '{"id":<id>,"status":"Disable"}'
$P POST /api/v2/cronjobs/update '{...同新建字段, "id":<id>}'
$P POST /api/v2/cronjobs/del '{"ids":[<id>]}'
```

**类型 `type`**：`shell` `curl` `ntp` `website` `cutWebsiteLog` `clean` `app` `database`
`directory` `log` `snapshot` `syncIpGroup` `cleanLog`（**没有 `backup` 类型**，备份由
`app`/`website`/`database`/`directory`/`snapshot`/`log`/`cutWebsiteLog` 触发）。

**Cron 表达式**用 robfig/cron 5 段式，支持 `@every Nm`，**多个用 `&&` 分隔**。
**没有任务级时区字段**，调度器用系统时区（`timedatectl` 读取）。

`scriptMode`：`input`（直接贴脚本）/ `library`（按 `scriptID` 取脚本库）/ `select`
（选主机文件；容器模式下会先 `docker cp` 到容器 `/tmp`）。

### 进程守护（工具箱 → 进程守护）

**路由不在 `/toolbox` 下，而在 `/hosts/tool/supervisor/*`。**

1Panel 不自带 supervisord，它驱动系统里已装的那个（systemd `supervisor.service`），
通过 `supervisorctl` 下发指令。1Panel 托管的进程定义在
`<install_dir>/tools/supervisord/supervisor.d/<name>.ini`，日志在同级的 `log/`。

```bash
P=~/.reasonix/skills/1panel-ops/scripts/p1api.py

# 守护服务状态（是否存在、运行中、配置路径、include 目录）
$P POST /api/v2/hosts/tool/status '{"type":"supervisord"}'

# 列进程（含每个实例的 status/PID/uptime）
$P GET /api/v2/hosts/tool/supervisor/process

# 新增进程（dir 必须存在、user 必须是系统用户）
$P POST /api/v2/hosts/tool/supervisor/process '{"name":"myapp","operate":"create",
  "command":"/usr/bin/myapp --serve","user":"root","dir":"/root","numprocs":"1",
  "autoRestart":"true","autoStart":"true","environment":"KEY=VAL"}'

# 启停 / 删除
$P POST /api/v2/hosts/tool/supervisor/process '{"name":"myapp","operate":"start"}'
$P POST /api/v2/hosts/tool/supervisor/process '{"name":"myapp","operate":"delete"}'

# 读 stdout / stderr / 配置；清空日志
$P POST /api/v2/hosts/tool/supervisor/process/file/get '{"name":"myapp","file":"out.log"}'
$P POST /api/v2/hosts/tool/supervisor/process/file '{"name":"myapp","operate":"clear","file":"out.log"}'
```

`operate` 取值：`create` `update` `start` `stop` `restart` `delete`。
`delete` 会同时删掉 ini 和两个日志文件（破坏性）。
**运行状态**在每个进程实例的 `status` 数组里，取值：`RUNNING` `STOPPED` `STARTING`
`STOPPING` `FATAL` `BACKOFF` `EXITED` `ERROR`。

**注意**：若系统里同时跑着多个 supervisord，`supervisorctl` 连的是 socket 拥有者。
用 `/hosts/tool/status` 的 `configPath` 确认 1Panel 操作的是哪一个。

### 其他高频接口（完整清单见 `references/api.md`）

| 域 | 关键路径（带 ✅ 的已在本机实测） |
|---|---|
| 网站 | `POST /websites`、`/websites/search`、`/websites/list`、`/websites/update`、`/websites/del`、`/websites/operate`、`/websites/{id}/https`、`/websites/nginx/update`、`/websites/config/update` |
| 反代片段 | `POST /websites/proxies`、`/proxies/update`、`/proxies/file`、`/proxies/delete` |
| 证书 | `POST /websites/ssl`（申请）、`/websites/ssl/search`、`/websites/acme`（ACME 账号）、`/websites/{id}/https`（绑定） |
| 容器 ✅ | `POST /containers/search`（**`state` 必填**，如 `"all"`）、`/containers/operate`（`operation:"start\|stop\|restart\|kill\|pause\|unpause\|remove"`，**删除就是 `remove`**）、`/containers/prune`、日志 `/containers/search/log` |
| 镜像 ✅ | `POST /containers/image/search`（**`orderBy`+`order` 必填**）、`/containers/image/pull`、`/containers/image/remove`（注意挂在 containers 组下，**不是** `/images/*`） |
| 数据库 ✅ | `POST /databases/db`（建库）、`/databases/db/update`、`/databases/db/del`、`/databases/db/del/check`、`/databases/search`（**`database`+`orderBy`+`order` 必填**） |
| 文件 ✅ | `POST /files/search`（列目录）、`/files/content`（读）、`/files/save`（写）、`/files/del`、`/files/batch/del`、`/files/rename`、`/files/move` |
| 主机 ✅ | `/hosts/monitor/search`（**`param` 必填**：`cpu`/`memory`/`load`…，空串也不行）、`/hosts/firewall/*`；宿主进程是顶层 `/process/*`（`/process/stop`、`/process/:pid`、`/process/listening`），**不是** `/hosts/process/*`，且**没有** `/process/list` |
| 商店 ✅ | `/apps/search`、`/apps/install`、`/apps/installed/search`、`/apps/installed/op`（启停删已装应用），**没有** `/apps/operate` |
| 定时任务 | `POST /cronjobs`（建）、`/cronjobs/status`（启停）、`/cronjobs/handle`（立即执行），**没有** `/cronjobs/create`、`/cronjobs/operate` |
| 面板 MCP | `/api/v2/core/mcp/*`（凭据、目录、运行时）——见下节 |

## 危险操作护栏

**这些操作执行前必须先向用户确认，并回显你要改的目标（id + 名称/域名）：**

- 删除类：`/websites/del`、`/containers/operate`（`operation:"remove"`）、`/containers/prune`、
  `/containers/image/remove`、`/databases/db/del`、`/apps/installed/op`（删除已装应用）、
  `/files/del`、`/files/batch/del`
- 停服类：`/containers/operate` 的 stop/kill、`/websites/operate` 的 stop、面板服务重启
- 覆盖类：`/websites/nginx/update`、`/websites/proxies/file`、`/files/save`、
  `/files/rename`、`/files/move`、`/containers/update`（改端口/挂载）、`/databases/db/update`
- 证书类：`/websites/ssl` 申请、`/websites/{id}/https` 改绑、ACME 账号删除、DNS 账号删除

**可以自主执行的**：所有查询类接口（search/list/get/content/status/log）、
以及你自己刚创建出来的资源的首次配置。

**边界**：本 skill 只管 1Panel 面板内的资源。宿主机的 docker / systemd / 文件系统
不在 1Panel 的授权范围内——直接用对应工具，但同样适用上面的确认规则。

## 关于 1Panel 内置 MCP

1Panel v2 确实自带 MCP server（把面板 REST API 包装成 MCP 工具集），外部 Agent 可用
`Authorization: Bearer mcp_xxx` 连**面板端口的 `/mcp`**。但不推荐作为 Agent 的主通道：

1. **适配器镜像难获取**：`1panel/mcp-server` 在 Docker Hub 上不存在，只经 1Panel
   应用商店的认证 registry 分发。
2. **契约强绑定**：适配器必须满足 `contractVersion=5` + `/usr/local/bin/mcp-1panel` +
   `--catalog`（≤256 工具），镜像不合约 = 整个功能不可用，**没有降级路径**。
3. **覆盖不比 REST API 全**：MCP 工具集排除 internal/core/terminal/ws 路径。
4. **管理面仍要 session**：装/启停 MCP、签发 `mcp_` 凭据必须走面板会话（且要求超管）。
5. **客户端限制**：请求**不能带 `Origin` 头**（带即 403），不能带 query。

**结论**：让 Agent 调 1Panel，用 REST API + API Key。只有当你要让 **第三方 MCP 客户端**
（Claude Code、Codex 等）以标准 MCP 协议接入 1Panel 时，才去 UI 里启用它。

若用户明确要求启用面板 MCP：
- UI：AI → MCP → 「1Panel」页签 → 安装（勾选要授权的工具）→ 创建凭据 → 拿 `mcp_` token
- 前提：rootful Docker、`/etc/1panel/mcp-runtime` 目录存在且非软链、127.0.0.1:18081 未占用
- 外部客户端连 `https://<面板域名>/mcp`，带 `Authorization: Bearer mcp_xxx`，
  `Accept: application/json, text/event-stream`，**不带 Origin**

## 已实测的坑（源码 + 实测双向验证）

1. **`appType` 必填**：即使 `type=proxy`，`appType` 也要填 `"new"` 或 `"installed"`，
   否则 400（`oneof` 校验）。
2. **同名文件/目录会阻塞建站**：站点已存在（手写的 `conf.d/<alias>.conf` 或
   `sites/<alias>/`）时，创建报 `ErrUpdateBuWebsite`（500）且**不写任何文件**。
   先清掉残留再建。
3. **API Key 的 `ip_white_list` 不能为空**：独立 Key 走自己的白名单，空值会被
   `IsIPInWhiteList` 直接拒绝（`ErrApiConfigIPInvalid`）。通过 UI 建 Key 时必填。
4. **独立 Key 不读全局 `ApiInterfaceStatus`**：`configForAPIKey` 用 `key.Status` 覆盖，
   全局开关关着也不影响独立 Key；只有旧版全局 Key 才需要 `ApiInterfaceStatus=Enable`。
   实测佐证（`ApiInterfaceStatus=Disable` 状态下，同一端点三种走法）：
   ```
   不带 Key-ID（旧版全局 Key 路径） → code=401 "API 接口禁止访问"   ← 被全局开关拦
   带真实 Key-ID（独立 Key 路径）   → code=401 "API 接口密钥错误"   ← 已进入独立 Key 校验
   ```
   错误码不同即可判断当前走的是哪条鉴权路径。
5. **建站 API 不返回 site id**：创建后要靠 `/websites/list` 按 alias 查。
6. **`client_max_body_size` 默认没有**：nginx 默认 1m，OTLP/大上传必须显式设。
   可用 `POST /websites/config/update`（`scope=http-per`）或直接写进 proxy 片段。
7. **没有独立 reload 接口**：所有写配置的内部流程自带 `nginx -t` + `nginx -s reload`，
   失败自动回滚，**不要**自己去 docker exec reload。
8. **HTTP-01 需要公网可达**：域名解析到内网 IP 时，Let's Encrypt 到不了。
   用 DNS-01（需服务商 API 凭据，见 `website_dns_accounts`）。
9. **`PageCronjob.OrderBy` 的取值与网站不同**：网站是 `created_at`（下划线），
   计划任务是 `createdAt`（驼峰）。填错直接 400。
10. **`cronjobs/search/records` 的时间不能留空**：`startTime`/`endTime` 必须是
    RFC3339（`2026-11-09T03:00:15Z`），传空串会报时间解析错误。
11. **进程守护路由在 `/hosts/tool/supervisor/*`**，不在 `/toolbox` 下——工具箱菜单里
    的「进程守护」和 API 路径对不上，容易找错。
12. **supervisor 的 `operate=create` 会写 ini 并 `supervisorctl reread+update`**，
    同名已存在会报 `ErrConfigAlreadyExist`；`dir` 必须存在、`user` 必须是系统用户。
13. **`/websites/ssl` 是异步的**：返回时 `status=init`，之后 `applying → ready`。
    DNS-01 实测约 40~120 秒。别在返回后立刻判失败。
14. **`core/*` 路由不接受 API Key**：带正确签名调 `/api/v2/core/settings`
    返回 **HTML 拦截页**「Access Temporarily Unavailable」（HTTP 200，非 JSON）；
    `/api/v2/core/auth/current` 则明确报「用户未登录」。结论：**面板自身的管理能力
    （改设置、建/删 Key、管用户、看快照）只能走网页会话**。遇到 core 侧需求先告知用户。
15. **多个 search 接口有隐藏必填项**（缺了直接 400，报错会指名道姓）：
    - `/containers/search` → `state`（`all`/`running`/`stopped`…）
    - `/containers/image/search` → `orderBy` + `order`
    - `/databases/search` → `database`（`mysql` 等）+ `orderBy` + `order`
    - `/hosts/monitor/search` → `param`（`cpu`/`memory`/`load`…，**传空串也不行**）
16. **宿主进程没有列表接口**：`/process/list`、`/hosts/process/list` 都是 **404**；
    实际只有 `/process/stop`、`/process/:pid`、`/process/listening`。要列进程请直接用
    `procs`/`ps`。
17. **`/websites/ssl/list` 会返回私钥明文**（`privateKey` 与 `pem` 整段）。调这个接口时
    **不要把输出整段贴到对话里**，只取 `id`/`primaryDomain`/`status`/`expireDate` 等元字段。
18. **`/websites/update` 不会重写已生成的 `proxy/root.conf`**：面板显示的 `proxy` 字段
    可能与实际片段不一致。改反代目标要同时调 `proxies/file`。
19. **删站点用 `{"id": <id>}`**（单数），不是 `{"ids":[...]}`——后者报
    `WebsiteDelete.ID required`。
20. **建站端口检查看实际监听**：目标端口已被占用时报 `服务错误: <port> 端口已被占用！`。
    要用 80/443 建站，须先确保 openresty 已按该端口配置（见下条）。
21. **openresty 的站点端口只能靠重装改**：端口存在 `agent.db` 的 `app_installs`
    （`http_port`/`https_port`），`GET /apps/installed/params/<id>` 返回 `edit:false`，
    改 `.env` 文件**完全无效**。要换成 80/443 必须卸载重装并在安装表单指定。

## 配套资源

- `scripts/p1detect.py` — 环境探测，生成 profile（**新主机第一步**）
- `scripts/p1api.py` — 签名客户端（读取 profile / 环境变量 / 凭据文件）
- `references/api.md` — 按域分组的完整 API 契约与 DTO 字段
- 面板 UI：`<探测出的 api.port>` 与 `SecurityEntrance` 拼出，形如
  `http://<本机IP>:<port>/<entrance>`
- 面板二进制：`<install_dir>/../bin/1panel-core`（通常 `/usr/local/bin/1panel-core`），
  CLI 支持 `version` / `user-list` / `user-info` / `reset {domain,entrance,https,ips,mfa}`
- 本机不一定有 1Panel 源码副本；`references/api.md` 中的路由依据上游 v2 源码整理，
  改动前建议用 `/api/v2/<域>` 实测确认
