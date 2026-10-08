# -*- coding: utf-8 -*-
"""Chrome を複数の Claude セッションで順番に使うための印＝lock.py の鍵「chrome」の呼び名（使い方は前と同じ）。

2026-10-07 本人の OK で全リポ共通の決まりにした。同じ Chrome の同じ窓をいくつものセッション（と本人）が使う。
隠れたタブ（最小化した窓も）は処理が進まないので、使う前に印を書き、終わったら消す。
🔁 2026-10-08 ADR-HAR-002 で lock.py に一般化した＝札の置き場は ~/.claude/state/locks/chrome.json
   （前の ~/.claude/chrome_lock.json も読む・取ったら消す）。古い札＝見込み＋5分（前は＋15分）。「譲って」は lock.py request。

使い方:
  python chrome_lock.py status
  python chrome_lock.py take <セッション名> <何を> <分> [<タブの題>] [--bg] [--force]
  python chrome_lock.py release <セッション名>
終了コード: 0＝空き・取れた・消せた／3＝使用中（待つ）／2＝使い方の誤り
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import lock  # noqa: E402


def main(argv: list[str]) -> int:
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 2
    cmd, rest = argv[0], argv[1:]
    if cmd in ("status", "take", "release", "request"):
        return lock.main([cmd, "chrome", *rest])
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
