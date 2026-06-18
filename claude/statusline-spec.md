# statusline 設計仕様

Claude Code statusLine（`claude/statusline.ps1`）の設計仕様。
（旧独立リポ `Repositories/statusline` の `CLAUDE.md` を 2026-06-18 に本リポへ合体。本リポ root `CLAUDE.md` の自動ロードと衝突しないよう `statusline-spec.md` にリネーム。）

## 正本と実体

正本は本リポの `claude/statusline.ps1`。実体（Claude Code が実行）は `C:\Users\81809\.claude\statusline.ps1`（現状は symlink 切れの実体コピー・正本とハッシュ一致 = backlog W1。次に編集したら手動コピー or 管理者で再リンク）。

WezTerm 側 statusline addon は 2026-05-21 に廃止済み（表示は Claude Code 内蔵 statusLine）。

## 現在の表示仕様(2026-05-21 時点)

Claude Code 入力欄の真上に 2 段表示。

```
◆ Opus 4.7 │ ◈ ctx:58%/1.0M │ ◐ 5h:20% ◑ 7d:75%
▸ ~/Documents/Repositories/statusline  ⎇ master !?
```

- **1 段目**: ランタイム情報(モデル / コンテキスト使用率 / 5h・7d レート使用率)
- **2 段目**: 開発コンテキスト(現在地 / git ブランチ + status)

### カラーパレット (Catppuccin Frappe)

Mocha の公式落ち着き版。長時間視認しても疲れにくい muted トーン。

| 用途 | 色 | hex |
|---|---|---|
| sep / labels / brackets / size 表記 | overlay0 | `#737994` |
| dir, time | blue | `#8caaee` |
| git branch / safe (<50%) | green | `#a6d189` |
| ctx ラベル | teal | `#81c8be` |
| model | mauve | `#ca9ee6` |
| vim / git status symbols | peach | `#ef9f76` |
| warn (50-80%) | yellow | `#e5c890` |
| danger (≥80%) | red | `#e78284` |

### アイコン (Unicode 標準幾何記号 — Nerd Font 不要)

| 項目 | 記号 | コード |
|---|---|---|
| model | ◆ | U+25C6 BLACK DIAMOND |
| ctx | ◈ | U+25C8 |
| 5h | ◐ | U+25D0 |
| 7d | ◑ | U+25D1 |
| dir | ▸ | U+25B8 |
| branch | ⎇ | U+2387 ALTERNATIVE KEY SYMBOL |

### 数値セマンティクス

ctx / 5h / 7d はすべて **使用率(USED %)** 表示で統一(大きいほど危険)。ステージカラーも used に基づく判定:

- `< 50%` 緑(safe)
- `50-80%` 黄(warn)
- `>= 80%` 赤(danger)

### Git status symbols (Starship `$all_status` 準拠)

`=` conflict, `+` staged, `!` modified, `?` untracked, `x` deleted, `v` behind, `^` ahead

着色なし(プレーン)で表示。

## 動作確認方法

```pwsh
# スクリプト単体の出力確認(JSON ダミー)
echo '{"workspace":{"current_dir":"C:\\Users\\81809\\Documents\\Repositories\\statusline"},"model":{"display_name":"Opus 4.7"},"context_window":{"used_percentage":58,"context_window_size":1000000},"rate_limits":{"five_hour":{"used_percentage":20},"seven_day":{"used_percentage":75}}}' | pwsh -NoProfile -NonInteractive -File C:\Users\81809\.claude\statusline.ps1

# Claude Code が実際にスクリプトを呼んでいるかの監視
Get-Content C:\Users\81809\.claude\statusline_debug.log -Tail 5
```

ユニットテストは無い。Claude Code 画面下端の視覚確認 + debug log のエントリ更新が事実上のテスト。

## 既知の罠

### Windows + Git Bash の backslash escape

