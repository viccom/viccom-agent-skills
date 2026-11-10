#!/usr/bin/env python3
"""探测本机 1Panel 部署参数，生成 profile（JSON）。

用法:
  p1detect.py                 # 探测并打印 JSON
  p1detect.py --write         # 探测并写入 ~/.config/1panel/profile.json
  p1detect.py --write --force # 覆盖已存在的 profile

设计原则:
  - 只读探测，不改任何系统状态
  - 端口探测不依赖进程名可见性（非 root 也能用）：
    ss 进程名 → core.db 的 ServerPort → 本地监听端口 HTTP 指纹
  - 已有 profile / P1_URL 作为兜底，输出里标注 api.port_source 与 api.verified
  - 探测失败时给出明确原因，不抛栈
"""
import concurrent.futures
import json
import os
import pathlib
import re
import subprocess
import sys
import urllib.request

PROFILE = pathlib.Path.home() / ".config" / "1panel" / "profile.json"
DEFAULT_PORT = 9999
FINGERPRINT_TIMEOUT = 0.4


def run(cmd, timeout=10):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return r.stdout if r.returncode == 0 else ""
    except (OSError, subprocess.SubprocessError):
        return ""


def _query(db_path, sql, args=()):
    """只读查询，返回行列表；库不存在/打不开返回 None（区别于空结果 []）。"""
    if not db_path or not os.path.exists(db_path):
        return None
    try:
        import sqlite3
        con = sqlite3.connect("file:%s?mode=ro" % db_path, uri=True, timeout=5)
        try:
            return con.execute(sql, args).fetchall()
        finally:
            con.close()
    except Exception:
        return None


def _db_state(db_path):
    """返回 'ok' | 'missing' | 'unreadable'。非 root 常见 'unreadable'。"""
    try:
        os.stat(db_path)
    except FileNotFoundError:
        return "missing"
    except OSError:
        return "unreadable"
    return "ok" if _query(db_path, "select 1") is not None else "unreadable"


def _load_profile():
    if not PROFILE.exists():
        return {}
    try:
        return json.loads(PROFILE.read_text())
    except (OSError, ValueError):
        return {}


def _profile_base():
    return ((_load_profile().get("api") or {}).get("base") or "").strip().rstrip("/")


def _url_port(base):
    m = re.search(r":(\d+)$", base.rstrip("/"))
    return int(m.group(1)) if m else DEFAULT_PORT


def _http_text(url, timeout=FINGERPRINT_TIMEOUT):
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "1panel-detect"})
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.read(8192).decode("utf-8", "ignore")
    except Exception:
        return ""


def _is_1panel_base(base):
    """HTTP 指纹：1Panel 的拦截页文案，或 /api/v2 的统一 JSON 信封。"""
    body = _http_text(base + "/")
    if "access temporarily unavailable" in body.lower():
        return True
    body = _http_text(base + "/api/v2/websites/list")
    try:
        obj = json.loads(body)
    except (ValueError, TypeError):
        return False
    return (isinstance(obj, dict) and isinstance(obj.get("code"), int)
            and "message" in obj and "data" in obj)


def _ss_ports():
    """解析 ss 输出，返回 (进程名可见的 1panel-core 端口集合, 全部监听端口集合)。"""
    named, listening = set(), set()
    out = run(["ss", "-tlnp"])
    for line in out.splitlines()[1:]:
        parts = line.split()
        if len(parts) < 4:
            continue
        m = re.search(r":(\d+)$", parts[3])
        if not m:
            continue
        port = int(m.group(1))
        listening.add(port)
        if "1panel-core" in line:
            named.add(port)
    return named, listening


def _probe_ports(ports):
    """并发探测本地监听端口的 HTTP 指纹，返回命中的端口（没有则 None）。"""
    ports = sorted(ports)
    if not ports:
        return None

    def probe(port):
        return port if _is_1panel_base("http://127.0.0.1:%d" % port) else None

    with concurrent.futures.ThreadPoolExecutor(max_workers=min(16, len(ports))) as pool:
        hits = [p for p in pool.map(probe, ports) if p]
    return hits[0] if hits else None


