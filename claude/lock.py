# -*- coding: utf-8 -*-
"""印（ロック）＝1つしか無い物を、いくつものセッションと本人が順番に使うための札（ADR-HAR-002 D2・2026-10-08）。

chrome_lock.py（10/7〜）を一般にした物。札は ~/.claude/state/locks/<鍵>.json。chrome_lock.py は鍵 chrome の呼び名として残る。
鍵の例: chrome（Chrome の窓）・studio（YouTube Studio のチャンネルを切り替えている間）・x（X のアカウントを切り替えている間）・
        qgis_map（正本地図の編集）・qgis_app（QGIS の起動と MCP のポート）・d_drive（USB へ書いている最中＝抜かないで）・
        work:<作品>/<版>（その版を作っている最中）
  python lock.py status [<鍵>]                                   # 今の札（鍵を省くと全部）
  python lock.py take <鍵> <名前> <何を> <分> [<タブの題>] [--bg] [--force]
  python lock.py release <鍵> <名前>
  python lock.py request <鍵> <名前> [--urgent] [<一言>]          # 持っている人に「譲って」を札に書く（SendMessage でも一言）
決まり: 見込みの分＋5分を過ぎ、書いた人が ListAgents で idle なら「古い札」＝一言送ってから --force で上書きしてよい。
        本人に聞く間・長い待ち・上限が近い時は札を返す。studio・x を返す時、board の今の値が既定（~/.claude/state/defaults.json）と違えば警告する。
終了コード: 0＝空き・取れた・返した／3＝使用中（待つ）／2＝使い方の誤り
"""
from __future__ import annotations

import sys
from pathlib import Path

from _state import STATE, age_min, locked, read_json, stamp, write_json

LOCKS = STATE / "locks"
LEGACY = {"chrome": Path.home() / ".claude" / "chrome_lock.json"}   # 10/7〜10/8 の chrome_lock.py の置き場
GRACE_MIN = 5
FLAGS = ("--force", "--bg", "--urgent")


def _path(key: str) -> Path:
    return LOCKS / (key.replace("/", "__").replace(":", "_") + ".json")


def read(key: str) -> dict | None:
    d = read_json(_path(key), None)
    if d is None and key in LEGACY:
        d = read_json(LEGACY[key], None)
    return d


def is_stale(d: dict) -> bool:
    return age_min(d.get("since", "")) > int(d.get("minutes", 10)) + GRACE_MIN


def show(key: str, d: dict) -> str:
    since = d.get("since", "")[11:16]
    s = (f"[{key}] 使用中: {d.get('who')}（{d.get('what')}・{since} から {d.get('minutes')} 分の見込み"
         + (f"・タブ「{d['tab']}」" if d.get("tab") else "")
         + ("" if key != "chrome" else ("・前に出す" if d.get("front", True) else "・前に出さない"))
         + ("・古い札＝見込み＋5分を過ぎた" if is_stale(d) else "") + "）")
    if d.get("request"):
        r = d["request"]
        s += f"\n    ↳ {'🔴急ぎ ' if r.get('urgent') else ''}譲ってほしい: {r.get('who')}（{r.get('at', '')[11:16]}）{r.get('note', '')}"
    return s


def keys() -> list[str]:
    ks = {p.stem.replace("__", "/") for p in LOCKS.glob("*.json")} if LOCKS.is_dir() else set()
    ks |= {k for k, p in LEGACY.items() if p.exists()}
    return sorted(ks)


def status_text(key: str | None = None) -> str:
    ks = [key] if key else keys()
    lines = [show(k, d) for k in ks if (d := read(k))]
    return "\n".join(["=== 印（lock.py）==="] + (lines or ["  空き（だれも持っていない）"]))


def _warn_on_release(key: str) -> str:
    if key not in ("studio", "x"):
        return ""
    try:
        import board
        cur = board.get({"studio": "studio_channel", "x": "x_account"}[key])
    except Exception:  # noqa: BLE001
        return ""
    want = read_json(STATE / "defaults.json", {}).get({"studio": "studio_channel", "x": "x_account"}[key])
    if want and cur and cur != want:
        return f"\n⚠️ 返す前に戻す: 今の{'チャンネル' if key == 'studio' else 'アカウント'}は「{cur}」・既定は「{want}」"
    return ""


def main(argv: list[str]) -> int:
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 2
    cmd = argv[0]
    args = [a for a in argv[1:] if a not in FLAGS]
    force, bg, urgent = "--force" in argv, "--bg" in argv, "--urgent" in argv
    if cmd == "status":
        print(status_text(args[0] if args else None))
        d = read(args[0]) if args else None
        return 3 if d and not is_stale(d) else 0
    if cmd == "take" and len(args) >= 4:
        key, who, what = args[0], args[1], args[2]
        minutes = 10 if args[3] in ("-", "") else int(args[3])
        tab = args[4] if len(args) > 4 else ""
        with locked(_path(key)):
            d = read(key)
            if d and d.get("who") != who and not (force and is_stale(d)):
                print(show(key, d) + "\n＝ 書いたセッションに SendMessage で一言送って待つ"
                      + ("（古い札なので、一言送った後なら --force で上書きしてよい）" if is_stale(d) else "")
                      + "\n  急ぎなら: lock.py request " + key + f" {who} --urgent")
                return 3
            write_json(_path(key), {"who": who, "what": what, "tab": tab, "front": not bg,
                                    "since": stamp(), "minutes": minutes})
            if key in LEGACY and LEGACY[key].exists():
                LEGACY[key].unlink()
        print(f"取った: [{key}] {who}（{what}・{minutes} 分の見込み）")
        return 0
    if cmd == "release" and len(args) >= 2:
        key, who = args[0], args[1]
        with locked(_path(key)):
            d = read(key)
            if d and d.get("who") != who:
                print(show(key, d) + "\n＝ 自分の札ではないので消さない")
                return 3
            for p in (_path(key), LEGACY.get(key)):
                if p and p.exists():
                    p.unlink()
        print(f"返した: [{key}]（空き）" + _warn_on_release(key))
        return 0
    if cmd == "request" and len(args) >= 2:
        key, who, note = args[0], args[1], " ".join(args[2:])
        with locked(_path(key)):
            d = read(key)
            if not d:
                print(f"[{key}] は空き＝そのまま take してよい")
                return 0
            d["request"] = {"who": who, "urgent": urgent, "note": note, "at": stamp()}
            write_json(_path(key), d)
        print(f"書いた: [{key}] の持ち主（{d.get('who')}）へ「譲って」{'（急ぎ）' if urgent else ''}＝SendMessage でも一言送ること")
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