Claude Code は Windows + Git Bash インストール環境では statusLine コマンドを Git Bash 経由で起動する。`settings.json` の `command` 内の `\` は Git Bash がエスケープとして食って path 解決に失敗 → **エラー無しで silent fail**(debug log にも残らない)。

必ず forward slash で書く:
```json
"command": "pwsh -NoProfile -NonInteractive -File C:/Users/81809/.claude/statusline.ps1"
```

公式ドキュメント (https://code.claude.com/docs/en/statusline → Windows configuration) に記載されている既知の挙動だが、ハマると原因特定が極めて困難。

## アーキテクチャ

`Claude Code が JSON を stdin に流す → statusline.ps1 がパース → 2 行を stdout に出力 → Claude Code が入力欄の上に描画` というシンプル構造。

更新トリガー(公式仕様):
- 新規アシスタント応答ごと
- `/compact` 完了時
- パーミッションモード変更時
- vim モードトグル時
- 300ms デバウンス

## データソース

| 表示項目 | ソース |
|---|---|
| モデル名 | `data.model.display_name` |
| ディレクトリ | `data.workspace.current_dir`(`~` 短縮 + 末尾 10 階層) |
| Git ブランチ / dirty / ahead-behind | `git rev-parse` / `git status --porcelain` / `git rev-list` |
| Context 使用率 | `data.context_window.used_percentage` + `context_window_size` |
| 5h / 7d レート使用率 | `data.rate_limits.{five_hour,seven_day}.used_percentage` |
| Vim mode | `data.vim.mode` |

レート情報は Claude.ai Pro/Max 加入者のみ初回 API 応答後に含まれる。それまでは `rate_limits` フィールド自体が無いのでセグメントは非表示になる(コード側でガード済み)。

## セッション変遷ログ (2026-05-19 〜 2026-05-21)

1. **初期**: WezTerm 側で ccusage + git + statusline_input.json 経由で画面下端に表示。Claude Code 内蔵 statusLine は非表示問題で使えなかった
2. **2026-05-19**: dump 専用 `statusline_dump.ps1` を廃止し `statusline.ps1` 1 本に統合。空文字返却が非表示の原因だったため、表示文字列を返すように修正
3. **2026-05-21**:
   - Windows + Git Bash の backslash escape 問題を発見 → settings.json の path を `/` 区切りに修正 → 内蔵 statusLine が表示可能に
   - WezTerm 側 addon を削除(set_right_status のクリア用退避ハンドラだけ残置)
   - 1 行 → 2 行レイアウト化(画面幅切れ対策)
   - 5h/7d を残量 → 使用率に変更
   - ctx を残量 → 使用率に変更(すべて「大きいほど危険」で統一)
   - 時刻表示削除
   - カラーを Catppuccin Mocha → Frappe(落ち着き muted トーン)に変更
   - 1 段目を runtime info、2 段目を dir/branch に並べ替え
   - dir/branch は無着色のプレーンテキスト化
   - Nerd Font アイコンが描画されなかったので Unicode 標準幾何記号に変更

途中で試した没案: 背景塗りつぶし pill 風 / 透明風 muted 暗背景 / 時刻表示あり版。

## 関連ファイル

- 実体スクリプト: `C:\Users\81809\.claude\statusline.ps1`
- 設定: `C:\Users\81809\.claude\settings.json`(`statusLine.command` は `/` 区切りで `statusline.ps1` を指す)
- スクリプト呼び出しデバッグログ: `C:\Users\81809\.claude\statusline_debug.log`
- (歴史的)WezTerm 設定: `C:\Users\81809\.config\wezterm\wezterm.lua` — addon 削除済み、退避ハンドラ + タブバー下端化のみ残存

## 既存の軽い技術的負債(影響無し、お好みで掃除可)

1. **dead dump コード**: `statusline.ps1` は `statusline_input.json` への JSON dump を毎回続けているが、現在読者は存在しない。3 行 + 1 ファイル書き込みのコストが残るが視覚的影響ゼロ
2. **`~/.claude/statusline_dump.ps1`**: 旧 dump 専用版が残置されている。誰からも呼ばれていないので削除可
3. **`~/.claude/*.bak*`**: 設定/スクリプトのバックアップ複数。安定後に削除可
4. **WezTerm の `update-status` 退避ハンドラ**: 旧 addon 残骸クリア用。WezTerm を完全再起動した後は不要(削除可)
5. **WezTerm 下端タブバー設定**: `tab_bar_at_bottom = true` + `hide_tab_bar_if_only_one_tab = false` は元々 statusline 描画領域確保のための設定。statusline 廃止後は下端に薄い空タブバーが残る。デフォルトに戻すなら両方反転 + `format-tab-title` の単一タブ特例も撤去
