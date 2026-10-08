# -*- coding: utf-8 -*-
"""セッション間で共有する状態ファイル（~/.claude/state/）の読み書きの共通部品。

lock.py・board.py・claims.py・drive_identity.py が使う。どれも「複数の Claude セッションが同時に叩いても壊れない」ことが要る:
- 書くときは同じフォルダの一時ファイルに書いてから置き換える（途中で止まっても半端なファイルが残らない）
- 読み・書きの間は <ファイル>.lock を排他で作って持つ（2つが同時に取りに来たら片方だけが勝つ）
個人の名前・ID・チャンネル名はここに書かない（公開リポ）。中身は ~/.claude/state/ の JSON にだけ入る。
"""
from __future__ import annotations

import contextlib
import datetime as dt
import json
import os
import sys
import time
from pathlib import Path

STATE = Path(os.environ.get("CLAUDE_STATE_DIR", Path.home() / ".claude" / "state"))

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception:  # noqa: BLE001
        pass


def now() -> dt.datetime:
    return dt.datetime.now().astimezone()


def stamp() -> str:
    return now().isoformat(timespec="seconds")


def age_min(iso: str) -> float:
    try:
        return (now() - dt.datetime.fromisoformat(iso)).total_seconds() / 60
    except (TypeError, ValueError):
        return 1e9


@contextlib.contextmanager
def locked(path: Path, wait_s: float = 5.0, stale_s: float = 30.0):
    """<path>.lock を排他で作る。取れるまで待つ（最大 wait_s）。stale_s より古い .lock は前の人が落ちた跡として消す。"""
    lk = path.with_name(path.name + ".lock")
    lk.parent.mkdir(parents=True, exist_ok=True)
    t0 = time.monotonic()
    while True:
        try:
            fd = os.open(str(lk), os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            os.write(fd, str(os.getpid()).encode())
            os.close(fd)
            break
        except FileExistsError:
            try:
                if time.time() - lk.stat().st_mtime > stale_s:
                    lk.unlink()
                    continue
            except OSError:
                pass
            if time.monotonic() - t0 > wait_s:
                raise TimeoutError(f"{lk} を取れなかった（他のセッションが書いている）")
            time.sleep(0.05)
    try:
        yield
    finally:
        try:
            lk.unlink()
        except OSError:
            pass


def read_json(path: Path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return default


def write_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    os.replace(tmp, path)
