# statusline 設計仕様

Claude Code statusLine（`claude/statusline.ps1`）の設計仕様。
（旧独立リポ `Repositories/statusline` の `CLAUDE.md` を 2026-06-18 に本リポへ合体。本リポ root `CLAUDE.md` の自動ロードと衝突しないよう `statusline-spec.md` にリネーム。）

## 正本と実体

正本は本リポの `claude/statusline.ps1`。実体（Claude Code が実行）は `C:\Users\81809\.claude\statusline.ps1`（現状は symlink 切れの実体コピー・正本とハッシュ一致 = backlog W1。次に編集したら手動コピー or 管理者で再リンク）。

WezTerm 側 statusline addon は 2026-05-21 に廃止済み（表示は Claude Code 内蔵 statusLine）。

## 現在の表示仕様(2026-08-20 時点 — 4 段縦積み)

Claude Code 入力欄の真上に最大 4 段表示。

```
◆ Opus 5 (1M context) │ ◇ eff:high │ +12 -3
◈ ctx:58%/1M │ ◐ 5h:20% ↺3h29m ◑ 7d:75% ↺3d2h ◒ F5:63% ↺6d23h
▸ ~/Documents/Repositories/setup-neovim-wezterm
⎇ master !?
```

| 段 | 内容 | 意味 |
|---|---|---|
| 1 | モデル │ effort │ 編集行数（+ vim モード） | 「今の設定と成果」系 |
| 2 | ctx │ 使用制限（5h / 7d / premium 週間） | 「残量メーター」系を一行に集約 |
| 3 | 現在地（dir） | 開発コンテキスト |
| 4 | git ブランチ + status | 開発コンテキスト |

> **なぜ縦積みか**（2026-08-20 に 2 段 → 4 段）: WezTerm を細かくペイン分割する運用だと、旧 1 段目（model〜ctx〜制限〜編集行数を横一列）は **80 列前後あり、ペイン幅で右端が切れて使用制限が見えなくなる**。statusLine payload には端末幅が含まれないため動的折り返しは不可能。よって**意味単位で固定段割り**した。
>
> **空行は出さない**: 中身の無い段（ctx 未取得 / rate_limits 不在 / git 非管理下）は行ごと落とすので、実際の行数は payload 次第で 4 行以下。セグメント連結は `Join-Segments`（空を除外して ` │ ` 結合）に一本化してあるので、先頭末尾に孤立したセパレータは出ない。

### effort セグメントと ultracode 検出

`data.effort.level` は **low / medium / high / xhigh / max** の 5 値のみ。**ultracode は payload に出てこない**（claude.exe 2.1.236 の payload ビルダー `...FD(_)&&{effort:{level:NK(_,m)}}` を直接確認。内部のエイリアス表 `{ultracode:"xhigh"}` で **xhigh に展開されてから** payload に載るため、素の xhigh と区別できない）。

そこで `Test-Ultracode` で 2 経路から補う:

1. **`~/.claude/settings.json` の `ultracode` キー** — `--settings` / Remote Control の `apply_flag_settings` 経由の指定はここに出る。確実・安価。
2. **transcript 末尾 256KB の system-reminder** — `/effort ultracode` は**セッション限定で設定ファイルに残らない**ため、会話ログ側の足跡（`Ultracode is on:` / `Ultracode is still on` / `Ultracode is off`）を見る。最後の 1 件が現在状態。

**誤検出対策**（重要）: 走査するのは **`"isMeta":true` の行だけ**。ツール出力やアシスタント発話に同じ文字列が出ても拾わない（ultracode を話題にした実 transcript で非検出を確認済）。また走査は **`xhigh` の時だけ**実行する（他レベルではファイルを 1 バイトも読まない）。

検出されたら `◇ eff:ultra`（**赤**）。見つからなければ従来通り `◇ eff:xhigh` に落ちるだけで、**嘘の表示は出ない**設計。

### カラーパレット (Catppuccin Frappe)

Mocha の公式落ち着き版。長時間視認しても疲れにくい muted トーン。

| 用途 | 色 | hex |
|---|---|---|
| sep / labels / brackets / size 表記 | overlay0 | `#737994` |
| git branch / safe (<50%) / 追加行 (+N) | green | `#a6d189` |
| ctx ラベル | teal | `#81c8be` |
| model | mauve | `#ca9ee6` |
| vim mode / xhigh effort | peach | `#ef9f76` |
| warn (50-80%) | yellow | `#e5c890` |
| danger (≥80%) / 削除行 (-N) | red | `#e78284` |
| (定義のみ・未使用 dead) | blue | `#8caaee` |

> dir / branch は**無着色（プレーン）**で描画（旧 blue 割当は廃止、`$BLUE` は定義のみで未使用）。effort レベルは離散値で色が変わる（下記「effort セグメント」）。

### アイコン (Unicode 標準幾何記号 — Nerd Font 不要)

