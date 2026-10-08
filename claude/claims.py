# -*- coding: utf-8 -*-
"""返事の担当印（~/.claude/state/claims.json）＝本人の返事に「だれが動くか」を1つに決める（ADR-HAR-002 D2・2026-10-08）。

起きていたこと: 同じ返事に Slack の受け口と PC のセッションの両方が動く（10/5・10/6・10/7）／受け口が上限や安全装置で落とした依頼を
だれも拾わない（10/4 に丸1日放置）。
鍵＝「その返事が指す親の投稿」（Claude が出した問い・定期タスクの投稿・本人の直下の依頼）。本人の ok がチャンネル直下のメンションで
来た時も、ok の ts でなく「指している親」で取る（親のスレッドを見ている側と二重にならないため）。返事そのものは --reply に記録する:
  スレッドの返事・直下のメンション＝その ts／リアクション＝reaction:<絵文字>:<ユーザー>／PC のチャット＝chat:<セッション名>
  python claims.py take <ws> <ch> <親ts> <名前> [--reply <id>] [--note <一言>]   # 動く前に。取れなければ他が動いている（exit 3）
  python claims.py done|failed|handed <ws> <ch> <親ts> <名前> [--note <理由>]   # 終わり／落とした（安全装置・上限・エラー）／受信箱へ渡した
  python claims.py list [--state failed] [--ch <ch>...]                          # 端末の見張りは failed だけ拾う
  python claims.py gc                                                            # 7日より古い印を消す
ws＝ワークスペース（private／work）。ch＝チャンネル ID。名前＝自分のセッション名（受け口は listen:<リポ>）。
"""
from __future__ import annotations

import sys

from _state import STATE, age_min, locked, read_json, stamp, write_json

CLAIMS = STATE / "claims.json"
KEEP_DAYS = 7
STATES = ("working", "done", "failed", "handed")


def _key(ws: str, ch: str, ts: str) -> str:
    return f"{ws}:{ch}:{ts}"


def _opt(argv: list[str], name: str) -> str:
    return argv[argv.index(name) + 1] if name in argv and argv.index(name) + 1 < len(argv) else ""


def _pos(argv: list[str]) -> list[str]:
    out, skip = [], False
    for i, a in enumerate(argv):
        if skip:
            skip = False
            continue
        if a in ("--reply", "--note", "--state", "--ch"):
            skip = True
            continue
        out.append(a)
    return out


def take(ws, ch, ts, who, reply="", note="") -> tuple[bool, dict]:
    with locked(CLAIMS):
        data = read_json(CLAIMS, {})
        k = _key(ws, ch, ts)
        cur = data.get(k)
        if cur and cur.get("who") != who and cur.get("state") == "working":
            if reply and reply not in cur.get("replies", []):
                cur.setdefault("replies", []).append(reply)        # 同じ親への2つ目の返事＝持ち主が受ける（記録だけ足す）
                write_json(CLAIMS, data)
            return False, cur
        rec = cur if cur and cur.get("who") == who else {"who": who, "since": stamp(), "replies": []}
        rec.update({"state": "working", "at": stamp(), "ws": ws, "ch": ch, "ts": ts})
        if reply and reply not in rec["replies"]:
            rec["replies"].append(reply)
        if note:
            rec["note"] = note
        data[k] = rec
        write_json(CLAIMS, data)
        return True, rec


def finish(ws, ch, ts, who, state, note="") -> bool:
    with locked(CLAIMS):
        data = read_json(CLAIMS, {})
        k = _key(ws, ch, ts)
        cur = data.get(k)
        if cur and cur.get("who") != who:
            return False
        rec = cur or {"who": who, "since": stamp(), "replies": [], "ws": ws, "ch": ch, "ts": ts}
        rec.update({"state": state, "at": stamp()})
        if note:
            rec["note"] = note
        data[k] = rec
        write_json(CLAIMS, data)
        return True


def listing(state: str = "", chans: list[str] | None = None) -> list[dict]:
    rows = []
    for k, v in read_json(CLAIMS, {}).items():
        if state and v.get("state") != state:
            continue
        if chans and v.get("ch") not in chans:
            continue
        rows.append({"key": k, **v})
    return sorted(rows, key=lambda r: r.get("at", ""))


def gc() -> int:
    with locked(CLAIMS):
        data = read_json(CLAIMS, {})
        old = [k for k, v in data.items() if age_min(v.get("at", "")) > KEEP_DAYS * 24 * 60]
        for k in old:
            del data[k]
        write_json(CLAIMS, data)
        return len(old)


def main(argv: list[str]) -> int:
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 2
    cmd, pos = argv[0], _pos(argv[1:])
    if cmd == "take" and len(pos) == 4:
        ok, rec = take(*pos, reply=_opt(argv, "--reply"), note=_opt(argv, "--note"))
        if ok:
            print(f"取った: {pos[1]} {pos[2]} ← {pos[3]}")
            return 0
        msg = f"他が動いている: {rec.get('who')}（{rec.get('since', '')[11:16]} から・{rec.get('state')}）＝触らない"
        print(msg + ("・この返事は記録に足した" if _opt(argv, "--reply") else ""))
        return 3
    if cmd in ("done", "failed", "handed") and len(pos) == 4:
        if finish(*pos, state=cmd, note=_opt(argv, "--note")):
            print(f"{cmd}: {pos[1]} {pos[2]}")
            return 0
        print("自分の印ではないので書かない")
        return 3
    if cmd == "list":
        chans = [argv[i + 1] for i, a in enumerate(argv) if a == "--ch" and i + 1 < len(argv)]
        rows = listing(_opt(argv, "--state"), chans or None)
        for r in rows:
            print(f"  [{r.get('state')}] {r['key']}  ← {r.get('who')}・{r.get('at', '')[5:16]}  {r.get('note', '')}")
        if not rows:
            print("  （無し）")
        return 0
    if cmd == "gc":
        print(f"消した: {gc()} 件")
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
