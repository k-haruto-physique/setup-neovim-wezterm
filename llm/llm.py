#!/usr/bin/env python3
"""この PC の GPU で動く小さいローカル LLM を、どのリポのセッションからも Bash で呼ぶ道具。

なぜ要るか:
    長い文字起こし・JSON・明細を Claude に丸ごと読ませる前に、手元で下読み・抜き出し・分類をさせる
    （プランの使用量を食わない）。機密の物を外へ出さずに扱う（-o でファイルに書けば、Claude は中身を見ない）。
    賢さは Claude の数段下＝計算・事実の断定・公開する言葉の確定・privacy の最終判断はさせない（当たり付けまで）。

しくみ:
    呼ばれた時だけ、見張り役（この道具の --serve）が裏で llama.cpp の llama-server を立てる（窓は出さない）。
    SLEEP_IDLE 秒使われないとモデルを GPU から降ろし、見張り役がサーバーごと終わらせる＝使っていない時は
    メモリも VRAM も食わない（次に呼ばれたらまた立つ。約 5〜10 秒）。サーバーは PC に 1 個だけ・127.0.0.1 だけ。
    置き場は %LOCALAPPDATA%\\llm（bin＝llama.cpp・models＝モデル・server.log・usage.jsonl）。リポの外。
    モデルを選んだ理由と測った数字は同じフォルダの README.md。

使い方:
    python llm.py --install                       # llama.cpp とモデルを落として確かめる（PC を作り直した時も）
    python llm.py "3行で要約して" -f talk.txt      # ファイルを読ませて答えを画面に
    python llm.py "店名を分類して" -f - < shops.txt # 標準入力から
    python llm.py "要約して" -f secret.txt -o out.txt  # 答えはファイルだけに（画面には件数だけ）
    python llm.py "…" -f x.json --json             # 答えを JSON に縛る
    python llm.py --model 4b "…" -f talk.txt       # 取りこぼしが困る当たり付けだけ 4B（遅い・VRAM ぎりぎり）
    python llm.py --status                        # 動いているか・どのモデルか・メモリ・VRAM
    python llm.py --stop                          # サーバーを止める
    python llm.py --self-test                     # ネットにつながない自己テスト

終了コード: 0 成功 / 2 使い方の誤り / 3 VRAM が足りない・入力が長すぎる / 4 サーバーが立たない・応答の誤り
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import secrets
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
import zipfile
from pathlib import Path

HOME = Path(os.environ.get("LOCALAPPDATA", str(Path.home()))) / "llm"
BIN = HOME / "bin"
MODELS = HOME / "models"
LOG = HOME / "server.log"
USAGE = HOME / "usage.jsonl"
KEY = HOME / "api-key.txt"        # この PC の中だけの合言葉（ブラウザのページから勝手に使われないように）
STARTING = HOME / "starting.lock"  # 2 つのセッションが同時に立てないように

PORT = int(os.environ.get("LLM_PORT", "8090"))
URL = f"http://127.0.0.1:{PORT}"
SLEEP_IDLE = int(os.environ.get("LLM_SLEEP_IDLE", "300"))   # 秒。使われないとモデルを降ろしてサーバーを終える

LLAMA_BUILD = "b11617"   # CUDA 12.4 版（ドライバ R576 で動く。13.x 版は R580 以上が要る）
LLAMA_ZIPS = {
    f"llama-{LLAMA_BUILD}-bin-win-cuda-12.4-x64.zip":
        "46d94e8676933a0eb0ad8c80ba1935001c193ccd745ae8372a90678675366dfb",
    "cudart-llama-bin-win-cuda-12.4-x64.zip":
        "8c79a9b226de4b3cacfd1f83d24f962d0773be79f1e7b75c6af4ded7e32ae1d6",
}

# VRAM に全部載る物だけ（一部が CPU に回ると RAM を食って 20 倍遅くなる＝README.md「モデルの選び方」）
MODELS_TABLE = {
    "2b": {   # 既定。長い JSON・文字起こしの抜き出しが確か・速い・VRAM に 1GB 余る
        "file": "Qwen3.5-2B-Q8_0.gguf",
        "url": "https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/main/Qwen3.5-2B-Q8_0.gguf",
        "sha256": "1b04acba824817554f4ce23639bc8495ff70453b8fcb047900c731521021f2c1",
        "ctx": 32768, "need_vram_mb": 2500,
    },
    "4b": {   # 当たり付けの取りこぼしが少ない。ただし速さは半分・VRAM の残りは 0.4GB（ブラウザが重いと立たない）
        "file": "Qwen3.5-4B-UD-IQ3_XXS.gguf",
        "url": "https://huggingface.co/unsloth/Qwen3.5-4B-GGUF/resolve/main/Qwen3.5-4B-UD-IQ3_XXS.gguf",
        "sha256": "00aab66a2359a9afc52f0ab757e61f9be1656e6fcaba8468bd95579a8b2cbc40",
        "ctx": 32768, "need_vram_mb": 2850,
    },
}
DEFAULT_MODEL = os.environ.get("LLM_MODEL", "2b")

SERVER_ARGS = [
    "--host", "127.0.0.1", "--port", str(PORT),
    "-ngl", "all", "-np", "1", "-fa", "on", "-ctk", "q8_0", "-ctv", "q8_0", "-ub", "256",
    "-cram", "0",                 # プロンプトの控えを RAM に溜めない（既定は最大 8GiB）
    "--reasoning", "off",         # 考える過程を出さない（--think で 1 回だけ入れられる）
    "--sleep-idle-seconds", str(SLEEP_IDLE),
    "--no-ui", "--no-slots",      # 画面と、処理中の中身が見える窓口を出さない
    "--cors-origins", "localhost", "--no-cors-credentials",
]

CREATE_NO_WINDOW = 0x08000000
CREATE_NEW_PROCESS_GROUP = 0x00000200
CREATE_BREAKAWAY_FROM_JOB = 0x01000000


def err(msg: str) -> None:
    print(msg, file=sys.stderr)


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def download(url: str, dest: Path, want: str) -> None:
    if dest.exists() and sha256(dest) == want:
        print(f"ある: {dest.name}")
        return
    tmp = dest.with_suffix(dest.suffix + ".part")
    print(f"落とす: {dest.name}", flush=True)
    with urllib.request.urlopen(url, timeout=60) as r, open(tmp, "wb") as f:
        shutil.copyfileobj(r, f, 1 << 20)
    got = sha256(tmp)
    if got != want:
        tmp.unlink()
        raise SystemExit(f"チェックサムが合わない: {dest.name}（{got}）")
    tmp.replace(dest)


def version() -> str:
    exe = BIN / "llama-server.exe"
    if not exe.exists():
        return ""
    r = subprocess.run([str(exe), "--version"], capture_output=True, text=True, encoding="utf-8",
                       errors="replace", creationflags=CREATE_NO_WINDOW)
    return r.stdout + r.stderr


def install(names: list[str]) -> int:
    MODELS.mkdir(parents=True, exist_ok=True)
    if f"build {LLAMA_BUILD.lstrip('b')}" not in version():
        stop()
        dl = HOME / "dl"
        dl.mkdir(exist_ok=True)
        base = f"https://github.com/ggml-org/llama.cpp/releases/download/{LLAMA_BUILD}/"
        for name, want in LLAMA_ZIPS.items():
            download(base + name, dl / name, want)
        if BIN.exists():
            shutil.rmtree(BIN)
        for name in LLAMA_ZIPS:
            with zipfile.ZipFile(dl / name) as z:
                z.extractall(BIN)
        shutil.rmtree(dl, ignore_errors=True)
    for n in names:
        m = MODELS_TABLE[n]
        download(m["url"], MODELS / m["file"], m["sha256"])
    print(version().strip().splitlines()[0] if version() else "llama-server が動かない")
    return 0


def api_key() -> str:
    if not KEY.exists():
        HOME.mkdir(parents=True, exist_ok=True)
        KEY.write_text(secrets.token_hex(24), encoding="utf-8")
    return KEY.read_text(encoding="utf-8").strip()


def request(path: str, body: dict | None = None, timeout: float = 5):
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(URL + path, data=data, headers={
        "Content-Type": "application/json", "Authorization": f"Bearer {api_key()}"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.load(r)


def alive() -> bool:
    try:
        return request("/health").get("status") == "ok"
    except Exception:
        return False


def running_model() -> str | None:
    try:
        path = request("/props").get("model_path") or ""
    except Exception:
        return None
    return next((n for n, m in MODELS_TABLE.items() if Path(path).name == m["file"]), Path(path).name or None)


def free_vram_mb() -> int | None:
    try:
        out = subprocess.run(["nvidia-smi", "--query-gpu=memory.total,memory.used",
                              "--format=csv,noheader,nounits"], capture_output=True, text=True,
                             creationflags=CREATE_NO_WINDOW).stdout
        total, used = (int(x) for x in out.split(",")[:2])
        return total - used
    except Exception:
        return None


def serve(name: str) -> int:
    """見張り役（start が裏で立てる）。llama-server を子に持ち、眠ったら（＝SLEEP_IDLE 秒使われなかったら）終わらせる。"""
    m = MODELS_TABLE[name]
    cmd = [str(BIN / "llama-server.exe"), "-m", str(MODELS / m["file"]), "-c", str(m["ctx"]),
           "--api-key-file", str(KEY), *SERVER_ARGS]
    with open(LOG, "w", encoding="utf-8") as log:
        child = subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL,
                                 creationflags=CREATE_NO_WINDOW)
        while child.poll() is None:
            time.sleep(10)
            try:
                if request("/props").get("is_sleeping"):
                    child.terminate()
                    child.wait(timeout=30)
            except Exception:
                pass
    return 0


def start(name: str, force: bool = False) -> int:
    if alive():
        return 0
    m = MODELS_TABLE[name]
    if not (BIN / "llama-server.exe").exists() or not (MODELS / m["file"]).exists():
        err(f"まだ入っていない＝ python llm.py --install{'' if name == '2b' else ' --model ' + name}")
        return 4
    HOME.mkdir(parents=True, exist_ok=True)
    try:
        fd = os.open(STARTING, os.O_CREAT | os.O_EXCL | os.O_WRONLY)   # 先に取った 1 人だけが立てる
        os.close(fd)
        mine = True
    except FileExistsError:
        mine = time.time() - STARTING.stat().st_mtime > 200   # 前の人が途中で落ちた古い札は取り直す
        if mine:
            STARTING.touch()
    try:
        if mine:
            free = free_vram_mb()
            if free is not None and free < m["need_vram_mb"] and not force:
                err(f"VRAM が足りない（空き {free}MB・要る {m['need_vram_mb']}MB）。一部を CPU に回すと RAM を食って"
                    "ひどく遅くなるので立てない。動画やブラウザのタブを閉じてからもう一度（--force で無理に立てる）")
                return 3
            api_key()
            cmd = [sys.executable, str(Path(__file__).resolve()), "--serve", "--model", name]
            flags = CREATE_NO_WINDOW | CREATE_NEW_PROCESS_GROUP
            kw = dict(stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, cwd=str(HOME))
            try:
                subprocess.Popen(cmd, creationflags=flags | CREATE_BREAKAWAY_FROM_JOB, **kw)
            except OSError:
                subprocess.Popen(cmd, creationflags=flags, **kw)
        for _ in range(180):
            if alive():
                return 0
            time.sleep(1)
        err(f"サーバーが 180 秒で立たなかった＝ {LOG} の終わりを見る")
        return 4
    finally:
        if mine:
            STARTING.unlink(missing_ok=True)


def pids(image: str) -> list[int]:
    out = subprocess.run(["tasklist", "/FI", f"IMAGENAME eq {image}", "/FO", "CSV", "/NH"],
                         capture_output=True, text=True, creationflags=CREATE_NO_WINDOW).stdout
    return [int(line.split(",")[1].strip('"')) for line in out.splitlines() if line.startswith(f'"{image}')]


def stop() -> int:
    found = pids("llama-server.exe")
    for pid in found:
        subprocess.run(["taskkill", "/PID", str(pid), "/F"], capture_output=True, creationflags=CREATE_NO_WINDOW)
    print(f"止めた: {len(found)} 個" if found else "動いていない")   # 見張り役は子が終わると自分で終わる
    return 0


def status() -> int:
    found = pids("llama-server.exe")
    if not found:
        print(f"止まっている（呼べば立ち上がる）・VRAM 空き {free_vram_mb()}MB")
        return 0
    ps = ("Get-Process -Id " + ",".join(map(str, found)) +
          " | ForEach-Object { 'Private {0}MB' -f [int]($_.PrivateMemorySize64/1MB) }")
    mem = subprocess.run(["powershell", "-NoProfile", "-Command", ps], capture_output=True, text=True,
                         creationflags=CREATE_NO_WINDOW).stdout.strip()
    try:
        state = "眠りに入った（まもなく終わる）" if request("/props").get("is_sleeping") else "起きている"
    except Exception:
        state = "立ち上げ中か応答しない"
    print(f"{running_model()}・{state}・{mem}・VRAM 空き {free_vram_mb()}MB")
    return 0


def build_prompt(instruction: str, files: list[str]) -> str:
    parts = [instruction]
    for f in files:
        if f == "-":
            text = sys.stdin.buffer.read().decode("utf-8", errors="replace")
            name = "標準入力"
        else:
            text = Path(f).read_text(encoding="utf-8", errors="replace")
            name = Path(f).name
        parts.append(f"--- {name} ---\n{text}")
    return "\n\n".join(parts)


def ask(args) -> int:
    rc = start(args.model, args.force)
    if rc:
        return rc
    now = running_model()
    if now and now != args.model:
        err(f"いま {now} で動いているので、そのまま {now} で答える（{args.model} にしたい時は、使い終わってから --stop）")
    body = {
        "messages": ([{"role": "system", "content": args.system}] if args.system else [])
        + [{"role": "user", "content": build_prompt(args.instruction, args.file)}],
        "temperature": args.temp, "top_p": 0.9, "max_tokens": args.max_tokens,
        "chat_template_kwargs": {"enable_thinking": bool(args.think)},
    }
    if args.json:
        body["response_format"] = {"type": "json_object"}
    t = time.time()
    try:
        try:
            d = request("/v1/chat/completions", body, timeout=1800)
        except (urllib.error.URLError, ConnectionError) as e:
            if isinstance(e, urllib.error.HTTPError):
                raise
            # 眠って終わる所と行き違った＝立て直して 1 回だけやり直す
            if start(args.model, args.force):
                raise
            d = request("/v1/chat/completions", body, timeout=1800)
    except urllib.error.HTTPError as e:
        msg = e.read().decode("utf-8", errors="replace")
        if "context" in msg and ("exceed" in msg or "too long" in msg):
            err(f"入力が長すぎる（上限 {MODELS_TABLE[now or args.model]['ctx']} トークン）＝分けて渡す")
            return 3
        err(f"サーバーの誤り {e.code}")   # 入力の中身を画面に出さないため、本文は出さない
        return 4
    except Exception as e:
        err(f"サーバーにつながらない: {type(e).__name__}")
        return 4
    text = d["choices"][0]["message"].get("content") or ""
    u = d.get("usage", {})
    with open(USAGE, "a", encoding="utf-8") as f:   # 中身は残さない（量と時間だけ）＝効き目を測るため
        f.write(json.dumps({"at": time.strftime("%Y-%m-%dT%H:%M:%S"), "cwd": Path.cwd().name, "model": now,
                            "in": u.get("prompt_tokens"), "out": u.get("completion_tokens"),
                            "sec": round(time.time() - t, 1), "to_file": bool(args.output)}, ensure_ascii=False) + "\n")
    if args.output:
        Path(args.output).write_text(text, encoding="utf-8")
        print(f"書いた: {args.output}（{len(text)} 文字・入力 {u.get('prompt_tokens')} トークン）")
    else:
        print(text)
    return 0


def self_test() -> int:
    assert build_prompt("指示", []) == "指示"
    HOME.mkdir(parents=True, exist_ok=True)
    p = HOME / "_selftest.txt"
    p.write_text("中身\n", encoding="utf-8")
    try:
        assert build_prompt("指示", [str(p)]) == "指示\n\n--- _selftest.txt ---\n中身\n"
    finally:
        p.unlink()
    assert "127.0.0.1" in SERVER_ARGS and "-cram" in SERVER_ARGS and "--no-slots" in SERVER_ARGS
    assert DEFAULT_MODEL in MODELS_TABLE
    print("self-test ok")
    return 0


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description="ローカル LLM（この PC の GPU）に聞く")
    ap.add_argument("instruction", nargs="?", help="指示（短く。材料は -f で）")
    ap.add_argument("-f", "--file", action="append", default=[], help="材料のファイル（UTF-8・何個でも・- は標準入力）")
    ap.add_argument("-o", "--output", help="答えをこのファイルに書き、画面には出さない（機密の時）")
    ap.add_argument("--model", choices=sorted(MODELS_TABLE), default=DEFAULT_MODEL)
    ap.add_argument("--system", default="必ず日本語で答える（固有名詞・コードは原文のまま）。", help="システムの指示（既定＝日本語で答える）")
    ap.add_argument("--json", action="store_true", help="答えを JSON に縛る")
    ap.add_argument("--think", action="store_true", help="考えてから答えさせる（遅い）")
    ap.add_argument("--temp", type=float, default=0.2)
    ap.add_argument("--max-tokens", type=int, default=2048)
    ap.add_argument("--force", action="store_true", help="VRAM が足りなくても立てる（遅く・RAM を食う）")
    ap.add_argument("--install", action="store_true", help="llama.cpp と --model のモデルを入れる")
    ap.add_argument("--status", action="store_true")
    ap.add_argument("--start", action="store_true")
    ap.add_argument("--stop", action="store_true")
    ap.add_argument("--serve", action="store_true", help=argparse.SUPPRESS)
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.install:
        return install([args.model])
    if args.serve:
        return serve(args.model)
    if args.self_test:
        return self_test()
    if args.status:
        return status()
    if args.stop:
        return stop()
    if args.start:
        return start(args.model, args.force)
    if not args.instruction:
        ap.print_usage(sys.stderr)
        return 2
    return ask(args)


if __name__ == "__main__":
    sys.exit(main())
