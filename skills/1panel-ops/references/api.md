# 1Panel v2 REST API 契约（按域）

基址由探测决定（见 SKILL.md「第一步：探测本机参数」）：`P1_URL` 环境变量 →
`~/.config/1panel/profile.json` 的 `api.base` → 自动探测 `1panel-core` 监听端口 →
默认 `http://127.0.0.1:9999`。
agent 侧路由前缀 `/api/v2`，面板自身 `/api/v2/core`。所有请求都要带签名头（见 SKILL.md）。

路由清单来源：上游 1Panel v2 源码的 `agent/router/ro_*.go` 与 `core/router/ro_*.go`。
若本机无源码副本，改动前请先用 `/api/v2/<域>` 实测确认路由存在。

---

## 认证与账号（`/api/v2/core/auth`）

| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/auth/login` | 密码登录，密码需 RSA+AES 双重加密，公开入口 |
| POST | `/auth/mfalogin` | MFA 第二步 |
| GET | `/auth/setting` | 登录页配置（公开） |
| GET | `/auth/captcha` | 验证码（公开） |
| GET | `/auth/current` | 当前用户 |
| POST | `/auth/api/keys/create` | **创建独立 API Key**（需 session） |
| POST | `/auth/api/keys/search` | Key 列表 |
| POST | `/auth/api/keys/update` | 更新 |
| POST | `/auth/api/keys/status` | 启停 |
| POST | `/auth/api/keys/revoke` | 吊销 |
| POST | `/auth/api/keys/delete` | 删除 |
| POST | `/auth/api/keys/reveal` | 揭示明文（需 session） |

> `POST /auth/api/keys/create` 的 `requestID` 支持幂等重试；明文 API Key **只在创建时返回一次**。

## 面板设置与用户（`/api/v2/core/...`）

| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/settings/search` | 查设置 |
| POST | `/settings/update` | 改设置（含 `ApiInterfaceStatus`、`SecurityEntrance`、`AllowIPs`） |
| POST | `/groups/*` | 用户组 |

## 网站（`/api/v2/websites`）

| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/websites` | **创建**。DTO 见下 |
| POST | `/websites/search` | 分页。`orderBy` 必填：`primary_domain\|type\|status\|createdAt\|expire_date\|created_at\|favorite`；`order` 必填：`null\|ascending\|descending` |
| GET | `/websites/list` | 全部站点（扁平） |
| GET | `/websites/{id}` | 单站详情 |
| POST | `/websites/update` | 更新元信息 |
| POST | `/websites/del` | 删除。`{id, deleteApp, deleteBackup, forceDelete, deleteDB}` |
| POST | `/websites/operate` | 启停：`{id, operate:"start"\|"stop"}` |
| POST | `/websites/check` | 建站前预检 |
| GET | `/websites/{id}/config/{type}` | 读某作用域配置 |
| POST | `/websites/config` | 读作用域配置：`{scope, websiteId}` |
| POST | `/websites/config/update` | 写作用域配置。`scope=http-per` 含 `client_max_body_size`、`gzip*`、`keepalive_timeout` |
| GET | `/websites/{id}/config/openresty` | 读 vhost 原文 |
| POST | `/websites/nginx/update` | **覆写整个 vhost**：`{id, content}` |
| POST | `/websites/{id}/https` | 绑定/解绑证书 |

**`WebsiteCreate` 关键字段**

```json
{
  "type": "proxy",              // proxy|static|runtime|deployment|subsite|stream
  "alias": "svc.example.com",     // 唯一，不能为 default
  "appType": "new",             // ← 必填！new|installed（即使 type=proxy）
  "webSiteGroupID": 1,          // 必填，默认分组=1
  "proxy": "http://127.0.0.1:8080",  // 反代目标，必须自带 scheme
  "IPV6": false,
  "domains": [{"domain":"svc.example.com","port":80,"ssl":false}]
}
```

其余可选：`enableSSL`+`websiteSSLID`（建站直接带证书）、`runtimeID`（runtime 类型）、
`createDb`+`db*`（建库）、`ftpUser`+`ftpPassword`、`streamPorts`+`servers`（stream 类型）。

### 反代片段（proxy 目录）

| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/websites/proxies` | 列 location 片段 |
| POST | `/websites/proxies/update` | 增改删 location（`operate:create\|edit\|delete\|enable\|disable`） |
| POST | `/websites/proxies/file` | **整文件覆写**：`{websiteID, name:"root", content:"..."}` |
| POST | `/websites/proxies/delete` | 删片段 |
| POST | `/websites/proxies/status` | 启停片段 |

