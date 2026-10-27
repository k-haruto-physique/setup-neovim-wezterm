# claude/ — Claude Code statusLine

Claude Code 入力欄の真上に出る 2 段ステータスラインの**正本一式**。
（2026-06-18 に旧独立リポ `Repositories/statusline` を本リポへ合体・退役。以降はここが唯一の正本。表示レイヤーは 2026-05-21 に WezTerm addon から Claude Code 内蔵 `statusLine` へ移管済。）

## ファイル

| ファイル | 用途 |
|---|---|
| `statusline.ps1` | **正本スクリプト**（`statusLine.command` から呼ばれる）。`~/.claude/statusline.ps1` へ配置（現状は symlink 切れの実体コピー＝ハッシュ一致。次に編集したら再リンク要 → backlog W1） |
| `statusline-spec.md` | **設計仕様**（カラーパレット / アイコン / 数値セマンティクス / データソース / 既知の罠 / 変遷ログ / 技術的負債） |
| `CHANGELOG.md` | 修正履歴（2026-06-15 stdin StreamReader 化バグ修正ほか） |
| `chrome_lock.py` | **Chrome の順番の印**（2026-10-07〜）。🔁 2026-10-08 から `lock.py` の鍵 `chrome` の呼び名（使い方は同じ・札は `~/.claude/state/locks/chrome.json`・古い札＝見込み＋5分） |
| `lock.py` | **印（ロック）の一般形**（2026-10-08〜・セッション運用の見直し）。1つしか無い物（Chrome・Studio のチャンネル・X のアカウント・QGIS・USB への書き込み・作品の版）を順番に使う。`take`／`release`／`status`／`request --urgent`。札＝`~/.claude/state/locks/<鍵>.json` |
| `board.py` | **状態板**（2026-10-08〜）。全セッションに効く「今の状態」（D: の正体・本人のタブ・Studio のチャンネルなど）を値・時刻・書いた人つきで1か所に。`show`／`get`／`set --by`。中身＝`~/.claude/state/board.json` |
| `claims.py` | **返事の担当印**（2026-10-08〜）。本人の返事（スレッド・直下・リアクション・チャット）に動く前に、その返事が指す親の投稿で印を取る＝受け口と端末が二重に動かない。受け口が落とした物（`failed`）だけを端末が拾う。中身＝`~/.claude/state/claims.json` |
| `drive_identity.py` | **D: の見分け**（2026-10-08〜）。家の SSD（`D:/YouTube` と `D:/Videos` の両方）／仕事の USB（ボリューム名＝`~/.claude/state/drives.json`）／無い。結果を状態板の `drive_d` に書く。道具からは `identify()` |
| `session-snapshot.ps1` | **開いている会話の控え**（2026-10-14〜）。ログオンタスク `Claude Session Snapshot`（登録＝`register-session-snapshot-task.ps1`・管理者不要・画面なし）が 2 分おきに、生きている対話セッションの会話 ID・フォルダ・名前を `~/.claude/state/open-sessions.json` に書く。再起動の後の最初の 1 回で前の控えを `open-sessions.prev.json` へ。フォルダごとの前回は `session-history.json`。troubleshooting #32 |
| `restore-sessions.ps1` | **再起動の前の会話を開き直す**（`restore` の本体）。prev を一覧にして `claude --resume` を 1 タブ 2×2 で開く。もう開いている会話は飛ばす。`c`／`-Continue` で、作業中だった会話にだけ続きを頼む |
| `session-common.ps1` | 上の 2 本と `powershell/profile.ps1` の `cc`／`cn`／知らせ が使う共通部品（`.key` には触らない・pwsh 7 と 5.1 の両方で読める） |
| `_state.py`・`test_state_tools.py` | 上の4本の共通部品（排他つきの読み書き）と確かめ（2つのプロセスが同時に取りに来たら片方だけ取れる・`python claude/test_state_tools.py`） |

**起動時の1画面の配線**（2026-10-08〜・本人 OK）: `~/.claude/settings.json` の `hooks.SessionStart` に1本＝`{"matcher": "startup|resume|compact", "hooks": [{"type": "command", "command": "python \"<このリポ>/claude/session_brief.py\""}]}`。全リポ（受け口の `claude -p` も）で起動時に状態板・印・受け口が落とした返事・他リポの依頼・本人待ちが出る。設定は `~/.claude/state/brief.json`（`{"hub": "<ハブのフォルダ>", "routes": ["~/.claude/slack-routes.json", …]}`）。PC を作り直したら、この1本を足して brief.json を置く。

**会話の記憶の知らせ**（2026-10-27〜・本人 GO）: `context_guard.py` を `hooks.PostToolUse` に1本＝`{"matcher": "*", "hooks": [{"type": "command", "command": "python \"<このリポ>/claude/context_guard.py\"", "timeout": 5}]}`。会話の記憶（コンテキスト）の使用率が 60% と 70% を初めて超えた時に1回ずつ、Claude に「控えを書く」と知らせる（50% 未満に下がる＝要約のあとで印を戻す）。使用率はフックに渡らないので、`statusline.ps1` が `~/.claude/state/ctx/<session_id>.json` に書いた値を読む（statusLine の無い `claude -p` では何もしない）。確かめ＝`python claude/context_guard.py selftest` で `RESULT: OK`。**戻し方**＝`~/.claude/settings.json` の `hooks.PostToolUse` のこの1本を消す（`statusline.ps1` の書き出しは残しても害なし・`~/.claude/state/ctx/` は消してよい）。

**既定のモデル**（2026-10-28〜・本人「Sonnetでいいよ」「Pro*5 を1週間…もつようなセッティング」）: `~/.claude/settings.json` の `"model"` を `"opus"` → `"sonnet"`（effort は `modelSettings` の `claude-sonnet-5-5`＝high のまま）。重い設計や込み入った調べ物だけ、そのセッションで `/model opus` に切り替える。**戻し方**＝`"model": "opus"` に戻す（起動中のセッションは `/model` で切り替わる）。無人実行のモデルは各リポの `run_*.ps1` の `--model`（life は全部 sonnet）。

`~/.claude/state/` は PC の中だけの機械の一時情報（git に入れない・控え不要）。`drives.json`・`defaults.json`（Studio・X の既定）は個人の名前が入るので、このリポには書かず PC を作り直したら手で置く（中身の形は各スクリプトの説明）。決まり（いつ使うか）は `~/.claude/rules/core-shared.md`・`core-slack.md`。

## アーキテクチャ

```
Claude Code が JSON を stdin に流す
  → statusline.ps1 がパース
  → 最大 4 行を stdout に出力（縦積み・空行は落とす）
  → Claude Code が入力欄の上に描画
```

更新トリガー（公式仕様）: 新規アシスタント応答ごと / `/compact` 完了時 / パーミッションモード変更時 / vim モードトグル時（300ms デバウンス）。詳細仕様は `statusline-spec.md`。

## 既知の制約

- **コンテキスト残量**は Claude Code stdin 専用値のため外部からは取得不可。
- **週間使用制限残量**は ccusage では取れず、Anthropic 非公開 OAuth (`/api/oauth/usage`) が必要。

## 参考

- [ohugonnot/claude-code-statusline](https://github.com/ohugonnot/claude-code-statusline) — UI デザイン参考
- [ccusage](https://github.com/ryoppippi/ccusage) — 使用データ取得 CLI
