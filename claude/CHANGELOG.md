# CHANGELOG — statusline.ps1

> 旧独立リポ `Repositories/statusline` から 2026-06-18 に本リポへ合体。以降は `claude/statusline.ps1` が正本。

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
