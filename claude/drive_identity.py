# -*- coding: utf-8 -*-
"""D: が「家の SSD」か「仕事の USB」か「無い」かを1か所で見分ける（ADR-HAR-002 D2・2026-10-08）。

起きていたこと: 家の SSD が抜けている間に仕事の USB が D: になっていた（2026-10-01）＝「D: がある」だけで家と決めると、私用の物を
仕事の USB に書いてしまう。見分けが4か所（YouTube・life・仕事のリポの道具）に別々にあった＝ここ1本に寄せる。
  家の SSD ＝ D:/YouTube と D:/Videos の**両方**がある
  仕事の USB ＝ ボリュームの名前が ~/.claude/state/drives.json の work_usb_labels のどれか（名前は公開リポに書かない）
  python drive_identity.py            # home_ssd／work_usb／absent／unknown を1行で出し、board の drive_d に書く
  python drive_identity.py --quiet    # 書くだけ（終了コードで見る）
  from drive_identity import identify  # 道具から使う＝ identify() -> "home_ssd" など
終了コード: 0＝home_ssd／10＝work_usb／11＝absent／12＝unknown（家の目印が無い・仕事の名前でもない＝書かない）
"""
from __future__ import annotations

import ctypes
import sys
from pathlib import Path

from _state import STATE, read_json

DRIVE = "D:\\"
CODES = {"home_ssd": 0, "work_usb": 10, "absent": 11, "unknown": 12}


def volume_label(root: str = DRIVE) -> str:
    buf = ctypes.create_unicode_buffer(261)
    ok = ctypes.windll.kernel32.GetVolumeInformationW(ctypes.c_wchar_p(root), buf, 261, None, None, None, None, 0)
    return buf.value if ok else ""


def identify(root: str = DRIVE) -> str:
    r = Path(root)
    if not r.exists():
        return "absent"
    if (r / "YouTube").is_dir() and (r / "Videos").is_dir():
        return "home_ssd"
    labels = read_json(STATE / "drives.json", {}).get("work_usb_labels", [])
    lab = volume_label(root)
    if lab and lab in labels:
        return "work_usb"
    return "unknown"


def main(argv: list[str]) -> int:
    who = argv[argv.index("--by") + 1] if "--by" in argv else "drive_identity"
    ident = identify()
    try:
        import board
        board.set_("drive_d", ident, who)
    except Exception as e:  # noqa: BLE001
        print(f"（board に書けなかった: {e}）", file=sys.stderr)
    if "--quiet" not in argv:
        tip = {"home_ssd": "家の SSD＝控えを書いてよい", "work_usb": "仕事の USB＝私用の物を書かない",
               "absent": "D: は無い＝控えは書かない（C: にも代わりに書かない）",
               "unknown": "見分けられない＝書かない（家の目印も仕事の名前も無い）"}[ident]
        print(f"D: = {ident}（{tip}）")
    return CODES[ident]


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
