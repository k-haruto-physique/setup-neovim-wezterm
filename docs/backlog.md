# バックログ（GO ゲート回収用）

セッション開始（`hi`）時に**必ず読む**未完タスク・仕様書の単一台帳。
troubleshooting / memory に「残タスク」が散らばるのを防ぐ集約点。**完了したら CLOSED へ落とし、起点ファイル（#番号 / memory）にも反映**する。

最終更新: 2026-07-03（**W3 追加**＝Claude TUI 描画 wedge 型のペイン入力不能。#12 修飾 stuck とは別種・遠隔修復不可を確定。**OPEN は 0 件**）

---

## 🔴 OPEN（未完・要対応）

| # | タスク | 状態 | 次の一手 | 起点 |
|---|---|---|---|---|
*(OPEN なし)*

> **OPEN は 0 件**。旧「監査残 30 件」は 2026-06-18 の再監査で superseded（下記 CLOSED）。B5 は 2026-06-18、B2・B6 は 2026-07-02 に決着（CLOSED）。

---

## 🟡 WATCH（潜在リスク・今は無対応でよい）

| # | 項目 | なぜ今やらないか | いつ顕在化するか |
|---|---|---|---|
| W1 | **statusline symlink 切れ** | `~/.claude/statusline.ps1` は実体ファイルだが repo 正本と**ハッシュ完全一致（2026-06-18 確認）**。表示も中身も正しく、再起動不要 | **次に repo 側 `claude/statusline.ps1` を編集した時**だけ。編集が live に伝播しないので、その時に手動コピー or 管理者で再リンク。それまで放置可 |
| W2 | **ペイン入力不能（修飾キー stuck）** | 2026-07-02 発生・原因確定（修飾キーの key-up 取りこぼし）。**コードでは直せない**（WezTerm×Windows 積年の既知問題・設定フラグ無し）。運用回避で足りる | 固まったら **Ctrl/Shift/Alt/Win を 1 回タップ**で復活。予防は「修飾キー押したまま Alt+Tab しない」。詳細 troubleshooting #12 |
| W3 | **ペイン入力不能（Claude TUI 描画 wedge）** | 2026-07-03 発生・W2 とは別種（修飾キータップで直らない）。特定 Claude ペインが "Esc to cancel" オーバーレイで wedge。**遠隔修復不可を実証**（send-text は Claude TUI に届かず・zoom-pane は mux CLI をデッドロックさせた）。頻発申告あり | 復旧は**ユーザー直接操作**: クリック→`Esc`×1-2→`Ctrl+C`→最終手段 `claude --continue`（会話復元）。`get-text` にオーバーレイが見えたら W3 確定。詳細 troubleshooting #13 |

---

## ✅ CLOSED（直近クローズ・履歴）

| 日付 | タスク | 確定根拠 |
|---|---|---|
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
| `docs/troubleshooting.md` | 既知地雷 #1〜#11（残タスクの起点が点在） |
| `docs/keybinds.md` / `docs/nvim-manual.md` | キー・操作仕様 |

---

## 運用ルール

- **新規の「残タスク」が出たら troubleshooting/memory に書くと同時にここへ 1 行追加**（散逸防止）。
- OPEN → CLOSED へ動かすときは**起点ファイルのステータスも更新**（二重台帳の乖離を防ぐ）。
- `hi` 起動時、Claude はこの OPEN 件数と上位項目を挨拶に含める。
