# -*- coding: utf-8 -*-
"""Chrome を複数の Claude セッションで順番に使うための印（~/.claude/chrome_lock.json）。

2026-10-07 本人の OK で全リポ共通の決まりにした（~/.claude/CLAUDE.md「Chrome を複数のセッションで使うとき」）。
同じ Chrome の同じ窓をいくつものセッション（と本人）が使う。隠れたタブは処理が進まない（スクショ・写真の一覧・X の動画の準備・
Studio の画面の操作）ので、使う前に印を書き、終わったら消す。印があれば、書いたセッションに SendMessage で一言送って待つ。

使い方:
  python chrome_lock.py status                                   # 今の印（無ければ「空き」）
  python chrome_lock.py take <セッション名> <何を> <分> [<タブの題>]   # 印を書く（他の人の新しい印があれば書かずに止まる）
  python chrome_lock.py release <セッション名>                     # 自分の印を消す
  python chrome_lock.py take ... --force                         # 古い印（見込み＋15分を過ぎた）を、書いた人に一言送った後で上書き
終了コード: 0＝空き・取れた・消せた／3＝使用中（待つ）／2＝使い方の誤り
"""
from __future__ import annotations

import datetime as dt
import json
import sys
from pathlib import Path

LOCK = Path.home() / ".claude" / "chrome_lock.json"
GRACE_MIN = 15          # 見込みの分を過ぎてから、古いと見なすまでの余裕


def now() -> dt.datetime:
    return dt.datetime.now().astimezone()


def read() -> dict | None:
    try:
        return json.loads(LOCK.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None


def is_stale(d: dict) -> bool:
    try:
        since = dt.datetime.fromisoformat(d["since"])
        return now() > since + dt.timedelta(minutes=int(d.get("minutes", 30)) + GRACE_MIN)
    except (KeyError, ValueError, TypeError):
        return True


def show(d: dict) -> str:
    since = dt.datetime.fromisoformat(d["since"]).strftime("%H:%M")
    return (f"使用中: {d.get('who')}（{d.get('what')}・{since} から {d.get('minutes')} 分の見込み"
            + (f"・タブ「{d['tab']}」" if d.get("tab") else "") + ("・古い印＝見込み＋15分を過ぎた" if is_stale(d) else "") + "）")


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__)
        return 2
    cmd, args = argv[0], [a for a in argv[1:] if a != "--force"]
    force = "--force" in argv
    d = read()
    if cmd == "status":
        print(show(d) if d else "空き")
        return 3 if d and not is_stale(d) else 0
    if cmd == "take":
        if len(args) < 3:
            print(__doc__)
            return 2
        who, what, minutes = args[0], args[1], int(args[2])
        tab = args[3] if len(args) > 3 else ""
        if d and d.get("who") != who and not (force and is_stale(d)):
            print(show(d) + " ＝ 書いたセッションに SendMessage で一言送って待つ" + ("（古い印なので、一言送った後なら --force で上書きしてよい）" if is_stale(d) else ""))
            return 3
        LOCK.parent.mkdir(parents=True, exist_ok=True)
        LOCK.write_text(json.dumps({"who": who, "what": what, "tab": tab, "since": now().isoformat(timespec="seconds"),
                                    "minutes": minutes}, ensure_ascii=False, indent=1), encoding="utf-8")
        print(f"取った: {who}（{what}・{minutes} 分の見込み）")
        return 0
    if cmd == "release":
        if not args:
            print(__doc__)
            return 2
        if d and d.get("who") != args[0]:
            print(show(d) + " ＝ 自分の印ではないので消さない")
            return 3
        if LOCK.exists():
            LOCK.unlink()
        print("消した（空き）")
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
