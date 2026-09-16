# バックログ（GO ゲート回収用）

セッション開始（`hi`）時に**必ず読む**未完タスク・仕様書の単一台帳。
troubleshooting / memory に「残タスク」が散らばるのを防ぐ集約点。**完了したら CLOSED へ落とし、起点ファイル（#番号 / memory）にも反映**する。

最終更新: 2026-09-16（Codex ステータスをタブバーへ移設。**OPEN 2 件**＝B16 実機確認・B17 旧 4 段機構の物理削除）。

---

## 🔴 OPEN（未完・要対応）

| # | タスク | 状態 | 次の一手 | 起点 |
|---|---|---|---|---|
| B16 | **Codex ステータスのタブバー表示を実機確認** | 実装・headless 検証済 / GUI 未確認 | **WezTerm を完全再起動**（reload では旧ハンドラが消えない＝#2）。その後 ① Codex ペインを選ぶとタブバー右に `◐ 5h:… ◑ 7d:… ▸ cwd ⎇ branch` が出る ② 旧 4 段ペインが作られない ③ 1 タブでもバーが出る ④ 0xc0000142 ダイアログが再発しない、を確認 | #29 |
| B17 | **旧 4 段ステータスペイン機構の物理削除** | B16 確認待ち | B16 が OK なら `Codex/session-status.ps1`・`install-session-status.ps1`・`hooks.json`・`test-session-status.py`・`statusline.ps1` を git rm し、README / statusline-spec / CHANGELOG を整理。NG ならこれらで巻き戻す（`install-session-status.ps1` 再実行＋`~/.codex/hooks.json` 復元） | #29 |

---

## 🟡 WATCH（潜在リスク・今は無対応でよい）

| # | 項目 | なぜ今やらないか | いつ顕在化するか |
|---|---|---|---|
| W1 | **statusline symlink 切れ** | `~/.claude/statusline.ps1` は symlink ではなく実体ファイル。**2026-08-20 の 4 段化でも repo 正本 → 実体へ手動コピーし、ハッシュ一致を確認済**（表示は最新） | **repo 側 `claude/statusline.ps1` を編集するたび**に手動コピーが要る。symlink 再リンクは `New-Item -ItemType SymbolicLink` が **管理者権限を要求して失敗**（2026-08-20 実測）＝管理者 PowerShell を開ける時にだけ解消可能。それまでは編集後コピーで運用 |
| W2 | **ペイン入力不能（修飾キー stuck）** | 2026-07-02 発生・原因確定（修飾キーの key-up 取りこぼし）。**コードでは直せない**（WezTerm×Windows 積年の既知問題・設定フラグ無し）。運用回避で足りる | 固まったら **Ctrl/Shift/Alt/Win を 1 回タップ**で復活。予防は「修飾キー押したまま Alt+Tab しない」。詳細 troubleshooting #12 |
| W3 | **ペイン入力不能（Claude TUI 描画 wedge）** | 2026-07-03 発生・W2 とは別種（修飾キータップで直らない）。特定 Claude ペインが "Esc to cancel" オーバーレイで wedge。**遠隔修復不可を実証**（send-text は Claude TUI に届かず・zoom-pane は mux CLI をデッドロックさせた）。頻発申告あり | 復旧は**ユーザー直接操作**: クリック→`Esc`×1-2→`Ctrl+C`→最終手段 `claude --continue`（会話復元）。`get-text` にオーバーレイが見えたら W3 確定。詳細 troubleshooting #13 |
| W4 | **statusline ◒ F5（Fable5 週間制限）セグメントが休眠中** | 2026-07-21 前方互換で実装済。だが Claude Code 2.1.216 の statusLine payload は `rate_limits` に `five_hour`/`seven_day` しか載せず（claude.exe 実体で確定）、Fable5 週間制限（内部 `seven_day_overage_included`）は転送されない＝**現在は非表示**。今すぐ出すには自前ポーラー要（不採用） | Claude Code 更新で payload に premium-weekly キーが載れば**自動点灯**（作業ゼロ）。更新後に `◒ F5:xx%` が出るか目視。載らないまま欲しくなったら usage ポーラーを再検討。詳細 `claude/statusline-spec.md`「前方互換」 |
| W5 | **statusline の ultracode 検出が claude 内部実装に依存** | 2026-08-20 に **transcript の `ultra_effort_enter`/`ultra_effort_exit` attachment レコード**方式へ置換し、合成 11 ケース + **実 transcript 3 本**で検証済（当初の system-reminder テキスト方式は**永続化されない**ことが判明＝死んでいた。settings.json 方式は嘘をつきうるので撤去）。残るのは (a) attachment レコードが内部実装で将来変わりうる (b) model-picker / Remote Control で OFF にした時だけ次のプロンプトまで表示が 1 ターン遅れる、の 2 点。どちらも**失敗方向は xhigh への縮退**で誤表示にはならない | 次回の全体監査で claude.exe 実体に対し `"attachment":{"type":"ultra_effort_` が生きているか再確認。消えていたら検出を撤去。詳細 `claude/statusline-spec.md`「effort セグメントと ultracode 検出」 |

