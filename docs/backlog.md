# バックログ（GO ゲート回収用）

セッション開始（`hi`）時に**必ず読む**未完タスク・仕様書の単一台帳。
troubleshooting / memory に「残タスク」が散らばるのを防ぐ集約点。**完了したら CLOSED へ落とし、起点ファイル（#番号 / memory）にも反映**する。

最終更新: 2026-06-18（B3/B4 を headless 検証で CLOSED、残 OPEN は B2 GUI 実機・B5 監査残）

---

## 🔴 OPEN（未完・要対応）

| # | タスク | 状態 | 次の一手 | 起点 |
|---|---|---|---|---|
| B2 | **open-path-in-nvim 対話 UX** | **静的検証は 2026-06-18 完了**（config パースエラー無し・Ctrl+Shift+O/Ctrl+Click 実装健全）。残るは GUI 実動作のみ（私は GUI 操作不可） | WezTerm **完全再起動**後に、あなたがパス上で `Ctrl+Shift+O` or `Ctrl+Click` → 選択 UI → nvim で開くを 1 回確認 | memory: WIP |
| B5 | **全体監査の残り 30 件** | 35 件中 最優先 5 件のみ修正・push 済。残り 30 件は未着手 | 監査リストから次バッチ（中優先）を選び着手 | memory: audit_2026_05_29 |

> B2 は GUI 実機 1 操作のみ残（あなたの手が必要）。B3/B4 は 2026-06-18 に headless で検証完了し CLOSED。

---

## 🟡 WATCH（潜在リスク・今は無対応でよい）

| # | 項目 | なぜ今やらないか | いつ顕在化するか |
|---|---|---|---|
| W1 | **statusline symlink 切れ** | `~/.claude/statusline.ps1` は実体ファイルだが repo 正本と**ハッシュ完全一致（2026-06-18 確認）**。表示も中身も正しく、再起動不要 | **次に repo 側 `claude/statusline.ps1` を編集した時**だけ。編集が live に伝播しないので、その時に手動コピー or 管理者で再リンク。それまで放置可 |

---

## ✅ CLOSED（直近クローズ・履歴）

| 日付 | タスク | 確定根拠 |
|---|---|---|
| 2026-06-18 | MCP /doctor の 3 件 timeout（#10） | 当日初回コールドで postgres 644 / playwright 635 / notion 392ms。MCP ログ実測で sub-second 確認 |
| 2026-06-18 | 旧 statusline 独立リポを本リポへ合体（`b4e93ae`） | `claude/` に script＋`statusline-spec.md`＋`CHANGELOG.md`＋`README.md` を集約。旧リポの古い ps1 は破棄。**旧リポ実体 `Repositories/statusline` は物理削除済（2026-06-18・全内容吸収後）** |
| 2026-06-18 | B4 treesitter C compiler（#7） | gcc 16.1.0 が PATH・nvim も `executable('gcc')=1`・**treesitter パーサ 27 個コンパイル済**（sql/python/lua/markdown 含む。パーサ生成は gcc 成功が前提）。`:checkhealth` の C compiler ✅ 相当を headless で確定 |
| 2026-06-18 | B3 dadbod 可視（#9） | psql 18.3 が PATH・pgpass 無人接続成功・kanro_db = **587 テーブル/15 スキーマ**（psql と MCP で二重確認）。`vim.g.dbs`=kanro_db(postgres@)・`:DBUI` 存在・dadbod 3 プラグイン実体あり。GUI ツリー目視を除き全層検証済 |

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