`NginxProxyUpdate`：`{websiteID(uint,必填), content(string,必填), name(string,必填)}`

### 证书（`/api/v2/websites/ssl`、`/websites/acme`、`/websites/dns`）

| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/websites/acme` | 建 ACME 账号：`{email, type:"letsencrypt", keyType, useEAB, eabKid, eabHmacKey}` |
| POST | `/websites/ssl` | 申请证书。`provider`：`http` 或 `dnsAccount`；`acmeAccountId` 必填 |
| POST | `/websites/ssl/obtain` | 手动触发签发 `{ID}` |
| POST | `/websites/ssl/search` / `/list` | 查询 |
| POST | `/websites/dns` | DNS 账号（DNS-01 验证用） |

`WebsiteHTTPSOp`：

```json
{"websiteId":23,"enable":true,"websiteSSLId":3,"type":"existed",
 "httpConfig":"HTTPToHTTPS","SSLProtocol":["TLSv1.3","TLSv1.2"],
 "algorithm":"ECDHE-ECDSA-AES256-GCM-SHA384:...","hsts":true,
 "hstsIncludeSubDomains":true}
```

`type`：`existed`（用已有证书）/ `auto` / `manual`（贴 PEM）。

## 容器与镜像（`/api/v2/containers`）

搜索 `/stats/{id}`、`/info`、`/search`、`/list`、`/status`、`/inspect`、`/operate`
（`operation`：`up|start|stop|restart|kill|pause|unpause|remove`，**删除容器就是 `remove`**）、
`/update`、`/rename`、`/commit`、`/prune`、`/search/log`、`/download/log`、
`/clean/log`、`/files/*`、`/repo/*`（镜像仓库）、`/compose/*`。

镜像操作挂在 containers 组下：`/containers/image/search`、`/containers/image/pull`、
`/containers/image/remove`、`/containers/image/remote/search`。
镜像仓库配置走 `docker login`（写 `~/.docker/config.json`），不是 1Panel 数据库。

## 数据库（`/api/v2/databases`）

`/search`、`/db`（新建）、`/db/update`、`/db/del`、`/db/del/check`、`/db/{name}`、
`/db/list/{type}`、`/db/item/{type}`、`/db/search`、
`/users/*`（账号）、`/grants/*`（授权）、`/status`、`/variables`、`/redis/*`、
`/remote`、`/format/options`。

## 文件（`/api/v2/files`）

`/search`（按路径列目录）、`/tree`、`/content`（读）、`/save`（写）、`/del`、
`/batch/del`、`/rename`、`/move`、`/compress`、`/decompress`、`/upload`、
`/chunkupload`、`/download`、`/size`、`/mode`（权限）、`/owner`、`/wget`、
`/share/*`（公开分享）、`/history/*`。

`/files/share` 是**免登录**公开路径，不要拿它做鉴权。

## 主机 / 防火墙 / 监控（`/api/v2/hosts`）

`/info`、`/search`、`/tree`、`/firewall/*`（规则、端口转发、白名单、Docker 端口策略）、
`/monitor/search`（监控）、`/hosts/diagnostics/*`（pprof）、`/hosts/terminal/*`（终端 WS）。

## 应用商店（`/api/v2/apps`）

`/search`（商店）、`/detail/{appId}/{version}/{type}`、`/install`、`/installed/search`、
`/installed/list`、`/installed/op`、`/installed/delete/check/{id}`、`/installed/conf`、
`/installed/params/update`、`/installed/update/versions`、`/sync/remote`、`/checkupdate`。

## 定时任务 / 日志 / 运行时 / 进程

- `/cronjobs`：`/search`、`/import`、`/export`、`/handle`、`/status`、`/stop`、`/records/log`
- `/logs`：`/system/files`、`/system/status`、`/system/read`、`/system/services`、
  `/tasks/search`、`/tasks/read`、`/tasks/executing/count`
- `/runtimes`：PHP/Node/Java/Go/Python/.NET 运行时与扩展
- `/process`：宿主进程（`/process/stop`、`/process/:pid`、`/process/listening`、`/process/ws`），顶层组，不在 `/hosts` 下
- `/openresty`：`/scope`、`/update`、`/status`、`/file`、`/build`、`/modules`、`/https`

## 面板 MCP（`/api/v2/core/mcp`）

| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/mcp/service/install` | 安装 MCP 适配器（异步任务） |
| POST | `/mcp/service/operate` | `{operation:"start"\|"stop"\|"restart"}` |
| POST | `/mcp/credentials/create` | 创建 `mcp_` 凭据 |
| POST | `/mcp/catalog` | 拉取工具目录 |
| POST | `/mcp/runtime/*` | 内部运行时 |

外部客户端连 **`/mcp`**（面板端口），`Authorization: Bearer mcp_xxx`，**不能带 `Origin`**。

## 证书申请与管理（`/api/v2/websites/ssl`、`/websites/acme`、`/websites/dns`）

| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/websites/ssl` | **申请证书（异步）**。DTO 见下 |
| POST | `/websites/ssl/obtain` | 手动触发申请/续签 `{ID}` |
| POST | `/websites/ssl/search` / `/list` | 查询（含 status、expireDate、applyError） |
| GET | `/websites/ssl/{id}` | 单证书详情 |
| GET | `/websites/ssl/website/{websiteId}` | 某站点绑定的证书 |
| POST | `/websites/ssl/del` | 删除 `{ids:[]}`。被站点引用时拒绝 |
| POST | `/websites/ssl/update` | 改元信息（不自动重签） |
| POST | `/websites/ssl/upload` | 导入 PEM（provider=manual） |
| POST | `/websites/ssl/download` | 下载证书文件 |
| POST | `/websites/ssl/resolve` | dnsManual 取 TXT 记录值 |
| POST | `/websites/acme` | 建 ACME 账号（**立即向 CA 注册**） |
| POST | `/websites/acme/search` / `/del` / `/update` | ACME 账号管理（只能改 useProxy） |
| POST | `/websites/dns` | 建 DNS 账号（28 种 lego provider） |
| POST | `/websites/dns/search` / `/update` / `/del` | DNS 账号管理 |

`WebsiteSSLCreate` 关键字段：

```json
{"primaryDomain":"svc.example.com",
 "otherDomains":"a.example.com\nb.example.com",  // 换行分隔
 "provider":"dnsAccount",             // http|dnsAccount|dnsManual|manual|selfSigned
 "acmeAccountId":1,                   // 必填
 "dnsAccountId":1,                    // provider=dnsAccount 时必填
 "autoRenew":true,                    // 仅 http/dnsAccount 会保存
 "keyType":"EC256",                   // EC256|EC384|RSA2048|RSA3072|RSA4096
 "description":"",
 "execShell":false,"shell":"",        // 签发成功后执行的后置脚本（不是 DNS 验证方式）
 "skipDNS":false,                     // 跳过权威 NS 传播检查
 "nameserver1":"","nameserver2":"",   // 自定义 DNS 服务器，必须是 IP
 "disableCNAME":false,"isIp":false}
```

**状态机**：`init` → `applying` → `ready` / `error` / `applyError`。
**自动续期**：内置 cron `0 */6 * * *`，剩余 <30 天触发（IP 证书 <72 小时）。

**ACME 账号**：`{email, type:"letsencrypt|zerossl|buypass|google|custom", keyType,
eabKid, eabHmacKey, useProxy, caDirURL, useEAB}`。`google`/`custom+useEAB` 必须给
eabKid+eabHmacKey。

**DNS 账号**：`{name, type, authorization:{...}}`。`authorization` 的键名按 provider 变
（AliYun=`accessKey`+`secretKey`；TencentCloud=`secretID`+`secretKey`；
CloudFlare=`email`+`apiKey`；AWSRoute53=`accessKey`+`secretKey`+`region`+`endpoint`…）。

## 计划任务（`/api/v2/cronjobs`）

| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/cronjobs` | **新建** |
| POST | `/cronjobs/update` | 改（同一个 DTO，带 id） |
| POST | `/cronjobs/del` | 删 `{ids:[], cleanData, cleanRemoteData}` |
| POST | `/cronjobs/status` | 启停 `{id, status:"Enable"\|"Disable"}` |
| POST | `/cronjobs/handle` | **立即执行一次**（异步） |
| POST | `/cronjobs/stop` | 中断正在执行的那次 |
| POST | `/cronjobs/search` | 列表。`orderBy` 只能是 `name\|status\|createdAt` |
| POST | `/cronjobs/search/records` | 执行记录。时间必须 RFC3339 |
| POST | `/cronjobs/records/log` | 单次执行日志 `{id: recordId}` |
| POST | `/cronjobs/records/clean` | 清执行记录 |
| POST | `/cronjobs/load/info` | 任务详情 |
| POST | `/cronjobs/next` | 预览未来 5 次触发 `{spec}` |
| POST | `/cronjobs/import` / `/export` | 批量导入导出 |