---

## ✅ CLOSED（直近クローズ・履歴）

| 日付 | タスク | 確定根拠 |
|---|---|---|
| 2026-09-15 | **B14 ブリッジの送り先があいまいな時は送らない** | ユーザーが (b) を選択。`Select-BridgeTarget`（`bridge-common.ps1`）で候補が 2 つ以上なら exit 6 にし、`-ThreadId`／`-ClaudePid` で指定させる。単体テスト（0/1/2 件）と、`ask-claude.ps1` の結合テスト（テスト用の場所で、実在セッション 2 つを指す仮の起動記録）で確認。`Codex/README.md` |
| 2026-09-15 | **B15 受信箱の真正性（許可した会話だけ受け付けるか）** | ユーザーが (a) 今のままを選択。許可制は導入せず、ブリッジ経由の破壊的・外部送信の操作は Claude がユーザーに確認する運用を続ける（`CLAUDE.md`・`~/.claude/CLAUDE.md`）。検証に使える情報（ファイル所有者・プロセスツリー）は `Codex/README.md` に記録済み |
| 2026-09-15 | **B13 Codex の実効サンドボックスと docs の食い違い** | `~/.codex/config.toml` は `workspace-write` + `auto_review`、docs は `danger-full-access` と記載していた。ユーザーの「どちらでもいい、お互いにやりやすい運用で」を受けて、実際の設定を正とし、`Codex/runtime.toml`・`Codex/README.md`・#17 を合わせた。ブリッジは Temp 配下で動作確認済み。#27 |
| 2026-09-14 | **B12 Codexシム経由のスマホ表示** | CLIの共有サーバー経由resumeを実測済み。ユーザーがスマホに現在の会話が「表示されてる」と確認。#22 |
| 2026-09-14 | **B7 WezTermのGPU高パフォーマンス固定** | ユーザーが「b7ok」と完了を確認。既定OpenGLでの運用を継続。#14 |
| 2026-09-14 | **B11 CopyModeの黄背景強調・表示安定性** | ユーザーが実機状態を「概ね問題なさそう」と確認。再発時は#21を起点に再開する |
| 2026-09-14 | **B9 Codex再起動後の表示・確認なし実行** | 現在のセッションでnever + danger-full-accessを確認。表示設定も一致し、ユーザーが概ね問題なしと確認。#17〜#20 |
| 2026-09-14 | **B8 WezTermのPowerShell反映** | 稼働中WezTerm直下のシェルはpwsh -NoLogo。新規PowerShellでrepo/v/usage/remoteを認識し、ユーザーが概ね問題なしと確認。#15 |
| 2026-09-14 | **B10 Codex CLIの自動Remote Control接続** | デスクトップ側OFF、共通起動スクリプトへPowerShell codexとCtrl+Shift+Nを統一。タスクRunning/RPC connected、PTYの新規thread起動とcwd/モデル/YOLO、回帰8件確認。既存CLIは次回起動/resumeで移行。**罠: 関数追加（11:25）より前に開いたpwshで `codex` を打つと素のexeが起動し共有サーバーに乗らない＝スマホに出ない**（14:49 実測: PID 16204 が `--remote` 無し）。古いシェルは `. $PROFILE` か新規タブで。troubleshooting #22 |
| 2026-09-14 | **Codex分割時の配置修正・shortcuts案内非表示** | 各owner直下に表示2個を移動。幾何照合による自動修復と表示選択時の分割対象修正、GUIなし9件成功。shortcutsの無効化設定を反映（既存CLIは次回起動時）。troubleshooting #19 |
| 2026-09-14 | **Codex並列表示をセッションごとに自動追従（W6解消）・スキル警告修復** | PID・ペイン・thread UUIDで結合し、タイトルとSessionStart/Endで起動/再開/終了を追従。同cwdの異なるモデル2セッションの独立表示、GUIなし8件の回帰確認。Excelスキルの不正アイコンパスを修復し5リポジトリのskills/listエラー0。詳細 troubleshooting #19 |
| 2026-09-14 | **再開後のCodexステータス欠落・旧表示タブ残留を復旧** | 旧SessionId固定の表示だけが別タブに残っていた。現在のCodex下端へ表示を作り直し4行を確認、旧表示ペインを終了。タブ閉じるボタンとタブ/ペイン終了キーを明示。troubleshooting #18 |
| 2026-09-14 | **Codex 4段ステータスを同一WezTermウィンドウへ統合** | 内蔵 `[tui].status_line` は項目を横1行に並べる仕様のため `[]` で非表示化。WezTerm `pane:split` の5セル固定ペインでClaude同等の4段表示を常駐させる。詳細 troubleshooting **#18** |
| 2026-09-11 | **Codex 自動承認 + Remote Control 自動起動** | `~/.codex/config.toml` に `approval_policy = "on-request"` + `approvals_reviewer = "auto_review"`。Windows ログオンタスク `Codex Remote Control` から localhost 限定 app-server を常駐起動し、タスク `Running`・`127.0.0.1:14567` Listen・`/readyz` HTTP 200 を確認。公式ラッパー2種のWindows失敗は troubleshooting **#17** に記録 |
| 2026-07-16 | **B6 再決着: Remote Control 自動接続を `settings.json` に一本化＋WezTerm 既定シェルを pwsh 化** | 同日朝の実装（下行 `3d9475b` の `claude` ラッパー）は **一度も発火していなかった**。原因: `wezterm.lua` に `default_prog` が無く既定シェルが **cmd.exe**（プロセスツリー実測: wezterm-gui → cmd.exe ×6 → claude ×5・pwsh 皆無）→ `$PROFILE` の dot-source 機会が無く、**B5(06-18) 以来 `repo`/`v`/`vrepo`/`kanro`/`remote`/`usage` も全部死んでいた**（README の「cmd.exe は使用しない」宣言とも矛盾）。**是正 3 点**: ① `wezterm.lua` に `config.default_prog = { "pwsh.exe", "-NoLogo" }`（`-NoProfile` 厳禁）② `~/.claude/settings.json` に `"remoteControlAtStartup": true` ③ `claude`/`claudeplain` ラッパーを撤去（正本を 2 箇所に割らない・`remote` は名前付き起動用に存続）。**② の裏取り**: 公式 docs はトグル存在のみでキー名非公開 → claude.exe 2.1.211 の実体から zod スキーマ `remoteControlAtStartup: "Start Remote Control bridge automatically each session"` と起動判定 `Bg = !(…) && !CLAUDE_CODE_REMOTE && (At \|\| U0e())`（`At`=フラグ / `U0e()`=設定）を確認＝**毎回 `--remote-control` と等価・起動経路に非依存**。**検証**: 独立プロセス起動の子が cmd.exe → **pwsh.exe** に変化／dot-source 後の関数に `claude` 無し・`claude` は exe に解決。**残**: 稼働中 WezTerm には乗らない＝完全再起動待ち（**B8**）。詳細 troubleshooting **#15 / #16** |
| 2026-07-16 | ~~B6 方針変更: Remote Control を既定 ON（全セッション）＋セッション名を当日 8 桁日付に~~（**同日中に上行で supersede**。実装自体が cmd.exe 環境で不発だったうえ、ネイティブ設定キーが存在したためシェル層の実装ごと撤去） | ユーザー判断「どれを起動しても remote-control になるように」＝2026-07-02 の B6 決着（手動のみ）を**撤回**。`powershell/profile.ps1` に `claude` ラッパーを追加し、対話起動時のみ `--remote-control --remote-control-session-name-prefix <yyyyMMdd>` を自動付与（例 `20260716-graceful-unicorn`）。**実機 `claude --help`（2.1.211）でフラグを裏取り**。`-p/--print`・`mcp` 等サブコマンド・`--remote-control` 指定済みは素通し（対話専用フラグのため）。退避路に `claudeplain`。`remote <名前>` は `20260716-<名前>` へ。**注意: Remote Control はローカル PC が動き続ける前提＝Windows 更新の再起動ではセッションは終わる**（消失対策は push の徹底。復帰は `--continue`・2.1.200+）。settings.json の該当キー名は公式非公開のため `/config` でなく検証済みフラグで実装 |
| 2026-07-06 | **WebGpu GPU ブロック（07-03 追加・未コミット）を不採用・削除** | 8 次元監査の stability 次元で上流裏取り: 凍結 2 種（#12/#13）はどちらも GPU 非起因＋WebGpu は同型環境（Optimus/NVIDIA）で入力ラグ #4278・透過破損 #4502・G-SYNC 誤発動 #7611 の報告。代替は B7（Windows 設定でアダプタ固定）。詳細 troubleshooting **#14** |
| 2026-07-06 | **リポジトリ公開化 + LICENSE 追加** | 監査 critic 指摘（docs は「公開」前提・実態 PRIVATE の矛盾）→ ユーザーが公開を選択。MIT LICENSE を root に追加し `gh repo edit --visibility public` 実施。secrets スキャンはゼロ確認済 |
| 2026-07-06 | **監査 findings 一括是正（確定 19 件中 auto 適用分）** | `hi` フック現行化（backlog 欠落・OPEN 報告指示なし）/ MEMORY.md の幻残タスク 3 行 / usage の NO_COLOR セッション漏れ / Shift+Click 誤爆経路封鎖 / keybinds.md（デフォルト宣言の虚偽・Ctrl+Shift+Space 誤記・open-path とPS 関数の未掲載）/ README（setup.md 壊れ参照・構成図陳腐化）/ CLAUDE.md（markdown.lua 説明・usage-log 説明）/ #12 をウィンドウ単位表現に補正 / nvim/.gitignore に spell/ 追加 |
| 2026-07-02 | B2 open-path-in-nvim GUI 実機確認 | GUI 実機で **Ctrl+Shift+O が nvim で開くのを確認**（本命・IME 無関係）。Ctrl+Click は当初無反応（プレーンクリックが既定 `CompleteSelectionOrOpenLinkAtMouseCursor` で開く＝誤爆源）→ `mouse_bindings` を明示追加し **Ctrl+Click=OpenLink / プレーンクリック=選択のみ / Ctrl+Down=Nop**（WezTerm 公式レシピ）。再確認で Ctrl+Click 開く・プレーンクリック開かずを確定 |
| 2026-07-02 | B6 Remote Control 採否 | ユーザーが (b) を選択。`powershell/profile.ps1` に手動起動の **`remote` 関数**を追加（公式フラグ `--remote-control [name]` を `claude --help` で裏取り）。全セッション自動 ON はせず、必要時のみ手動起動する方針で決着 |
| 2026-06-18 | MCP /doctor の 3 件 timeout（#10） | 当日初回コールドで postgres 644 / playwright 635 / notion 392ms。MCP ログ実測で sub-second 確認 |
| 2026-06-18 | 旧 statusline 独立リポを本リポへ合体（`b4e93ae`） | `claude/` に script＋`statusline-spec.md`＋`CHANGELOG.md`＋`README.md` を集約。旧リポの古い ps1 は破棄。**旧リポ実体 `Repositories/statusline` は物理削除済（2026-06-18・全内容吸収後）** |
| 2026-06-18 | B4 treesitter C compiler（#7） | gcc 16.1.0 が PATH・nvim も `executable('gcc')=1`・**treesitter パーサ 27 個コンパイル済**（sql/python/lua/markdown 含む。パーサ生成は gcc 成功が前提）。`:checkhealth` の C compiler ✅ 相当を headless で確定 |
| 2026-06-18 | B3 dadbod 可視（#9） | psql 18.3 が PATH・pgpass 無人接続成功・kanro_db = **587 テーブル/15 スキーマ**（psql と MCP で二重確認）。`vim.g.dbs`=kanro_db(postgres@)・`:DBUI` 存在・dadbod 3 プラグイン実体あり。GUI ツリー目視を除き全層検証済 |
| 2026-06-18 | repo 全体 再監査 + auto 修正（`1f51111`） | 6 次元 fan-out＋敵対的検証で確定 20 件。**auto 19 件を適用**（秘密漏れ 2 件＝Notion トークン prefix マスク・MCP 接続文字列の DB パスワード除去 / README・nvim-manual・keybinds・wezterm の実装乖離 / statusline 仕様に eff・reset・編集行数を同期 / 陳腐化 cheatsheet.pdf を git rm）。残 1 件は B5。旧 05-29 監査の 30 件リストは現状乖離のため superseded |
| 2026-06-18 | B5 `powershell/profile.ps1`（監査 doc-impl-02） | ユーザーが「作成」を選択。`powershell/profile.ps1` 正本を新設し `$PROFILE` から **dot-source**（管理者不要・W1 型の symlink 切れ回避）。新規 pwsh で `repo`/`v`/`vrepo`/`kanro`/`dotfiles` 動作確認。README/CLAUDE.md も実態へ更新 |

---

## 📘 仕様書・参照ポインタ（回収対象）

| ポインタ | 中身 |
|---|---|
| `docs/initial-prompt.md` | 原依頼・Phase 構成・意思決定背景（仕様の正本） |
| `memory/project_audit_2026_05_29.md` | 全体監査 35 件の一覧（B5 の供給源） |
| `docs/troubleshooting.md` | 既知地雷 #1〜（随時追記。上限番号は書かない＝陳腐化防止） |
| `docs/keybinds.md` / `docs/nvim-manual.md` | キー・操作仕様 |

---

## 運用ルール

- **新規の「残タスク」が出たら troubleshooting/memory に書くと同時にここへ 1 行追加**（散逸防止）。
- OPEN → CLOSED へ動かすときは**起点ファイルのステータスも更新**（二重台帳の乖離を防ぐ）。
- `hi` 起動時、Claude はこの OPEN 件数と上位項目を挨拶に含める。
