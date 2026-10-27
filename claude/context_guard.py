"""会話の記憶（コンテキスト）の使用率が 6割・7割を超えたら、Claude に控えを書くよう1回ずつ知らせる（PostToolUse のフック）。

使用率はフックには渡らないので、statusline.ps1 が ~/.claude/state/ctx/<session_id>.json に書いた値を読む。
- 60% 以上（初回）: 区切りのよい所で NEXT・メモ・控えを書く
- 70% 以上（初回）: 今すぐ控えを書く
- 50% 未満に下がったら（要約のあと）知らせの印を戻す＝次の山でまた知らせる
statusLine の無い無人実行（claude -p）では値の書き手がいない＝何もしない。
python context_guard.py selftest で陽性対照（60・70 で1回ずつ鳴り、2回目は黙る）。
"""
import json
import os
import sys
import tempfile
import time
from pathlib import Path

CTX_DIR = Path(os.environ.get("USERPROFILE", str(Path.home()))) / ".claude" / "state" / "ctx"
STALE_SEC = 3 * 24 * 3600  # 3日より古い値の写しは掃除する

MSG = {
    60: "🧠 会話の記憶が {used}% に達した（6割）。区切りのよい所で、今の作業の控え（NEXT・CHECKPOINTS・memory・作業メモ）を書いておく。要約が入っても続きが分かるように。",
    70: "🧠 会話の記憶が {used}% に達した（7割）。途中でもよいので今すぐ控えを書く（やりかけの作業・決まった事・本人の言葉・次の一手）。",
}


def check(ctx_dir: Path, sid: str) -> str:
    f = ctx_dir / f"{sid}.json"
    if not f.exists():
        return ""
    try:
        used = int(json.loads(f.read_text(encoding="utf-8-sig"))["used"])
    except Exception:
        return ""
    mark = ctx_dir / f"{sid}.warned"
    warned = set()
    if mark.exists():
        warned = {int(x) for x in mark.read_text(encoding="utf-8").split() if x.isdigit()}
    if used < 50 and warned:
        mark.unlink(missing_ok=True)
        return ""
    for th in (70, 60):
        if used >= th and th not in warned:
            warned.update(t for t in (60, 70) if t <= th)
            mark.write_text(" ".join(map(str, sorted(warned))), encoding="utf-8")
            return MSG[th].format(used=used)
    return ""


def sweep(ctx_dir: Path):
    now = time.time()
    for p in ctx_dir.glob("*"):
        try:
            if now - p.stat().st_mtime > STALE_SEC:
                p.unlink()
        except OSError:
            pass


def selftest() -> int:
    d = Path(tempfile.mkdtemp())
    sid = "t"
    ok = True

    def at(u):
        (d / f"{sid}.json").write_text(json.dumps({"used": u}), encoding="utf-8")
        return check(d, sid)

    ok &= at(40) == ""
    ok &= "6割" in at(61)
    ok &= at(65) == ""
    ok &= "7割" in at(72)
    ok &= at(75) == ""
    ok &= at(20) == ""  # 要約のあと＝印を戻す
    ok &= "6割" in at(62)
    print("RESULT: OK" if ok else "RESULT: MISSING")
    return 0 if ok else 1


def main() -> int:
    if len(sys.argv) > 1 and sys.argv[1] == "selftest":
        return selftest()
    try:
        sid = json.load(sys.stdin).get("session_id") or ""
    except Exception:
        return 0
    if not sid or not CTX_DIR.exists():
        return 0
    msg = check(CTX_DIR, sid)
    if msg:
        sys.stdout.reconfigure(encoding="utf-8")
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": msg}}, ensure_ascii=False))
    if int(time.time()) % 50 == 0:
        sweep(CTX_DIR)
    return 0


if __name__ == "__main__":
    sys.exit(main())