def detect_install_dir():
    """1Panel 安装根目录。"""
    for d in ("/opt/1panel", "/usr/local/1panel", "/usr/share/1panel"):
        if pathlib.Path(d).is_dir():
            return d
    return ""


def _core_db(install_dir):
    return os.path.join(install_dir, "db", "core.db") if install_dir else ""


def _agent_db(install_dir):
    return os.path.join(install_dir, "db", "agent.db") if install_dir else ""


def _db_server_port(install_dir):
    rows = _query(_core_db(install_dir), "select value from settings where key='ServerPort'")
    if rows and rows[0][0] and str(rows[0][0]).isdigit():
        return int(rows[0][0])
    return 0


def detect_entrance(install_dir=""):
    rows = _query(_core_db(install_dir), "select value from settings where key='SecurityEntrance'")
    return (rows[0][0] or "") if rows else ""


def detect_admin(install_dir=""):
    rows = _query(_core_db(install_dir), "select value from settings where key='UserName'")
    return (rows[0][0] or "") if rows else ""


def detect_app_port(app_name="openresty", install_dir=""):
    """从 agent.db 的 app_installs 读应用端口（vhost listen 的依据）。"""
    rows = _query(
        _agent_db(install_dir),
        "select http_port, https_port from app_installs where lower(name)=lower(?)",
        (app_name,),
    )
    if rows:
        return {"http": rows[0][0] or 0, "https": rows[0][1] or 0}
    return None


def detect_certs(install_dir=""):
    """列出证书元信息（不取私钥）。"""
    rows = _query(
        _agent_db(install_dir),
        "select id, primary_domain, provider, status, expire_date from website_ssls order by id",
    )
    return [
        {"id": r[0], "domain": r[1], "provider": r[2], "status": r[3], "expire": r[4]}
        for r in (rows or [])
    ]


def detect_websites(install_dir=""):
    """列出站点（不打印私钥等敏感字段）。"""
    rows = _query(
        _agent_db(install_dir),
        "select w.id, w.alias, w.proxy, w.status, w.website_ssl_id, "
        "(select group_concat(d.domain||':'||d.port, ',') "
        " from website_domains d where d.website_id=w.id) "
        "from websites w order by w.id",
    )
    return [
        {"id": r[0], "alias": r[1], "proxy": r[2], "status": r[3],
         "sslId": r[4] or 0, "domains": r[5] or ""}
        for r in (rows or [])
    ]


def detect_credential_state():
    conf = pathlib.Path.home() / ".config" / "1panel"
    return {
        "api_key": (conf / "api_key").exists(),
        "api_key_id": (conf / "api_key_id").exists(),
        "profile": (conf / "profile.json").exists(),
    }


def detect_api(install_dir=""):
    """解析面板 API 基址，返回 (base, port, source, verified)。

    顺序：P1_URL → ss 可见的 1panel-core → core.db 的 ServerPort
    → 本地监听端口 HTTP 指纹 → 已有 profile 兜底 → 默认 http://127.0.0.1:9999。
    """
    named, listening = _ss_ports()
    db_port = _db_server_port(install_dir)
    env = os.environ.get("P1_URL", "").strip()

    candidates = []
    if env:
        candidates.append(("env:P1_URL", env.rstrip("/")))
    candidates += [("ss", "http://127.0.0.1:%d" % p) for p in sorted(named)]
    if db_port:
        candidates.append(("core.db", "http://127.0.0.1:%d" % db_port))
    candidates += [("fingerprint", "http://127.0.0.1:%d" % p) for p in sorted(listening)]
    profile_base = _profile_base()
    if profile_base:
        candidates.append(("profile", profile_base))

    seen = set()
    for source, base in candidates:
        if base in seen:
            continue
        seen.add(base)
        verified = _is_1panel_base(base)
        # 显式指定与已有 profile 即使未被指纹确认也采用，但标注 verified=false。
        if verified or source in ("env:P1_URL", "profile"):
            return base, _url_port(base), source, verified
    return "http://127.0.0.1:%d" % DEFAULT_PORT, DEFAULT_PORT, "default", False


