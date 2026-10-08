# -*- coding: utf-8 -*-
"""状態板（~/.claude/state/board.json）＝全セッションに効く「今の状態」を1か所に（ADR-HAR-002 D2・2026-10-08）。

変わる物は決まりの文に書かず、ここに書く。値には必ず「いつ・誰が」を付ける＝古ければ確かめ直す。
例の鍵: drive_d（home_ssd／work_usb／absent）・chrome.front_tab（本人のタブ＝戻す先）・studio_channel・x_account・qgis_map.owner
  python board.py show                         # 全部（古さつき）＋今の印（lock.py）
  python board.py get <鍵>                     # 値だけ（無ければ空・exit 1）
  python board.py set <鍵> <値> --by <名前>     # 書く（鍵は a.b の形で入れ子にできる）
  python board.py del <鍵> --by <名前>
個人の名前・ID・チャンネル名の既定値は公開リポに書かない＝ ~/.claude/state/defaults.json に置く（lock.py が見る）。
"""
from __future__ import annotations

import sys

from _state import STATE, age_min, locked, read_json, stamp, write_json

BOARD = STATE / "board.json"


def _walk(d: dict, key: str, create: bool = False):
    parts = key.split(".")
    for p in parts[:-1]:
        if p not in d or not isinstance(d[p], dict) or "value" in d[p]:
            if not create:
                return None, parts[-1]
            d[p] = {}
        d = d[p]
    return d, parts[-1]


def get(key: str):
    d, last = _walk(read_json(BOARD, {}), key)
    v = (d or {}).get(last)
    return v.get("value") if isinstance(v, dict) and "value" in v else None


def set_(key: str, value, by: str) -> None:
    with locked(BOARD):
        data = read_json(BOARD, {})
        d, last = _walk(data, key, create=True)
        d[last] = {"value": value, "at": stamp(), "by": by}
        write_json(BOARD, data)


def delete(key: str, by: str) -> None:
    with locked(BOARD):
        data = read_json(BOARD, {})
        d, last = _walk(data, key)
        if d and last in d:
            del d[last]
            write_json(BOARD, data)


def _lines(d: dict, prefix: str = ""):
    for k, v in sorted(d.items()):
        if isinstance(v, dict) and "value" in v:
            a = age_min(v.get("at", ""))
            old = "（古い＝確かめ直す）" if a > 12 * 60 else ""
            yield f"  {prefix}{k} = {v['value']}  ← {v.get('by', '?')}・{a:.0f}分前{old}"
        elif isinstance(v, dict):
            yield from _lines(v, f"{prefix}{k}.")


def show() -> str:
    out = ["=== 状態板（~/.claude/state/board.json）==="]
    out += list(_lines(read_json(BOARD, {}))) or ["  （まだ何も無い）"]
    try:
        import lock
        out.append(lock.status_text())
    except Exception as e:  # noqa: BLE001
        out.append(f"  （印は読めなかった: {e}）")
    return "\n".join(out)


def main(argv: list[str]) -> int:
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 2
    by = argv[argv.index("--by") + 1] if "--by" in argv else ""
    args = [a for i, a in enumerate(argv) if a != "--by" and (i == 0 or argv[i - 1] != "--by")]
    cmd = args[0]
    if cmd == "show":
        print(show())
        return 0
    if cmd == "get" and len(args) == 2:
        v = get(args[1])
        print("" if v is None else v)
        return 0 if v is not None else 1
    if cmd in ("set", "del") and not by:
        print("--by <自分のセッション名> が要る（誰が書いたかを残す）")
        return 2
    if cmd == "set" and len(args) >= 3:
        set_(args[1], " ".join(args[2:]), by)
        print(f"書いた: {args[1]} = {' '.join(args[2:])}")
        return 0
    if cmd == "del" and len(args) == 2:
        delete(args[1], by)
        print(f"消した: {args[1]}")
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
