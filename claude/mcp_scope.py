# -*- coding: utf-8 -*-
"""MCP サーバーを「全リポ共通」から「使うリポだけ」に移す・戻す（2026-10-14・troubleshooting #34）。

なぜ: ~/.claude.json の全リポ共通（ユーザー全体）に置いた MCP は、どのリポのセッションでも全部が起動し、
      セッション 1 個あたり 0.3〜0.8GB を食っていた。使うリポの登録（ローカル）に移せば、そのリポでだけ起動する。
しくみ: 移す先は ~/.claude.json の projects[<リポのパス>].mcpServers（`claude mcp add -s local` と同じ所）。
      同じリポが別の書き方（C:/・C:\\・c:/）で何個も載っているので、全部に入れる。
      park＝定義だけ置いて disabledMcpServers に入れる（起動しない。そのリポで /mcp から入れ直せる）。
      鍵・トークン（env の値）は画面に出さない。名前と数だけを出す。
計画（どのサーバーをどのリポに）は ~/.claude/state/mcp-plan.json（リポの名前が入るので公開リポに置かない）:
  {"enable": {"<サーバー>": ["<リポのフォルダ名>", ...]}, "park": {"<サーバー>": [...]}}
  python mcp_scope.py --show            # 今どこに何があるか（名前だけ）
  python mcp_scope.py --apply           # 計画どおりに移す（全リポ共通からは消す）
  python mcp_scope.py --revert          # 全リポ共通に戻す（各リポの登録と park の止めた印を消す）
変えた後に起動したセッションから効く。開いているセッションは開き直すまで前のまま。
"""
from __future__ import annotations

import copy
import json
import os
import shutil
import sys
import time
from pathlib import Path

CONFIG = Path.home() / ".claude.json"
PLAN = Path.home() / ".claude" / "state" / "mcp-plan.json"
DONE = Path.home() / ".claude" / "state" / "mcp-scope-applied.json"   # 移した記録（名前とキーだけ）


def load() -> dict:
    return json.loads(CONFIG.read_text(encoding="utf-8"))


def save(d: dict) -> None:
    tmp = CONFIG.with_name(f"{CONFIG.name}.tmp.mcpscope.{os.getpid()}")
    tmp.write_text(json.dumps(d, indent=2, ensure_ascii=False), encoding="utf-8")
    os.replace(tmp, CONFIG)


def keys_for(d: dict, repo: str) -> list[str]:
    """そのリポを指す projects のキーを全部（書き方の違いを含む）。"""
    want = repo.lower()
    return [k for k in d.get("projects", {}) if k.replace("\\", "/").rstrip("/").split("/")[-1].lower() == want]


def show() -> int:
    d = load()
    print("全リポ共通:", sorted((d.get("mcpServers") or {}).keys()) or "なし")
    rows = {}
    for k, pr in d.get("projects", {}).items():
        local = sorted((pr.get("mcpServers") or {}).keys())
        if not local:
            continue
        off = set(pr.get("disabledMcpServers") or [])
        name = k.replace("\\", "/").rstrip("/").split("/")[-1]
        rows.setdefault(name.lower(), (name, [s + ("（止めてある）" if s in off else "") for s in local]))
    for name, items in sorted(rows.values()):
        print(f"  {name}: {', '.join(items)}")
    return 0


def apply() -> int:
    plan = json.loads(PLAN.read_text(encoding="utf-8"))
    d = load()
    top = d.get("mcpServers") or {}
    record = []
    for kind in ("enable", "park"):
        for server, repos in plan.get(kind, {}).items():
            if server not in top:
                print(f"全リポ共通に無い（もう移した？）: {server}")
                continue
            for repo in repos:
                ks = keys_for(d, repo)
                if not ks:
                    print(f"⚠ ~/.claude.json に無いリポ（一度そこで claude を開くと載る）: {repo}")
                for k in ks:
                    pr = d["projects"][k]
                    pr.setdefault("mcpServers", {})[server] = copy.deepcopy(top[server])
                    added_off = False
                    if kind == "park":
                        off = pr.setdefault("disabledMcpServers", [])
                        if server not in off:
                            off.append(server)
                            added_off = True
                    record.append({"server": server, "key": k, "kind": kind, "added_off": added_off})
    moved = sorted({r["server"] for r in record})
    for s in moved:
        del top[s]
    left = sorted(top)
    bak = CONFIG.with_name(f"{CONFIG.name}.bak-mcpscope-{time.strftime('%Y%m%d')}")
    if not bak.exists():
        shutil.copy2(CONFIG, bak)   # 当てる前の控え（同じ所・中身は画面に出さない）
    save(d)
    DONE.write_text(json.dumps({"at": time.strftime("%Y-%m-%dT%H:%M:%S"), "moved": record}, ensure_ascii=False, indent=1),
                    encoding="utf-8")
    print(f"移した: {', '.join(moved)}（{len(record)} 件のキー）・全リポ共通に残った: {left or 'なし'}")
    return 0


def revert() -> int:
    rec = json.loads(DONE.read_text(encoding="utf-8"))["moved"]
    d = load()
    top = d.setdefault("mcpServers", {})
    for r in rec:
        pr = d.get("projects", {}).get(r["key"])
        if not pr:
            continue
        conf = (pr.get("mcpServers") or {}).pop(r["server"], None)
        if conf is not None and r["server"] not in top:
            top[r["server"]] = conf
        if r.get("added_off") and r["server"] in (pr.get("disabledMcpServers") or []):   # 前からあった印は残す
            pr["disabledMcpServers"].remove(r["server"])
    save(d)
    print("全リポ共通に戻した:", sorted(top))
    return 0


if __name__ == "__main__":
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    arg = sys.argv[1] if len(sys.argv) > 1 else "--show"
    sys.exit({"--show": show, "--apply": apply, "--revert": revert}.get(arg, show)())
