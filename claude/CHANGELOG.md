# CHANGELOG — statusline.ps1

> 旧独立リポ `Repositories/statusline` から 2026-06-18 に本リポへ合体。以降は `claude/statusline.ps1` が正本。

## 2026-07-21 — Fable 5（premium モデル）週間制限セグメントを前方互換で追加

### 背景
- 「Fable 5 の週間制限を statusline に出したい」という要望。だが **Claude Code 2.1.216 の statusLine payload は `rate_limits` に `five_hour` / `seven_day` の 2 つしか載せない**（claude.exe の rate_limits ビルダー `I={...x.five_hour&&…,...x.seven_day&&…}` を直接確認）。
- 「Fable 5 limit」の値は claude 内部には存在する（レスポンスヘッダ `anthropic-ratelimit-unified-7d_oi-*` → メモリ `Fkt`）。内部ラベル表 `$kt` に `seven_day_overage_included:"Fable 5 limit"`（兄弟 `seven_day_opus:"Opus limit"` / `seven_day_sonnet:"Sonnet limit"`）が実在。だが statusLine 層で間引かれ、payload にもディスク（`cachedUsageUtilization` は現在 `.claude.json` に不在）にも出てこない。

### 変更
- `rate_limits.seven_day_overage_included`（無ければ `seven_day_opus` → `seven_day_sonnet`）を**優先順で 1 つ**読むセグメントを追加。アイコン `◒`、ラベル `F5`/`Op`/`So`。色・reset 表記は 5h/7d と同一（used% ステージ + ↺）。
- **前方互換設計**: 今日は payload にフィールドが無いので**非表示**（何も壊さない）。将来 Claude Code が premium-weekly キーを payload に載せた瞬間、**追加作業ゼロで自動点灯**する。内部ラベル表が既にある以上、追加は時間の問題という読み。

### 検証
- payload に premium キー無し → F5 非表示・5h/7d 正常（現行実ダンプで確認）。
- `seven_day_overage_included` 有り → `◒ F5:63% ↺6d23h` 出現。`seven_day_opus` のみ → `◒ Op:88%` 出現（fallback・88% 赤ステージ）。
- 正本編集後、実体 `~/.claude/statusline.ps1` へコピーしハッシュ一致を確認（W1 解消）。

## 2026-06-15 — 空行/フォールバック表示のバグ修正（stdin読み取り）

### 症状
- 複数ペイン（WezTerm）で Claude Code を開くと、**一部のペインだけステータスラインが空行**になる（例：6ペイン中2ペインがNG、他は正常）。
- 修正途中では**全ペインが `◆ Claude / ▸ ?`（フォールバック）**になる状態も発生。

### 根本原因（2段重ね）
1. **`[Console]::InputEncoding = UTF8` をセットすると、リダイレクト/パイプの stdin 読み取りが 0 バイトになる。**
   Claude Code は stdin にJSONをパイプで渡すため、これで入力が空→ JSON解析不可。
   さらにこの設定は「コンソール無し（パイプ）」環境で例外を投げることがあり、その場合 `Write-Output` 到達前に**スクリプトが異常終了→空行**。ペインのハンドル状態で成否が分かれるため「N個中M個だけNG」になっていた。
2. **スクリプト内に自動変数 `$input` が1箇所でも存在すると、PowerShell が起動時に stdin を `$input` へ吸い取る（pre-drain）。**
   その後 `[Console]::OpenStandardInput().ReadToEnd()` を呼んでも 0 バイト。
   旧コードの `$raw = $input | Out-String` がこれに該当（かつ Console.InputEncoding 依存で UTF-8 が CP932 復号され文字化け）。

### 修正
- **stdin を最初に、`OpenStandardInput()` + `StreamReader([Encoding]::UTF8)` で明示的にUTF-8読み取り**（Console.InputEncoding に依存しない）。
- **`$input` を完全排除**（pre-drain を避ける。コメントで理由を明記）。
- `[Console]::InputEncoding` は**設定しない**（入力は自前で復号するため不要）。
- `[Console]::OutputEncoding`（グリフ表示用）は **stdin読み取り後** に設定し、`try/catch` で保護（パイプ出力でも異常終了しない）。

### 検証
- `$input` 参照ゼロ（コメントのみ）。
- バイト忠実な `pwsh -File statusline.ps1 < input.json`：**フルの2行出力**（model / eff / ctx / 5h / 7d / +/- / dir / branch）。
- デバッグログ `stdin_len > 0`（読めている）。

### 既知の残課題（別件・未対応）
- `statusline_input.json`（WezTerm連携用ダンプ）が**全セッション共通の1ファイル**で、最後に描画したウィンドウに上書きされる。複数ウィンドウでWezTerm側が別リポ名を表示する原因。直すなら session_id 別ファイル化。
- Claude Code が渡す `session_name` の文字化け（payload側のUTF-8/CP932問題。ステータスライン描画には影響なし）。

### 配置
- 実体（Claude Codeが実行）：`C:\Users\81809\.claude\statusline.ps1`
- 本リポ：`statusline.ps1`（同一・版管理用）
- 旧版バックアップ：`C:\Users\81809\.claude\statusline.ps1.bak`
