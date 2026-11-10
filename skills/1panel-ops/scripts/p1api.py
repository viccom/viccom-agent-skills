#!/usr/bin/env python3
"""1Panel v2 REST API 签名客户端（可移植版）。

用法:
  p1api.py GET  /api/v2/websites/list
  p1api.py POST /api/v2/websites/search '{"page":1,"pageSize":20,...}'
  p1api.py detect              # 探测本机 1Panel 参数（同 p1detect.py）

配置解析顺序（优先级从高到低）:
  1. 环境变量  P1_URL / P1_SECRET / P1_KEY_ID
  2. profile   ~/.config/1panel/profile.json  （由 p1detect.py --write 生成）
  3. 凭据文件  ~/.config/1panel/api_key、api_key_id
  4. 自动探测  监听端口 / 已知默认值

签名算法（1Panel core/app/auth/api_auth.go）:
  hmac-sha256 : 1Panel-Token = hex(HMAC-SHA256(key, "1panel:" + ts))
  md5          : 1Panel-Token = md5("1panel" + key + ts)
推荐 hmac-sha256。

1Panel 的 HTTP 状态码恒为 200，错误看响应体 code 字段；本脚本在 code != 200 时非零退出。
"""
import hashlib
import hmac
import json
import os
import pathlib
import sys
import time
import urllib.error
import urllib.request

CONF_DIR = pathlib.Path.home() / ".config" / "1panel"
PROFILE = CONF_DIR / "profile.json"
# 1Panel 默认端口：v2 新装为 9999，常见改动为 5000 / 8090 / 10086
FALLBACK_PORTS = (9999, 5000, 8090, 10086)


def _read_text(name):
    p = CONF_DIR / name
    return p.read_text().strip() if p.exists() else ""


def _load_profile():
    if PROFILE.exists():
        try:
            return json.loads(PROFILE.read_text())
        except (json.JSONDecodeError, OSError):
            return {}
    return {}


def _detect_port():
    """探测 1panel-core 监听端口；失败返回 None。"""
    try:
        import re
        import subprocess
        out = subprocess.run(["ss", "-tlnp"], capture_output=True, text=True, timeout=5).stdout
        for line in out.splitlines():
            if "1panel-core" in line:
                m = re.search(r":(\d+)\s", line)
                if m:
                    return int(m.group(1))
    except (OSError, subprocess.SubprocessError):
        pass
    return None


def resolve_base():
    env = os.environ.get("P1_URL")
    if env:
        return env.rstrip("/")
    prof = _load_profile()
    base = (prof.get("api") or {}).get("base")
    if base:
        return base.rstrip("/")
    port = _detect_port()
    if port:
        return "http://127.0.0.1:%d" % port
    for p in FALLBACK_PORTS:
        return "http://127.0.0.1:%d" % p
    return "http://127.0.0.1:9999"


def resolve_credential():
    secret = os.environ.get("P1_SECRET") or _read_text("api_key")
    key_id = os.environ.get("P1_KEY_ID") or _read_text("api_key_id")
    return secret, key_id


def sign(secret, ts, version="hmac-sha256"):
    if version in ("md5", "v1"):
        return hashlib.md5(("1panel" + secret + ts).encode()).hexdigest()
    return hmac.new(secret.encode(), ("1panel:" + ts).encode(), hashlib.sha256).hexdigest()


def call(method, path, body=None, version="hmac-sha256", base=None, secret=None, key_id=None):
    base = (base or resolve_base()).rstrip("/")
    if secret is None and key_id is None:
        secret, key_id = resolve_credential()
    secret = secret or ""
    key_id = key_id or ""
    if not secret:
        raise SystemExit(
            "no credential: set P1_SECRET, or run scripts/p1detect.py --write, "
            "or write ~/.config/1panel/api_key"
        )

    ts = str(int(time.time()))
    headers = {
        "Content-Type": "application/json",
        "1Panel-Token": sign(secret, ts, version),
        "1Panel-Timestamp": ts,
        "1Panel-Signature-Version": version,
    }
    if key_id:
        headers["1Panel-Key-ID"] = key_id

    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(base + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=90) as resp:
            raw = resp.read().decode()
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
    except urllib.error.URLError as e:
        raise SystemExit("connection failed (%s): %s" % (base, e))

    # 面板被 IP 白名单/安全入口拦截时返回 HTML 错误页（HTTP 200），显式报出
    head = raw.lstrip()[:64].lower()
    if head.startswith("<!doctype") or head.startswith("<html"):
        snippet = " ".join(raw.split())[:200]
        raise SystemExit("non-JSON response (likely IP/domain block page): %s" % snippet)

    try:
        out = json.loads(raw)
    except json.JSONDecodeError:
        return raw
    if isinstance(out, dict) and out.get("code") not in (200, None):
        raise SystemExit("API error code=%s message=%s" % (out.get("code"), out.get("message")))
    return out


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)

    # 便捷子命令：直接转发给 p1detect.py
    if sys.argv[1] == "detect":
        import subprocess
        here = pathlib.Path(__file__).resolve().parent
        sys.exit(subprocess.call([sys.executable, str(here / "p1detect.py")] + sys.argv[2:]))

    method = sys.argv[1].upper()
    path = sys.argv[2]
    body = json.loads(sys.argv[3]) if len(sys.argv) > 3 else None
    if body is None and method == "POST":
        body = {}  # 1Panel 的 POST 接口都要求 JSON body，空 body 会解析失败
    result = call(method, path, body)
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