def detect():
    inst = detect_install_dir()
    base, port, source, verified = detect_api(inst)
    has_key = (pathlib.Path.home() / ".config" / "1panel" / "api_key").exists()
    existing = _load_profile()

    prof = {
        "schema": 1,
        "detected_at": run(["date", "-Iseconds"]).strip(),
        "install_dir": inst,
        "api": {
            "base": base,
            "port": port,
            "port_source": source,
            "verified": verified,
            "entrance": detect_entrance(inst),
            "admin": detect_admin(inst),
        },
        "openresty": detect_app_port("openresty", inst),
        "certs": detect_certs(inst),
        "websites": detect_websites(inst),
        "credential": detect_credential_state(),
        "ready": bool(has_key),
        "notes": [],
    }

    if source in ("profile", "env:P1_URL"):
        prof["notes"].append(
            "api.base 来自 %s（非实时探测）；端口变更后请用 P1_URL 覆盖或重新探测" % source)
    if not verified:
        prof["notes"].append(
            "%s 未通过 1Panel HTTP 指纹校验：可能端口变更、服务未启动，或被 IP 白名单/安全入口拦截"
            % base)

    if not inst:
        prof["notes"].append("未找到 1Panel 安装目录（/opt/1panel 等），可能使用了自定义路径")
    if not has_key:
        prof["notes"].append(
            "缺少 API Key：需在面板 UI（设置 → API 接口）创建独立 Key，"
            "白名单含 127.0.0.1，然后写入 ~/.config/1panel/api_key 与 api_key_id"
        )

    # 非 root 读不到 root 所有的 DB：沿用已有 profile 的快照，避免 --write 清空有用信息。
    unreadable = [db for db in (_core_db(inst), _agent_db(inst))
                  if db and _db_state(db) == "unreadable"]
    if unreadable:
        old_api = existing.get("api") or {}
        prof["api"]["entrance"] = prof["api"]["entrance"] or old_api.get("entrance") or ""
        prof["api"]["admin"] = prof["api"]["admin"] or old_api.get("admin") or ""
        prof["openresty"] = prof["openresty"] or existing.get("openresty")
        prof["certs"] = prof["certs"] or (existing.get("certs") or [])
        prof["websites"] = prof["websites"] or (existing.get("websites") or [])
        prof["notes"].append(
            "无法读取 %s（多为非 root 运行）：entrance/admin/openresty/certs/websites 在探测为空时沿用已有 profile 快照"
            % ", ".join(unreadable)
        )

    fragment_hint = os.path.join(inst, "www", "conf.d") if inst else ""
    if fragment_hint and pathlib.Path(fragment_hint).is_dir():
        prof["notes"].append(
            "站点 vhost 目录：%s（生成物，只应由 API 改写）" % fragment_hint
        )
    return prof


def main():
    args = sys.argv[1:]
    prof = detect()
    if "--write" in args:
        if PROFILE.exists() and "--force" not in args:
            print("profile 已存在：%s（加 --force 覆盖）" % PROFILE, file=sys.stderr)
            print(json.dumps(prof, ensure_ascii=False, indent=2))
            return 1
        PROFILE.parent.mkdir(parents=True, exist_ok=True)
        PROFILE.write_text(json.dumps(prof, ensure_ascii=False, indent=2))
        os.chmod(PROFILE, 0o600)
        # 写盘成功后回填状态，避免输出里 credential.profile 仍是探测时的旧值
        prof["credential"]["profile"] = True
        print("已写入 %s" % PROFILE, file=sys.stderr)
    print(json.dumps(prof, ensure_ascii=False, indent=2))
    return 0 if prof["ready"] else 2


if __name__ == "__main__":
    sys.exit(main())
