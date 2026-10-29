"""会話の記憶（コンテキスト）が要約（圧縮）の入りうる量に近づいたら、Claude に控えを書くよう知らせる（PostToolUse のフック）。

使用率はフックには渡らないので、statusline.ps1 が ~/.claude/state/ctx/<session_id>.json に書いた {used, size} を読み、トークン数に直す。
割合でなくトークン数で見る（2026-10-29）: 100万の窓でも自動の要約は 22万〜98万の間のどこかで入り（直近3日の45回）、
6割（60万）で鳴らす作りでは 45回中34回が鳴る前に要約された。要約の直後は 8万〜15万に戻る。
- 18万以上（初回）: 区切りのよい所で NEXT・メモ・控えを書く
- 21万以上（初回）: 今すぐ控えを書く
- そのあと10万進むごと: 控えを足す（いつ要約が入るか決まらないため）
- 16万未満に下がったら（要約のあと）知らせの印を戻す＝次の山でまた知らせる
窓が小さい（20万など）時は、それぞれ 6割・7割・5割と小さいほうを使う。
statusLine の無い無人実行（claude -p）では値の書き手がいない＝何もしない。
python context_guard.py selftest で陽性対照（100万と20万の窓で、段ごとに1回ずつ鳴り、2回目は黙る）。
"""
import json
import os
import sys
import tempfile
import time
from pathlib import Path

CTX_DIR = Path(os.environ.get("USERPROFILE", str(Path.home()))) / ".claude" / "state" / "ctx"
STALE_SEC = 3 * 24 * 3600  # 3日より古い値の写しは掃除する

FIRST = 180_000  # 要約の直後（最大15万）より上・いちばん早い要約（22万）より下
NOW = 210_000
STEP = 100_000
RESET = 160_000
DEFAULT_SIZE = 1_000_000

MSG = {
    "first": "🧠 会話の記憶が約{man}万トークン。自動の要約は早いと22万前後で入る。区切りのよい所で、今の作業の控え（NEXT・CHECKPOINTS・memory・作業メモ）を書いておく。要約が入っても続きが分かるように。",
    "now": "🧠 会話の記憶が約{man}万トークン。いつ要約が入ってもおかしくない。途中でもよいので今すぐ控えを書く（やりかけの作業・決まった事・本人の言葉・次の一手・持っている印と開いたタブ）。",
    "more": "🧠 会話の記憶が約{man}万トークン（前の知らせから10万進んだ）。そのあとに決まった事・やりかけの事を控えに足す。",
}


def levels(size: int) -> tuple[int, int, int]:
    return min(FIRST, int(size * 0.6)), min(NOW, int(size * 0.7)), min(RESET, int(size * 0.5))


def stage(tokens: int, size: int) -> tuple[int, str]:
    """今の量に当たるいちばん上の段（トークン数）と、その知らせの種類。段に届いていなければ (0, "")。"""
    first, now, _ = levels(size)
    if tokens >= now:
        lv = now + (tokens - now) // STEP * STEP
        return lv, ("now" if lv == now else "more")
    if tokens >= first:
        return first, "first"
    return 0, ""


def check(ctx_dir: Path, sid: str) -> str:
    f = ctx_dir / f"{sid}.json"
    if not f.exists():
        return ""
    try:
        d = json.loads(f.read_text(encoding="utf-8-sig"))
        size = int(d.get("size") or DEFAULT_SIZE)
        tokens = int(float(d["used"]) * size / 100)
    except Exception:
        return ""
    mark = ctx_dir / f"{sid}.warned"
    last = 0
    if mark.exists():
        nums = [int(x) for x in mark.read_text(encoding="utf-8").split() if x.isdigit()]
        last = max(nums) if nums and max(nums) >= 1000 else 0  # 旧形式（"60 70"＝割合）は読み捨てる
    if tokens < levels(size)[2]:
        if mark.exists():
            mark.unlink(missing_ok=True)
        return ""
    lv, kind = stage(tokens, size)
    if not kind or lv <= last:
        return ""
    mark.write_text(str(lv), encoding="utf-8")
    return MSG[kind].format(man=round(tokens / 10_000))


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
    ok = True

    def at(u, size=DEFAULT_SIZE, sid="t"):
        (d / f"{sid}.json").write_text(json.dumps({"used": u, "size": size}), encoding="utf-8")
        return check(d, sid)

    # 100万の窓（used は割合＝1% が1万）
    ok &= at(12) == ""  # 要約の直後
    ok &= "区切り" in at(18)
    ok &= at(19) == ""
    ok &= "今すぐ" in at(21)
    ok &= at(25) == ""
    ok &= "10万進んだ" in at(31)
    ok &= at(33) == ""
    ok &= "10万進んだ" in at(52)  # 段を飛ばしても1回だけ
    ok &= at(55) == ""
    ok &= at(12) == ""  # 要約のあと＝印を戻す
    ok &= "区切り" in at(19)
    # 20万の窓＝6割・7割・5割
    ok &= at(40, 200_000, "s") == ""
    ok &= "区切り" in at(61, 200_000, "s")
    ok &= "今すぐ" in at(72, 200_000, "s")
    ok &= at(95, 200_000, "s") == ""
    ok &= at(20, 200_000, "s") == ""
    ok &= "区切り" in at(62, 200_000, "s")
    # 旧形式の印（"60 70"）が残っていても、新しい段で鳴る
    (d / "o.warned").write_text("60 70", encoding="utf-8")
    ok &= "区切り" in at(18, sid="o")
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
