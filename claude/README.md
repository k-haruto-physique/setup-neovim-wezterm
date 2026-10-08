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
| `_state.py`・`test_state_tools.py` | 上の4本の共通部品（排他つきの読み書き）と確かめ（2つのプロセスが同時に取りに来たら片方だけ取れる・`python claude/test_state_tools.py`） |

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