`CronjobOperate` 关键字段：

```json
{"name":"daily","type":"shell","groupID":1,
 "spec":"0 3 * * *",                   // 必填；5 段式或 @every Nm；多个用 && 分隔
 "scriptMode":"input",                 // input|library|select
 "script":"...",                       // input 模式的脚本体
 "scriptID":0,                         // library 模式的脚本库 id
 "executor":"bash",                    // bash|sh|python|python3（主机执行）
 "containerName":"",                   // 非空则改为容器内执行
 "user":"root","command":"sh",
 "retainCopies":3,"timeout":60,"retryTimes":0,"ignoreErr":true,
 "alertCount":0,"alertTitle":"","alertMethod":"","alertTriggerMode":"failed",
 "retainCopies":3}
```

**类型**：`shell` `curl` `ntp` `website` `cutWebsiteLog` `clean` `app` `database`
`directory` `log` `snapshot` `syncIpGroup` `cleanLog`（无 `backup`）。

## 进程守护（`/api/v2/hosts/tool/supervisor/*`）

| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/hosts/tool/status` | 守护服务状态 `{type:"supervisord"}` |
| POST | `/hosts/tool/init` | 初始化（在主配置写 include 并重启服务） |
| POST | `/hosts/tool/operate` | 启停守护服务 `{type, operate:start\|stop\|restart}` |
| POST | `/hosts/tool/config/get` / `/set` | 读/写主配置全文（写会重启） |
| GET | `/hosts/tool/supervisor/process` | **列进程** |
| POST | `/hosts/tool/supervisor/process` | 增改删启停 `{name, operate, command, user, dir, numprocs, autoRestart, autoStart, environment}` |
| POST | `/hosts/tool/supervisor/process/file/get` | 读日志/配置 `{name, file:"out.log"\|"err.log"\|"config"}` |
| POST | `/hosts/tool/supervisor/process/file` | 清日志 / 改配置 `{name, operate:"clear"\|"update", file, content}` |

`operate`：`create` `update` `start` `stop` `restart` `delete`。
进程实例状态在每个进程的 `status` 数组里：`RUNNING` `STOPPED` `STARTING` `STOPPING`
`FATAL` `BACKOFF` `EXITED` `ERROR`。

## 请求头汇总

| 头 | 必需 | 说明 |
|---|---|---|
| `1Panel-Token` | 是 | 签名值 |
| `1Panel-Timestamp` | 是 | Unix 秒，±60s 窗口 |
| `1Panel-Signature-Version` | 建议 | `hmac-sha256` / `md5` / `v1` |
| `1Panel-Key-ID` | 独立 Key 建议 | Key 的 UUID |
| `Content-Type` | POST 时 | `application/json` |
| `Origin` | 不需要 | REST API 不校验 Origin（MCP 端点则禁止带） |
