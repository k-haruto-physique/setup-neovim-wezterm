# CHANGELOG — statusline.ps1

> 旧独立リポ `Repositories/statusline` から 2026-06-18 に本リポへ合体。以降は `claude/statusline.ps1` が正本。

## 2026-10-29 — context_guard.py を割合からトークン数へ

### 背景
- 本人「他のリポもふくめて定期的に圧縮がはいっているけど大丈夫？」→「なおしていい」。
- 直近3日の transcript の `compact_boundary` を数えた＝自動の要約 45回は 22万〜98万トークンの間でばらばらに入り、要約の直後は 8万〜15万に戻っていた。100万の窓の 60%（60万）で鳴らす作りでは **45回中34回が鳴る前に要約された**（この回を数えたセッション自身も 53万・47万で2回、知らせなしで要約された）。

### 変更
- 段をトークン数に＝18万（区切りで控え）・21万（今すぐ控え）・そのあと10万ごと（控えを足す）・16万未満で印を戻す。窓が小さい時は 60%・70%・50% と小さいほう（20万の窓なら今までと同じ）。
- `.warned` の中身は「最後に鳴らした段のトークン数」に。旧形式（`60 70`）は読み捨てる。
- selftest を 100万と20万の窓・段飛ばし・旧形式の印で組み直した（`RESULT: OK`）。statusline.ps1 は変えていない。

## 2026-10-27 — ctx の値をフック用に書き出す（context_guard.py）

### 背景
- 本人 GO＝会話の記憶が 6割・7割を超えたら、要約が入る前に控えを書かせたい（同僚の進め方を見て）。フックの入力には使用率が無いので、表示のために受け取っている `context_window.used_percentage` を書き出して渡す。

### 変更
- 「4. Context window」で使用率を出した直後に、`~/.claude/state/ctx/<session_id>.json`＝`{used, size, ts}` を書く（失敗しても表示は変えない）。
- 読む側は `claude/context_guard.py`（`hooks.PostToolUse`・60% と 70% で1回ずつ知らせる・50% 未満で印を戻す・3日より古い写しは掃除）。配線と戻し方は README。

## 2026-10-20 — eff に ultracode のオンオフを出す（2.1.284 の仕様変更に追従）

### 背景
- 本人「effの仕様が変わったので記載をかえてほしい　思考の深さのほかにultracodeがオンオフできるようになった　それがわかるようにして」。
- 2.1.284 で ultracode は effort の一段（xhigh の別名）から、**effort とは別のセッション単位のオンオフ**に変わった（`/effort ultracode [on|off]`・スライダーの Tab。`Ultracode on (this session only): … Effort stays high.`）。claude.exe 2.1.304 で、payload には今も ultracode の欄が無く、transcript の `ultra_effort_enter`/`exit` が今も確実な足跡であることを確かめた。
- 08-20 (2) の判定は新仕様で 3 か所外れていた: ① payload の段が xhigh の時しか読まない＝high のまま ON にしても出ない ② `Set effort level to …`・`Effort level set to auto`・`Cleared effort …` を OFF として扱う＝ローカルでは ultracode を保つので ON なのに消える ③ 新しい文言 `Ultracode on (this session only)`・`Ultracode off.` を拾わない（旧文言 `Set effort level to ultracode …` は 2.1.286 以降の本体に無い）。

### 変更
- **表示**: `◇ eff:<段>` の後ろに、効いている時だけ `+ultracode`（赤）を付ける。段の文字と色は変えない（旧: `◇ eff:ultracode` で段を置き換えていた）。
- **判定**（`Test-Ultracode`）を、transcript を前から順に追う形にした。enter/exit・`/effort` の結果（状態が一意に決まる文言だけ＝`Get-UltracodeFromStdout`・` · Ultracode on|off` の接尾辞と `/effort status` を含む。それ以外は読み飛ばす）・`compact_boundary`（その時 ON なら保留）・人のプロンプト行（保留中なら OFF。ON のままなら直後の enter/full で ON に戻る）。
  - 保留は「圧縮の後、本体が圧縮前の enter を忘れる」穴への手当て: 読み飛ばすと stdout の残らない OFF で永久に嘘の ON、圧縮で OFF にすると長いターンの途中の自動圧縮のたびに消える。
  - 人のプロンプト行から、attachment の入れ子（`queued_command`）・スキルの起動行・`/` で始まる入力を除く（zIr が走らない）。人の行は stdout より先に見る（`<local-command-stdout>` で始まる文の貼り付けを取り違えない）。
- **ゲート**: 旧ゲート「xhigh の時だけ読む」を撤去。effort が payload に無い時と、xhigh 非対応モデルの表（`$UC_NO_XHIGH`・本体 `Zgt` の既定の表）に当たる時は読まない（ON にした直後に `/model` でそこへ替えると exit が永久に書かれない穴を塞ぐ）。sessionId・startedAt のゲートは行ごとに残した。pid ファイルが書きかけ（空・途中で切れた JSON）の時だけ、同じ会話の控えの startedAt を使う。
- **読んだ所までの控え**（`%TEMP%\claude-statusline\uc-<CLAUDE_PID>.json`）: 段を問わず毎回読むようになったので、次回は追記分だけ読む。控えた位置の直前 4KB の指紋（SHA-256）で、本体が行を消して詰め直した時（墓標の削除）を見抜く。値の形まで確かめ、別名に書いてから置き換え、7 日より古い `uc-*` を片付ける。旧版の毎回の全走査（負荷の高い時に 40MB 手前で約 1 秒）と、40MB 超の会話で末尾 32MB の窓が最後の enter を切り落とす取りこぼしの両方が解けた。

### 検証
- 本体を 4 観点（`/effort` の文言・attachment の書かれ方・payload と再描画・実 transcript の並び）で読み、反証を 2 回。
- 実 transcript を途中で切った写し 1,771 か所で、規則の文面だけから独立に書いた Python の判定と不一致 0。少しずつ伸ばす再生 1,447 回（510MB の会話も最後まで）で、控えを使った差分読みが窓なしの全走査と毎回一致。
- 合成の試験 約 500 件（文言・保留・ゲート・控えの壊れ方・同時実行・墓標の削除・モデルの表 40 表記・表示）で、外れは意図して残した参考の 2 件だけ（うち 1 件は `-ceq` に直した）。
- 本セッション（xhigh・OFF）の実物で `◇ eff:xhigh`、ON の写しで `◇ eff:high+ultracode` を確認。
- 詳細と残るリスクは `statusline-spec.md`「effort セグメントと ultracode 検出」。

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
