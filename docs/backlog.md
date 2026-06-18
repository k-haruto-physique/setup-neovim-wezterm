# バックログ（GO ゲート回収用）

セッション開始（`hi`）時に**必ず読む**未完タスク・仕様書の単一台帳。
troubleshooting / memory に「残タスク」が散らばるのを防ぐ集約点。**完了したら CLOSED へ落とし、起点ファイル（#番号 / memory）にも反映**する。

最終更新: 2026-06-18

---

## 🔴 OPEN（未完・要対応）

| # | タスク | 状態 | 次の一手 | 起点 |
|---|---|---|---|---|
| B2 | **open-path-in-nvim 実機確認** | `bff65d2` でコミット済・構文OK。Ctrl+Shift+O / Ctrl+Click の対話 UX が未検証 | WezTerm **完全再起動**後にパス選択 UI を実機で叩く | memory: WIP |
| B3 | **dadbod 可視確認** | psql PATH 追記・kanro_db 固定済。最終的な「テーブルが見える」確認が WezTerm 再起動待ち | 新規 WezTerm で `where.exe psql` → nvim `:DBUIToggle` で kanro_db 展開 | troubleshooting #9 |
| B4 | **treesitter C compiler 確認** | WinLibs gcc 16.1.0 導入済。再起動後の `:checkhealth` 確認が未記録 | nvim で `:checkhealth nvim-treesitter` → C compiler ✅ を確認し本欄を閉じる | troubleshooting #7 |
| B5 | **全体監査の残り 30 件** | 35 件中 最優先 5 件のみ修正・push 済。残り 30 件は未着手 | 監査リストから次バッチ（中優先）を選び着手 | memory: audit_2026_05_29 |

> B2 / B3 / B4 は**いずれも「WezTerm 完全再起動 1 回」で同時に検証できる**。再起動したらまとめて潰す。

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