| 項目 | 記号 | コード |
|---|---|---|
| model | ◆ | U+25C6 BLACK DIAMOND |
| effort | ◇ | U+25C7 WHITE DIAMOND |
| ctx | ◈ | U+25C8 |
| 5h | ◐ | U+25D0 |
| 7d | ◑ | U+25D1 |
| Fable5 / premium 週間 | ◒ | U+25D2 CIRCLE WITH LOWER HALF BLACK |
| reset 残時間 | ↺ | U+21BA ANTICLOCKWISE OPEN CIRCLE ARROW |
| dir | ▸ | U+25B8 |
| branch | ⎇ | U+2387 ALTERNATIVE KEY SYMBOL |

### 数値セマンティクス

ctx / 5h / 7d / Fable5 週間はすべて **使用率(USED %)** 表示で統一(大きいほど危険)。ステージカラーも used に基づく判定:

- `< 50%` 緑(safe)
- `50-80%` 黄(warn)
- `>= 80%` 赤(danger)

### effort セグメント (◇ eff:)

`data.effort.level` を離散表示（USED% ではないので上記 <50/50-80/≥80 閾値とは別系統）:
`low`=overlay0(dim) / `medium`=green / `high`=yellow / `xhigh`=peach / `max`=red。

### reset 残時間 (↺)

5h/7d は `resets_at`(Unix epoch) から残時間を算出し ↺ 付きで併記: `>=1d → 3d3h` / `>=1h → 2h13m` / それ未満 → `47m`。absent または経過済みなら非表示。

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
| effort レベル | `data.effort.level` |
| ディレクトリ | `data.workspace.current_dir`(`~` 短縮 + 末尾 10 階層) |
| Git ブランチ / dirty / ahead-behind | `git rev-parse` / `git status --porcelain` / `git rev-list` |
| Context 使用率 | `data.context_window.used_percentage` + `context_window_size` |
| 5h / 7d レート使用率 + reset 残時間 | `data.rate_limits.{five_hour,seven_day}.used_percentage` / `.resets_at` |
| Fable5 / premium 週間制限（◒）| `data.rate_limits.{seven_day_overage_included,seven_day_opus,seven_day_sonnet}`（優先順で最初の 1 つ）。**2.1.216 では payload に未搭載＝現在は非表示**。下記「前方互換」参照 |
| 編集行数 (+追加 / -削除) | `data.cost.total_lines_added` / `data.cost.total_lines_removed`（>0 のみ表示） |
| Vim mode | `data.vim.mode` |

レート情報は Claude.ai Pro/Max 加入者のみ初回 API 応答後に含まれる。それまでは `rate_limits` フィールド自体が無いのでセグメントは非表示になる(コード側でガード済み)。

### Fable5 週間制限の前方互換（◒ セグメント・2026-07-21 追加）

**現状**: Claude Code 2.1.216 の statusLine payload の `rate_limits` は `five_hour` / `seven_day` の 2 つ**しか**載らない（claude.exe のビルダー `I={...x.five_hour&&…,...x.seven_day&&…}` を直接確認）。「Fable 5 の週間制限」は payload には**来ない**。

だが値自体は claude 内部に存在する:
- 出所はレスポンスヘッダ `anthropic-ratelimit-unified-7d_oi-*`（`hyu()` がメモリ `Fkt` にパース）。
- claude の内部ラベル表 `$kt` に **`seven_day_overage_included:"Fable 5 limit"`**（兄弟 `seven_day_opus:"Opus limit"` / `seven_day_sonnet:"Sonnet limit"`）が実在。`/usage` や警告文（"try /model opus · more runway"）はこれを使う。
- ディスク永続の `cachedUsageUtilization`（`.claude.json`）も候補だが、**現在不在**かつスキーマ別系統（`overage_included` を持たない）＝読めない。

**設計**: statusline.ps1 は `seven_day_overage_included`（無ければ `seven_day_opus` → `seven_day_sonnet`）を優先順で読む。**今日は payload に無いので何も描画しない（前方互換の休眠状態）**。将来 Claude Code が premium-weekly キーを payload に載せた瞬間、追加作業ゼロで `◒ F5:xx%` が自動点灯する。内部ラベル表が既にある以上、payload 搭載は時間の問題という判断。

**もし「今すぐ数値を出す」なら**: usage エンドポイントを叩く自前ポーラー（scheduled task → キャッシュ JSON → statusline が読む）が唯一の手だが、未公開 OAuth 経路・トークン取扱い・claude 更新での破綻リスクを抱えるため 2026-07-21 時点では**採らない**（低保守方針）。将来 payload 搭載が来なければ再検討。

## セッション変遷ログ (2026-05-19 〜 2026-05-21)

1. **初期**: WezTerm 側で ccusage + git + statusline_input.json 経由で画面下端に表示。Claude Code 内蔵 statusLine は非表示問題で使えなかった
2. **2026-05-19**: dump 専用 `statusline_dump.ps1` を廃止し `statusline.ps1` 1 本に統合。空文字返却が非表示の原因だったため、表示文字列を返すように修正
3. **2026-05-21**:
   - Windows + Git Bash の backslash escape 問題を発見 → settings.json の path を `/` 区切りに修正 → 内蔵 statusLine が表示可能に
   - WezTerm 側 addon を削除(set_right_status のクリア用退避ハンドラだけ残置)
   - 1 行 → 2 行レイアウト化(画面幅切れ対策) — 2026-08-20 にさらに 5 行化(ペイン分割対策)
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
