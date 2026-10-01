#!/usr/bin/env python3
"""Slack へ「投稿役（ボット）」の名前で投稿する、全リポ共通の道具。

なぜ要るか:
    Claude の Slack 接続（コネクタ）で投稿すると、送り主が本人の名前になり、
    本人が自分で書いた返事と見分けにくい。投稿役（Slack アプリのボット）から出せば、
    送り主は投稿役の名前になり、本人の書き込みと分かれる。
    読む（返事を確かめる）のは、これまでどおりコネクタで行う。

鍵（ボットのトークン）の置き場:
    この PC の Windows 資格情報マネージャー（汎用資格情報「claude-slack-bot」）。
    リポジトリには書かない（このリポは公開）。環境変数 SLACK_BOT_TOKEN があればそちらを優先する。
    作り方と戻し方は同じフォルダの README.md。

使い方:
    # 鍵をしまう（Slack の画面で鍵をコピーしてから。鍵は画面に出さない）
    python post.py --store-token-from-clipboard

    # つながるか確かめる（投稿はしない）
    python post.py --check

    # 投稿する（本文は UTF-8 のファイルで渡す。コマンドに直接書くと文字化けしやすい）
    python post.py --channel C0XXXXXXXXX --name "表示名" --file message.txt
    python post.py --channel C0XXXXXXXXX --name "表示名" --file reply.txt --thread-ts 1790000000.000000

    # 送らずに中身だけ確かめる
    python post.py --channel C0XXXXXXXXX --name "表示名" --file message.txt --dry-run

    # 自己テスト（ネットにつながない）
    python post.py --self-test

出力:
    投稿できたら、その投稿の番号（ts）を 1 行目に出す。スレッドに返信するときは、この番号を --thread-ts に渡す。

Slack アプリに要る権限（Bot Token Scopes）:
    chat:write            … 投稿する
    chat:write.customize  … チャンネルごとに表示名（--name）を変える
非公開チャンネルには、先に投稿役を招く（チャンネルで /invite @投稿役の名前）。
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request

API = "https://slack.com/api/"
CRED_TARGET = "claude-slack-bot"
TOKEN_PREFIX = "xoxb-"

# Markdown の番号リスト（1. 2. …）は、Slack に送ると項目の間の空行が消える（2026-10-01 実測）。
NUMBERED_LIST = re.compile(r"^\s*\d+\.\s")


# ---------------------------------------------------------------- 資格情報マネージャー

def _cred_api():
    import ctypes
    from ctypes import wintypes

    class CREDENTIAL(ctypes.Structure):
        _fields_ = [
            ("Flags", wintypes.DWORD),
            ("Type", wintypes.DWORD),
            ("TargetName", wintypes.LPWSTR),
            ("Comment", wintypes.LPWSTR),
            ("LastWritten", wintypes.FILETIME),
            ("CredentialBlobSize", wintypes.DWORD),
            ("CredentialBlob", ctypes.POINTER(ctypes.c_ubyte)),
            ("Persist", wintypes.DWORD),
            ("AttributeCount", wintypes.DWORD),
            ("Attributes", ctypes.c_void_p),
            ("TargetAlias", wintypes.LPWSTR),
            ("UserName", wintypes.LPWSTR),
        ]

    advapi32 = ctypes.WinDLL("advapi32", use_last_error=True)
    advapi32.CredWriteW.argtypes = [ctypes.POINTER(CREDENTIAL), wintypes.DWORD]
    advapi32.CredWriteW.restype = wintypes.BOOL
    advapi32.CredReadW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
                                   ctypes.POINTER(ctypes.POINTER(CREDENTIAL))]
    advapi32.CredReadW.restype = wintypes.BOOL
    advapi32.CredDeleteW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD]
    advapi32.CredDeleteW.restype = wintypes.BOOL
    advapi32.CredFree.argtypes = [ctypes.c_void_p]
    return ctypes, CREDENTIAL, advapi32


CRED_TYPE_GENERIC = 1
CRED_PERSIST_LOCAL_MACHINE = 2


def cred_write(target: str, secret: str, user: str = "slack-bot") -> None:
    ctypes, CREDENTIAL, advapi32 = _cred_api()
    blob = secret.encode("utf-16-le")
    buf = (ctypes.c_ubyte * len(blob)).from_buffer_copy(blob)
    cred = CREDENTIAL()
    cred.Type = CRED_TYPE_GENERIC
    cred.TargetName = target
    cred.CredentialBlobSize = len(blob)
    cred.CredentialBlob = ctypes.cast(buf, ctypes.POINTER(ctypes.c_ubyte))
    cred.Persist = CRED_PERSIST_LOCAL_MACHINE
    cred.UserName = user
    if not advapi32.CredWriteW(ctypes.byref(cred), 0):
        raise OSError(ctypes.get_last_error(), "資格情報マネージャーへ書き込めませんでした")


def cred_read(target: str) -> str | None:
    ctypes, CREDENTIAL, advapi32 = _cred_api()
    pcred = ctypes.POINTER(CREDENTIAL)()
    if not advapi32.CredReadW(target, CRED_TYPE_GENERIC, 0, ctypes.byref(pcred)):
        return None
    try:
        size = pcred.contents.CredentialBlobSize
        raw = ctypes.string_at(pcred.contents.CredentialBlob, size)
        return raw.decode("utf-16-le")
    finally:
        advapi32.CredFree(pcred)


def cred_delete(target: str) -> bool:
    _, _, advapi32 = _cred_api()
    return bool(advapi32.CredDeleteW(target, CRED_TYPE_GENERIC, 0))


# ---------------------------------------------------------------- 鍵

def mask(token: str) -> str:
    if len(token) <= 10:
        return "*" * len(token)
    return token[:5] + "…" + token[-4:]


def load_token() -> str:
    token = os.environ.get("SLACK_BOT_TOKEN", "").strip()
    if token:
        return token
    if os.name == "nt":
        token = (cred_read(CRED_TARGET) or "").strip()
        if token:
            return token
    raise SystemExit(
        "鍵（ボットのトークン）が見つかりません。README.md の手順で "
        "`python post.py --store-token-from-clipboard` を実行してください。"
    )


def read_clipboard() -> str:
    out = subprocess.run(
        ["powershell.exe", "-NoProfile", "-Command", "Get-Clipboard -Raw"],
        capture_output=True, text=True, encoding="utf-8", errors="replace", check=False,
    )
    return (out.stdout or "").strip()


def clear_clipboard() -> None:
    subprocess.run(["powershell.exe", "-NoProfile", "-Command", "Set-Clipboard -Value ' '"],
                   capture_output=True, check=False)


def store_token_from_clipboard() -> int:
    token = read_clipboard()
    if not token.startswith(TOKEN_PREFIX):
        print(f"[NG] クリップボードの中身が鍵の形（{TOKEN_PREFIX}…）ではありません。"
              "Slack の画面で「Bot User OAuth Token」をコピーしてから、もう一度実行してください。")
        return 1
    cred_write(CRED_TARGET, token)
    if cred_read(CRED_TARGET) != token:
        print("[NG] しまった鍵を読み戻せませんでした。")
        return 1
    clear_clipboard()
    print(f"[OK] 鍵をしまいました（{mask(token)}・置き場＝資格情報マネージャーの「{CRED_TARGET}」）。"
          "クリップボードは空にしました。")
    return 0


# ---------------------------------------------------------------- Slack

def api_call(method: str, token: str, payload: dict, timeout: float = 20.0) -> dict:
    req = urllib.request.Request(
        API + method,
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        headers={"Authorization": f"Bearer {token}",
                 "Content-Type": "application/json; charset=utf-8"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as res:
            return json.loads(res.read().decode("utf-8"))
    except urllib.error.URLError as e:
        return {"ok": False, "error": f"network: {e.reason}"}


HINTS = {
    "not_in_channel": "投稿役がチャンネルにいません。そのチャンネルで /invite @投稿役の名前 を打ってください。",
    "channel_not_found": "チャンネルの番号が違うか、投稿役が招かれていません（非公開チャンネルは招待が要ります）。",
    "missing_scope": "Slack アプリの権限が足りません。README.md の手順 2 の権限を足し、入れ直して（Reinstall）ください。",
    "invalid_auth": "鍵が違います。Slack の画面で鍵をコピーし直し、--store-token-from-clipboard をやり直してください。",
    "token_revoked": "鍵が無効になっています。Slack アプリを入れ直し、新しい鍵をしまい直してください。",
}


def build_payload(channel: str, text: str, name: str | None, icon: str | None,
                  thread_ts: str | None) -> dict:
    payload = {"channel": channel, "text": text, "mrkdwn": True,
               "unfurl_links": False, "unfurl_media": False}
    if name:
        payload["username"] = name
    if icon:
        payload["icon_emoji"] = icon if icon.startswith(":") else f":{icon}:"
    if thread_ts:
        payload["thread_ts"] = thread_ts
    return payload


def lint(text: str) -> list[str]:
    warns = []
    for i, line in enumerate(text.splitlines(), 1):
        if NUMBERED_LIST.match(line):
            warns.append(f"{i} 行目: 「1.」形式の番号は Slack で空行が消えます。①② や ・ で書いてください。")
    if len(text) > 3500:
        warns.append(f"本文が {len(text)} 文字あります。長い投稿は途中で折りたたまれます。スレッドに分けてください。")
    return warns


def post(args) -> int:
    if args.file:
        with open(args.file, encoding="utf-8") as f:
            text = f.read().strip()
    elif args.text:
        text = args.text.strip()
    else:
        text = sys.stdin.read().strip()
    if not text:
        print("[NG] 本文が空です。")
        return 1
    for w in lint(text):
        print("[注意] " + w)
    if args.post_at:
        return schedule(args, text)
    payload = build_payload(args.channel, text, args.name, args.icon, args.thread_ts)
    if args.dry_run:
        shown = dict(payload)
        print("[下見] 送りません。送る中身:")
        print(json.dumps(shown, ensure_ascii=False, indent=2))
        return 0
    res = api_call("chat.postMessage", load_token(), payload)
    if not res.get("ok"):
        err = res.get("error", "?")
        print(f"[NG] 投稿できませんでした: {err}")
        if err in HINTS:
            print("     " + HINTS[err])
        return 1
    print(res.get("ts", ""))
    print(f"[OK] 投稿しました（チャンネル {res.get('channel')}・番号 {res.get('ts')}）")
    return 0


def parse_post_at(value: str) -> int:
    """「2026-10-02 18:00」（この PC の時刻＝日本時間）か、エポック秒を受け取り、エポック秒を返す。"""
    import datetime as _dt
    v = value.strip()
    if v.isdigit():
        return int(v)
    for fmt in ("%Y-%m-%d %H:%M", "%Y-%m-%dT%H:%M", "%Y/%m/%d %H:%M"):
        try:
            return int(_dt.datetime.strptime(v, fmt).timestamp())
        except ValueError:
            pass
    raise ValueError(f"予約の時刻の書き方が違います: {value}（例: 2026-10-02 18:00）")


def schedule(args, text: str) -> int:
    # 予約投稿（chat.scheduleMessage）。送り主はアプリの名前で出る（予約では表示名を変えられない）。
    import time as _time
    try:
        post_at = parse_post_at(args.post_at)
    except ValueError as e:
        print(f"[NG] {e}")
        return 1
    if post_at <= _time.time() + 60:
        print("[NG] 予約の時刻は、いまより 1 分以上あとにしてください。")
        return 1
    payload = {"channel": args.channel, "text": text, "post_at": post_at,
               "unfurl_links": False, "unfurl_media": False}
    if args.thread_ts:
        payload["thread_ts"] = args.thread_ts
    if args.dry_run:
        print("[下見] 予約しません。予約する中身:")
        print(json.dumps(payload, ensure_ascii=False, indent=2))
        return 0
    res = api_call("chat.scheduleMessage", load_token(), payload)
    if not res.get("ok"):
        err = res.get("error", "?")
        print(f"[NG] 予約できませんでした: {err}")
        if err in HINTS:
            print("     " + HINTS[err])
        return 1
    print(res.get("scheduled_message_id", ""))
    print(f"[OK] 予約しました（チャンネル {res.get('channel')}・予約番号 {res.get('scheduled_message_id')}・"
          f"時刻 {args.post_at}）")
    return 0


def list_scheduled(channel: str) -> int:
    import datetime as _dt
    res = api_call("chat.scheduledMessages.list", load_token(), {"channel": channel})
    if not res.get("ok"):
        print(f"[NG] 予約の一覧を読めませんでした: {res.get('error', '?')}")
        return 1
    items = res.get("scheduled_messages", [])
    print(f"投稿役が予約している投稿: {len(items)} 件")
    for m in items:
        when = _dt.datetime.fromtimestamp(m.get("post_at", 0)).strftime("%Y-%m-%d %H:%M")
        head = (m.get("text") or "").splitlines()[0][:40] if m.get("text") else ""
        print(f"  {m.get('id')}  {when}  {head}")
    return 0


def delete_scheduled(channel: str, sid: str) -> int:
    res = api_call("chat.deleteScheduledMessage", load_token(),
                   {"channel": channel, "scheduled_message_id": sid})
    if not res.get("ok"):
        print(f"[NG] 予約を取り消せませんでした: {res.get('error', '?')}")
        return 1
    print(f"[OK] 予約を取り消しました（予約番号 {sid}）")
    return 0


def delete(channel: str, ts: str) -> int:
    # 投稿役が出した投稿だけ消せる（chat:write の範囲）。試しの投稿の片付けに使う。
    res = api_call("chat.delete", load_token(), {"channel": channel, "ts": ts})
    if not res.get("ok"):
        err = res.get("error", "?")
        print(f"[NG] 消せませんでした: {err}")
        if err in HINTS:
            print("     " + HINTS[err])
        return 1
    print(f"[OK] 消しました（チャンネル {channel}・番号 {ts}）")
    return 0


def check() -> int:
    token = load_token()
    res = api_call("auth.test", token, {})
    if not res.get("ok"):
        err = res.get("error", "?")
        print(f"[NG] つながりませんでした: {err}")
        if err in HINTS:
            print("     " + HINTS[err])
        return 1
    print(f"[OK] つながりました（鍵 {mask(token)}・投稿役 {res.get('user')}・ワークスペース {res.get('team')}）")
    return 0


# ---------------------------------------------------------------- 自己テスト

def self_test() -> int:
    ok = 0
    ng = 0

    def expect(label, cond):
        nonlocal ok, ng
        if cond:
            ok += 1
            print(f"  [OK] {label}")
        else:
            ng += 1
            print(f"  [NG] {label}")

    p = build_payload("C0TEST", "本文", "表示名", "memo", None)
    expect("表示名が username に入る", p.get("username") == "表示名")
    expect("絵文字名の前後に : が付く", p.get("icon_emoji") == ":memo:")
    expect("スレッド指定なしなら thread_ts を持たない", "thread_ts" not in p)
    p2 = build_payload("C0TEST", "本文", None, None, "1790000000.000001")
    expect("スレッド指定が入る", p2.get("thread_ts") == "1790000000.000001")
    expect("表示名なしなら username を持たない", "username" not in p2)
    expect("リンクの展開をしない", p2.get("unfurl_links") is False)
    expect("番号リストを見つける", len(lint("見出し\n\n1. 一つ目\n2. 二つ目")) == 2)
    expect("①② と ・ は見逃す", lint("①一つ目\n\n②二つ目\n\n・三つ目") == [])
    expect("「2026.10.01」は番号リストと取り違えない", lint("日付 2026.10.01 の件") == [])
    expect("長すぎる本文を知らせる", any("文字あります" in w for w in lint("あ" * 3600)))
    expect("鍵の伏せ字は頭と尻だけ見せる", mask("xoxb-FAKE-FOR-TEST-abcdef") == "xoxb-…cdef")
    expect("短い文字列は全部伏せる", mask("abc") == "***")
    import datetime as _dt
    expect("予約の時刻をこの PC の時刻で読む",
           parse_post_at("2026-10-02 18:00") == int(_dt.datetime(2026, 10, 2, 18, 0).timestamp()))
    expect("予約の時刻はエポック秒でも読める", parse_post_at("1790000000") == 1790000000)
    try:
        parse_post_at("10月2日")
        expect("書き方の違う時刻を止める", False)
    except ValueError:
        expect("書き方の違う時刻を止める", True)
    if os.name == "nt":
        target = CRED_TARGET + "-selftest"
        secret = "xoxb-selftest-0000"
        try:
            cred_write(target, secret)
            expect("資格情報マネージャーへ書いて読み戻せる", cred_read(target) == secret)
        finally:
            cred_delete(target)
        expect("試験用の資格情報を消した", cred_read(target) is None)
    print(f"自己テスト: {ok} 合格・{ng} 不合格")
    return 0 if ng == 0 else 1


def main() -> int:
    ap = argparse.ArgumentParser(description="Slack へ投稿役の名前で投稿する")
    ap.add_argument("--channel", help="チャンネルの番号（C で始まる）")
    ap.add_argument("--name", help="その投稿で見せる送り主の名前（chat:write.customize が要る）")
    ap.add_argument("--icon", help="送り主の絵文字（例 memo）")
    ap.add_argument("--file", help="本文のファイル（UTF-8）")
    ap.add_argument("--text", help="本文（短いときだけ。長い本文は --file で）")
    ap.add_argument("--thread-ts", help="返信先の投稿の番号")
    ap.add_argument("--dry-run", action="store_true", help="送らずに中身を見せる")
    ap.add_argument("--delete-ts", help="投稿役が出したこの番号の投稿を消す（--channel と一緒に）")
    ap.add_argument("--post-at", help="予約投稿の時刻（例 \"2026-10-02 18:00\"・この PC の時刻）。表示名は変えられずアプリの名前で出る")
    ap.add_argument("--list-scheduled", action="store_true", help="投稿役がそのチャンネルに予約している投稿の一覧")
    ap.add_argument("--delete-scheduled", help="この予約番号の予約を取り消す（--channel と一緒に）")
    ap.add_argument("--check", action="store_true", help="鍵とつながりを確かめる")
    ap.add_argument("--store-token-from-clipboard", action="store_true",
                    help="クリップボードの鍵を資格情報マネージャーへしまう")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()

    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    if args.self_test:
        return self_test()
    if args.store_token_from_clipboard:
        return store_token_from_clipboard()
    if args.check:
        return check()
    if not args.channel:
        ap.error("--channel が要ります")
    if args.delete_ts:
        return delete(args.channel, args.delete_ts)
    if args.list_scheduled:
        return list_scheduled(args.channel)
    if args.delete_scheduled:
        return delete_scheduled(args.channel, args.delete_scheduled)
    return post(args)


if __name__ == "__main__":
    sys.exit(main())
