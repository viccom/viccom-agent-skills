#!/usr/bin/env python3
"""探测本机 1Panel 部署参数，生成 profile（JSON）。

用法:
  p1detect.py                 # 探测并打印 JSON
  p1detect.py --write         # 探测并写入 ~/.config/1panel/profile.json
  p1detect.py --write --force # 覆盖已存在的 profile

设计原则:
  - 只读探测，不改任何系统状态
  - 所有输出字段都可被环境变量或 profile 覆盖（见 p1api.py 的 resolve 顺序）
  - 探测失败时给出明确原因，不抛栈
"""
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys

PROFILE = pathlib.Path.home() / ".config" / "1panel" / "profile.json"


def run(cmd, timeout=10):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return r.stdout if r.returncode == 0 else ""
    except (OSError, subprocess.SubprocessError):
        return ""


def detect_install_dir():
    """1Panel 安装根目录。"""
    for d in ("/opt/1panel", "/usr/local/1panel", "/usr/share/1panel"):
        if pathlib.Path(d).is_dir():
            return d
    return ""


def detect_port(install_dir=""):
    """面板 API 端口：优先 systemd 监听，其次数据库，最后默认 9999。"""
    # 1) 从 ss 找 1panel-core 的监听端口
    out = run(["ss", "-tlnp"])
    for line in out.splitlines():
        if "1panel-core" in line:
            m = re.search(r":(\d+)\s", line)
            if m:
                return int(m.group(1))
    # 2) 从数据库读 ServerPort
    core_db = os.path.join(install_dir, "db", "core.db") if install_dir else ""
    if core_db and os.path.exists(core_db):
        port = _sqlite_scalar(core_db, "settings", "value", "key='ServerPort'")
        if port and port.isdigit():
            return int(port)
    return 9999


def _sqlite_scalar(db_path, table, column, where):
    """只读查一个标量；用 sqlite3 CLI 或 python sqlite3，不修改原库。"""
    try:
        import sqlite3
        uri = "file:%s?mode=ro" % db_path
        con = sqlite3.connect(uri, uri=True, timeout=5)
        try:
            row = con.execute("select %s from %s where %s" % (column, table, where)).fetchone()
            return row[0] if row else ""
        finally:
            con.close()
    except Exception:
        return ""


def detect_entrance(install_dir=""):
    core_db = os.path.join(install_dir, "db", "core.db") if install_dir else ""
    if core_db and os.path.exists(core_db):
        v = _sqlite_scalar(core_db, "settings", "value", "key='SecurityEntrance'")
        return v or ""
    return ""


def detect_admin(install_dir=""):
    core_db = os.path.join(install_dir, "db", "core.db") if install_dir else ""
    if core_db and os.path.exists(core_db):
        v = _sqlite_scalar(core_db, "settings", "value", "key='UserName'")
        return v or ""
    return ""


def detect_app_port(app_name="openresty"):
    """从 agent.db 的 app_installs 读应用端口（vhost listen 的依据）。"""
    inst = detect_install_dir()
    agent_db = os.path.join(inst, "db", "agent.db") if inst else ""
    if not (agent_db and os.path.exists(agent_db)):
        return None
    try:
        import sqlite3
        con = sqlite3.connect("file:%s?mode=ro" % agent_db, uri=True, timeout=5)
        try:
            # 应用名随 1Panel 版本可能是 OpenResty/openresty，按小写比较
            row = con.execute(
                "select http_port, https_port from app_installs where lower(name)=lower(?)",
                (app_name,),
            ).fetchone()
            if row:
                return {"http": row[0] or 0, "https": row[1] or 0}
        finally:
            con.close()
    except Exception:
        pass
    return None


def detect_certs():
    """列出证书元信息（不取私钥）。"""
    inst = detect_install_dir()
    agent_db = os.path.join(inst, "db", "agent.db") if inst else ""
    if not (agent_db and os.path.exists(agent_db)):
        return []
    try:
        import sqlite3
        con = sqlite3.connect("file:%s?mode=ro" % agent_db, uri=True, timeout=5)
        try:
            rows = con.execute(
                "select id, primary_domain, provider, status, expire_date "
                "from website_ssls order by id"
            ).fetchall()
            return [
                {"id": r[0], "domain": r[1], "provider": r[2],
                 "status": r[3], "expire": r[4]}
                for r in rows
            ]
        finally:
            con.close()
    except Exception:
        return []


def detect_websites():
    """列出站点（不打印私钥等敏感字段）。"""
    inst = detect_install_dir()
    agent_db = os.path.join(inst, "db", "agent.db") if inst else ""
    if not (agent_db and os.path.exists(agent_db)):
        return []
    try:
        import sqlite3
        con = sqlite3.connect("file:%s?mode=ro" % agent_db, uri=True, timeout=5)
        try:
            rows = con.execute(
                "select w.id, w.alias, w.proxy, w.status, w.website_ssl_id, "
                "(select group_concat(d.domain||':'||d.port, ',') "
                " from website_domains d where d.website_id=w.id) "
                "from websites w order by w.id"
            ).fetchall()
            return [
                {"id": r[0], "alias": r[1], "proxy": r[2], "status": r[3],
                 "sslId": r[4] or 0, "domains": r[5] or ""}
                for r in rows
            ]
        finally:
            con.close()
    except Exception:
        return []


def detect_credential_state():
    conf = pathlib.Path.home() / ".config" / "1panel"
    return {
        "api_key": (conf / "api_key").exists(),
        "api_key_id": (conf / "api_key_id").exists(),
        "profile": (conf / "profile.json").exists(),
    }


def detect():
    inst = detect_install_dir()
    port = detect_port(inst)
    has_key = (pathlib.Path.home() / ".config" / "1panel" / "api_key").exists()

    prof = {
        "schema": 1,
        "detected_at": run(["date", "-Iseconds"]).strip(),
        "install_dir": inst,
        "api": {
            "base": "http://127.0.0.1:%d" % port,
            "port": port,
            "entrance": detect_entrance(inst),
            "admin": detect_admin(inst),
        },
        "openresty": detect_app_port("openresty"),
        "certs": detect_certs(),
        "websites": detect_websites(),
        "credential": detect_credential_state(),
        "ready": bool(has_key),
        "notes": [],
    }

    if not inst:
        prof["notes"].append("未找到 1Panel 安装目录（/opt/1panel 等），可能使用了自定义路径")
    if not has_key:
        prof["notes"].append(
            "缺少 API Key：需在面板 UI（设置 → API 接口）创建独立 Key，"
            "白名单含 127.0.0.1，然后写入 ~/.config/1panel/api_key 与 api_key_id"
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
