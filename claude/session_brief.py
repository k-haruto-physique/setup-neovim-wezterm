# -*- coding: utf-8 -*-
"""起動時の1画面（ADR-HAR-002 D2・2026-10-08）＝どのリポで起動しても、セッション間の「今」を 40 行以内で出す。

ユーザー階層の SessionStart フック（~/.claude/settings.json）から1本だけ呼ぶ想定。リポは $CLAUDE_PROJECT_DIR（無ければ今のフォルダ）で見分ける。
出す物（どれも無ければ出さない）:
  ① 状態板（D: の正体・本人のタブ・Studio・X など）と今の印（lock.py）
  ② このリポのチャンネルで、受け口が落とした返事（claims.py の failed）
  ③ このリポへの他リポからの依頼（ハブ inbox の未返事）
  ④ 本人待ちの件数（ハブ board/本人待ち.md）と、今日が休みか（~/.claude/state/today.json）
設定（PC の中だけ・公開リポに書かない）: ~/.claude/state/brief.json {"hub": "<ハブのフォルダ>", "routes": ["<slack-routes.json>", ...]}
  python session_brief.py            # 出す（何があっても exit 0＝起動を止めない）
"""
from __future__ import annotations

import datetime as dt
import os
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _state import STATE, read_json  # noqa: E402

LIMIT_LINES = 40


def repo_dir() -> Path:
    return Path(os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()).resolve()


def my_channels(repo: Path, routes: list[str]) -> list[str]:
    chans = []
    for r in routes:
        d = read_json(Path(r).expanduser(), {})
        for cid, v in (d.get("channels") or {}).items():
            try:
                if Path(v.get("repo", "")).resolve() == repo:
                    chans.append(cid)
            except OSError:
                pass
    return chans


def section_board() -> list[str]:
    try:
        import board
        lines = board.show().splitlines()
    except Exception as e:  # noqa: BLE001
        return [f"（状態板を読めなかった: {e}）"]
    lines = [l for l in lines if "まだ何も無い" not in l and "空き（だれも" not in l]
    if lines and lines[-1].startswith("=== 印"):
        lines = lines[:-1]                     # 札が1枚も無ければ見出しも出さない
    if lines == ["=== 状態板（~/.claude/state/board.json）==="]:
        return []
    return lines


def section_claims(chans: list[str]) -> list[str]:
    if not chans:
        return []
    import claims
    rows = claims.listing("failed", chans)
    if not rows:
        return []
    out = [f"=== 🔴 受け口が落とした返事（このリポのチャンネル・{len(rows)} 件＝拾う）==="]
    out += [f"  {r['key']}  ← {r.get('who')}・{r.get('at', '')[5:16]}  {r.get('note', '')}" for r in rows[:6]]
    return out


def section_inbox(hub: Path, repo: Path) -> list[str]:
    hp = hub / "scripts" / "handoff.py"
    if not hp.exists():
        return []
    names = [repo.name]
    try:
        r = subprocess.run([sys.executable, str(hp), "open", *names], capture_output=True, text=True,
                           encoding="utf-8", errors="replace", timeout=20)
    except Exception:  # noqa: BLE001
        return []
    lines = [l for l in (r.stdout or "").splitlines() if l.strip()]
    if not lines or "未返事 0" in lines[0] or "未返事なし" in lines[0]:
        return []
    return [l if len(l) <= 180 else l[:180] + "…" for l in lines[:6]]


def section_waiting(hub: Path) -> list[str]:
    p = hub / "board" / "本人待ち.md"
    try:
        s = p.read_text(encoding="utf-8")
    except OSError:
        return []
    block = s.split("## 開いている", 1)[-1].split("## 閉じた", 1)[0]
    rows = [l for l in block.splitlines() if re.match(r"^\| W-\d+", l)]
    return [f"=== 🙋 本人待ち（ハブ）＝開いている {len(rows)} 件（{', '.join(l.split('|')[1].strip() for l in rows[:6])}）==="] if rows else []


def section_today() -> list[str]:
    t = read_json(STATE / "today.json", {})
    if not t:
        return []
    today = dt.date.today().isoformat()
    if t.get("date") != today:
        return [f"（today.json が古い＝{t.get('date')}・休みかはカレンダー「休日」で確かめる）"]
    return [f"=== 今日 {today}: {t.get('label') or ('休み' if t.get('off') else '勤務日 8:00–16:30＝画面を前に出さない')} ==="]


def main() -> int:
    cfg = read_json(STATE / "brief.json", {})
    hub = Path(cfg.get("hub", "")).expanduser() if cfg.get("hub") else None
    repo = repo_dir()
    out = []
    try:
        out += section_today()
        out += section_board()
        out += section_claims(my_channels(repo, cfg.get("routes", [])))
        if hub:
            out += section_inbox(hub, repo)
            out += section_waiting(hub)
    except Exception as e:  # noqa: BLE001
        out.append(f"（session_brief の途中で止まった: {e}）")
    if out:
        if len(out) > LIMIT_LINES:
            out = out[:LIMIT_LINES - 1] + [f"…（{len(out) - LIMIT_LINES + 1} 行を省略）"]
        print("\n".join(out))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:  # noqa: BLE001
        sys.exit(0)
