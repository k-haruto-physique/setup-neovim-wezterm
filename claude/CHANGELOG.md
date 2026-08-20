# CHANGELOG — statusline.ps1

> 旧独立リポ `Repositories/statusline` から 2026-06-18 に本リポへ合体。以降は `claude/statusline.ps1` が正本。

## 2026-08-20 (2) — ultracode 検出を transcript の attachment レコードに置き換え

### 背景
- 同日 (1) で入れた検出（settings.json + system-reminder テキスト）が**実セッションで点かなかった**。ユーザー報告「セッション名を付けると入力欄の上の ultracode 表示が消えるので eff で視認したい／今は xhigh と同じ表示になる」。
- 調査で判明: **system-reminder のテキストは transcript に永続化されない**（`Ay([vn({content:…,isMeta:!0})])` は API リクエスト組み立て時にだけ差し込む）。ユーザーの transcript 2808 本に 0 件＝(1) の経路は最初から死んでいた。
- 同時に判明した本命: リマインダを生成する `QLS()` が出す**属性レコードの方は transcript に書かれる**。

### 変更
- `Test-Ultracode` を全面的に置き換え。**`{"attachment":{"type":"ultra_effort_enter"|"ultra_effort_exit"},"type":"attachment",…}` の最後の 1 件**を現在状態として読む（実レコード 258 件を 68 ファイルで確認、2.1.220+）。補助アンカーとして `/effort` の `<local-command-stdout>` 行も見る（`/effort xhigh` で切れた直後の窓を塞ぐ）。
- **3 つの AND ゲート**を追加: ① `effort.level == "xhigh"`（他レベルではファイルを読まない）② 一致行の `sessionId` == payload の `session_id` ③ 一致行の `timestamp` >= このプロセスの `startedAt`（`~/.claude/sessions/$env:CLAUDE_PID.json` から取得。**`--continue` で追記され続ける transcript の再開穴を塞ぐ**）。
- **`settings.json` の `ultracode` キー読みは撤去**。静的な入力であって live state ではなく、`/effort xhigh`・model-picker・Remote Control がキーに触れずに OFF にできる＝嘘をつきうるため。
- 表示は `◇ eff:ultracode`（赤）。(1) の `ultra` から視認性優先で改名。
- 走査は約 2.9ms/MB。典型 0.6MB で数 ms、40MB 超の異常サイズのみ末尾 32MB に限定して ~120ms 以内。

### 検証
- 合成 11 ケース全 PASS（enter / exit / 再開前の古い enter / 別セッション / `/effort xhigh` 直後 / `/effort ultracode` 直後 / エスケープ済みノイズ / マーカー無し / effort=high / `CLAUDE_PID` 無し / pid ファイル不在）。
- **実 transcript 3 本**（claude が実際に書いたバイト列）でも PASS: enter 終端 2 本 → `ultracode` / exit 終端 1 本 → `xhigh`。
- 本セッションの transcript には `"Ultracode is on:"` や `"ultracode": true` がツール出力として実在するが、**エスケープ済みのため一致せず** `xhigh` を返すことを確認（誤検出無し）。

## 2026-08-20 — 2 段 → 4 段の縦積み化 + ultracode 検出

### 背景
- WezTerm を細かくペイン分割して使う運用で、旧 1 段目（`◆ model │ ◇ eff │ ◈ ctx │ ◐ 5h ◑ 7d ◒ F5 │ +/-lines` の横一列）が **約 80 列あり、ペイン幅で右端が切れて使用制限が読めない**。
- statusLine payload に端末幅のフィールドが無いため、**幅に応じた動的折り返しは原理的に不可** → 意味単位の固定段割りに切り替える。

### 変更
- 出力を **最大 4 段**に縦積み化: (1) model │ eff │ 編集行数（+ vim）/ (2) ctx │ 使用制限（5h・7d・F5）/ (3) dir / (4) branch。「設定系」と「残量メーター系」で行を分けた。
- 組み立てを `$line1`/`$line2` の直書きから **`Join-Segments` + `$rows` リスト**に変更。空セグメントは連結から除外され、**中身の無い段は行ごと落とす**（無駄な空行を出さない）。
- **ultracode 検出を新設**（`Test-Ultracode`）。payload の `effort.level` は low/medium/high/xhigh/max のみで、**ultracode は内部エイリアス表 `{ultracode:"xhigh"}` で xhigh に展開されてから載る**ため payload 単体では区別不可（claude.exe 2.1.236 の payload ビルダーを直接確認）。よって (1) `settings.json` の `ultracode` キー、(2) transcript 末尾 256KB の `"isMeta":true` 行に残る system-reminder（`Ultracode is on:` / `still on` / `off`）の 2 経路で判定し、`◇ eff:ultra`（赤）を出す。
- セグメントの中身（アイコン・色・数値セマンティクス・dir/branch の無着色）は eff 以外**変えていない**。

### 検証
- 4 段出力を実ペイロードで目視確認（model│eff│行数 / ctx│5h・7d・F5 / dir / branch）。
- ultracode 検出の 4 ケースマトリクス: `on` → **ultra** / `off` → xhigh / **ノイズ（同文字列がアシスタント発話にある）→ xhigh（誤検出無し）** / マーカー無し → xhigh。加えて **ultracode を話題にした実 transcript**（本セッション）でも非検出を確認。
- `settings.json` 経路は `USERPROFILE` を差し替えたダミー HOME で検証（ユーザ実ファイルは未変更）。
- 正本編集後、実体 `~/.claude/statusline.ps1` へコピーしハッシュ一致を確認。**symlink 再リンクは管理者権限が必要で今回も不可（W1 継続）**。

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
