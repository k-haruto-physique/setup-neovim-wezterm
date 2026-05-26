# 言語別ワークフロー（このセットアップ固有）

SQL / Python / Markdown / Lua を **このリポジトリの LazyVim で実際にどう編集・整形・実行するか**。
汎用 Vim 操作は `docs/keybinds.md` / `docs/nvim-manual.md`。本書は **Mason が実際に入れたツール**（2026-05-26 時点の実体調査ベース）に紐づけた実戦ガイド。

---

## 結論: いま何が動くか

| 言語 | LSP（補完・定義ジャンプ・hover） | 整形 | Lint | 総合 |
|---|---|---|---|---|
| **Python** | `pyright` ✅ | `ruff` ✅ | `ruff` ✅ | フル装備 ◎ |
| **Lua** | `lua-language-server` ✅ | `stylua` ✅ | LSP 内蔵 | フル装備 ◎ |
| **Markdown** | `marksman` ✅ | `markdownlint-cli2` / `markdown-toc` | **無効化済**（意図的）| LSP あり・preview なし ○ |
| **SQL** | `postgres_lsp`（導入設定済・要初回 install）✅ | `sqlfluff` ✅ | `sqlfluff` / `postgres_lsp` ✅ | 設定完了・初回 install 待ち ○ |

> **SQL は当初 LSP なし**（sqlfluff だけ）だったが、2026-05-26 に `postgres_lsp` 導入を決定（`nvim/lua/plugins/sql-lsp.lua`）。Mason パッケージ名は **`postgres-language-server`**。プロジェクトに `postgres-language-server.jsonc` がある時だけ起動する opt-in 方式（下記 SQL 節）。

---

## 全言語共通の仕組み（先にこれだけ理解）

### 1. LSP = コードの知能（補完・ジャンプ・エラー検出）

ファイルを開くと対応する LSP が自動で立ち上がる。共通キー（`docs/keybinds.md` の LSP 節と同じ）:

| キー | 動作 | VSCode |
|---|---|---|
| `K` | カーソル下の型・ドキュメント表示（hover） | マウスホバー |
| `g d` | 定義へジャンプ | F12 |
| `g r` | 参照を一覧 | Shift+F12 |
| `Space c a` | コードアクション（自動修正・import 等） | Ctrl+. |
| `Space c r` | シンボル名を一括リネーム | F2 |
| `Space c d` | カーソル行の診断（エラー）を表示 | — |
| `[d` / `]d` | 前 / 次のエラーへ | F8 |
| `Space x x` | 診断一覧パネル（Trouble） | 問題タブ |

**確認コマンド**: ファイルを開いて `:LspInfo` → 対応 LSP が `attached` なら知能が効いている。

### 2. 整形 = 保存時に自動実行（conform.nvim）

LazyVim は**保存（`:w`）時に自動フォーマット ON** がデフォルト。手動・トグルは下記:

| キー / コマンド | 動作 |
|---|---|
| `Space c f` | いま手動で整形 |
| `Space u f` | このバッファの保存時整形を ON/OFF |
| `Space u F` | 全体の保存時整形を ON/OFF（グローバル） |
| `:ConformInfo` | **どのフォーマッタが今のファイルに効くか**を確認（最重要・困ったらこれ） |

> 整形が暴れる・意図と違う時は、まず `:ConformInfo` で「何が走っているか」を見る。憶測でいじらない。

### 3. ツール管理 = Mason

LSP・フォーマッタの実体は Mason が `%LOCALAPPDATA%\nvim-data\mason\` に入れる。

| キー / コマンド | 動作 |
|---|---|
| `:Mason` | GUI。`i` で追加インストール、`X` で削除、`u` で更新 |
| `Space c m` | Mason 起動（同上） |

---

## Python（pyright + ruff）◎

最もフル装備。pyright が型・補完・ジャンプ、ruff が整形と lint を高速に担当。

### 日常フロー

1. `.py` を開く → pyright と ruff が自動 attach
2. 入力中に補完が出る（`Ctrl+Space` で強制起動 / `Tab` で確定）
3. 型を見たい → `K`、定義へ飛ぶ → `g d`
4. 保存 `:w` → ruff が整形（import 並べ替え・空白調整など）
5. 赤波線（lint 警告）は `]d` で巡回、`Space c a` で自動修正候補

### 実行

| やりたいこと | コマンド |
|---|---|
| 今のファイルを実行 | `:!python %` （`%` = 現在ファイルのパス） |
| ターミナルで対話実行 | `:terminal python %` → そのまま REPL 操作 |
| WezTerm 別ペインで実行 | `Ctrl+Shift+Alt+"` で下にペイン分割 → `python ファイル名` |

> マルチモニター運用なら、nvim とは別の WezTerm ペイン / ウィンドウで `python` を回すのが見やすい。

### 注意

- **仮想環境（venv）**: pyright は通常プロジェクト直下の `.venv` を自動検出するが、外れる時は `:!python -c "import sys; print(sys.executable)"` で今どの Python を見ているか確認。明示指定が要るなら `pyrightconfig.json` か `:PyrightSetPythonPath`（後者は要プラグイン、未導入なら前者）。
- **デバッガ（dap）**: `debugpy` は **未インストール**。ステップ実行が要るなら `:Mason` で `debugpy` を入れて lang.python の DAP を有効化（必要になったら相談を）。

---

## Lua（lua-language-server + stylua）◎

このリポジトリ自身（nvim 設定）を編集するための装備。Neovim API を理解した補完が効く。

### 日常フロー

1. `.lua` を開く → lua-language-server が attach
2. `vim.api.` まで打つと **Neovim API の候補**が出る（LazyVim が型定義を読み込み済）
3. 保存 `:w` → `stylua` が整形（設定は `nvim/stylua.toml`）
4. `K` で関数シグネチャ、`g d` で定義元へ

### このリポジトリを編集する時の鉄則（再掲・重要）

- **必ずリポジトリ側パスで編集**: `nvim/lua/plugins/<name>.lua`
- 実体側（`%LOCALAPPDATA%\nvim`）経由で編集すると `Refusing to write through symlink` で弾かれる
- プラグイン設定を変えたら `:Lazy reload <plugin>` か nvim 再起動で反映

### stylua の設定変更

整形ルール（インデント幅・引用符など）は `nvim/stylua.toml` を編集。変更後は次回保存から反映。

---

## Markdown（marksman、preview なし）○

このリポジトリの docs を書くための装備。**意図的に「素の見た目」**にしてある（背景塗り・conceal を全停止、`docs/troubleshooting.md` 第 6 項）。

### 日常フロー

1. `.md` を開く → marksman が attach（見出し・リンク補完、ファイル間リンク追跡）
2. `g d` で `[リンク](other.md)` の飛び先へジャンプ
3. `Space s s` でファイル内の見出しシンボル一覧（アウトライン的に飛べる）
4. 保存 `:w` → 整形が走る（`:ConformInfo` で実体確認）

### 装備の現状と意図

| 項目 | 状態 | 理由 |
|---|---|---|
| `render-markdown.nvim` | **無効** | 見出し・コードの背景塗りが「醜い」ため全停止（`nvim/lua/plugins/markdown.lua`） |
| `conceallevel` | `0`（マーカー常時表示） | `**` や `_` が消えたり出たりするのを防止 |
| `markdownlint-cli2` の lint | **無効** | 警告が厳しすぎて目障り。整形機能は生かしたまま診断だけ停止 |
| ライブ HTML preview | **なし** | preview プラグイン未導入 |

### 目次（TOC）生成

`markdown-toc` が入っている。見出しから目次を自動生成できる。使い方は `:ConformInfo` でフォーマッタ列に出ていれば保存時に `<!-- toc -->` マーカー位置へ挿入される（マーカーを置いて保存して挙動確認）。

### preview したい場合（未導入・将来オプション）

- 簡易: `Space x o`（独自キー）で OS 既定アプリに渡す。ただし `.md` はエディタ関連付けだと nvim 等が開くだけで HTML レンダリングはされない
- 本格: `markdown-preview.nvim`（ブラウザでライブプレビュー）を入れる案。必要になれば相談を

---

## SQL（postgres_lsp + dadbod-ui + sqlfluff）◎

PostgreSQL / PostGIS 用。SQL は **3 つのツールが役割分担**する:

| ツール | 役割 | pgAdmin で言うと |
|---|---|---|
| `postgres_lsp`（postgres-language-server） | SQL を**書く**補助：補完・構文/型エラー・hover | クエリエディタの入力支援 |
| `vim-dadbod-ui`（lang.sql で既存） | DB に**繋ぐ**：接続・スキーマツリー閲覧・クエリ実行・結果表示 | **pgAdmin 本体そのもの** |
| `vim-dadbod-completion`（既存） | 繋いだ DB の実テーブル/カラムを補完 | 入力中のテーブル候補 |
| `sqlfluff` | 整形 + lint | — |

整形・lint は `sqlfluff`、書く補助は `postgres_lsp`（2026-05-26 導入・`nvim/lua/plugins/sql-lsp.lua`）、**DB クライアント（pgAdmin 的な利用）は `vim-dadbod-ui`**。

### pgAdmin 的に DB を触る（dadbod-ui）

> 🔧 **前提（Windows の定番ハマり）**: vim-dadbod は PostgreSQL と話すのに **`psql` クライアントを内部で呼ぶ**。`psql` が PATH に無いと「接続は出るのに中身が見えない」。`where.exe psql` で確認し、無ければ `C:\Program Files\PostgreSQL\18\bin` を User PATH に追記 → 新規ターミナル → **WezTerm 完全再起動**。詳細は `docs/troubleshooting.md` 第 9 項。

「接続してクエリを流し結果を見る」は dadbod-ui の担当（lang.sql で導入済・追加インストール不要）:

| コマンド | 動作 |
|---|---|
| `:DBUIToggle` | サイドバー開閉（pgAdmin の接続ツリー相当） |
| `:DBUIAddConnection` | 接続を対話追加。PostgreSQL は `postgresql://user:pass@localhost:5432/dbname` |
| ツリーで `Enter` | DB → テーブル展開・中身プレビュー |
| New query バッファで SQL → 実行 | 既定 `<leader>S`（効かなければ `Space` で確認）。保存で自動実行する設定もあり |

結果は別バッファに**表形式**で出る。接続情報を固定したいなら `vim.g.dbs` に定義（パスワードは git に commit しないこと）。

**pgAdmin との差**: 接続・ツリー閲覧・クエリ実行・結果表示・補完は nvim で完結。ただし**結果グリッドのセル直接編集・ER 図・サーバ管理 GUI・EXPLAIN 可視化は pgAdmin/DBeaver が上**。重い視覚作業は GUI 併用が定石。

### 初回セットアップ（1 回だけ・必須）

`postgres_lsp` 本体は Mason パッケージ **`postgres-language-server`**（旧称 postgrestools ではない）。`sql-lsp.lua` の `ensure_installed` で**次回 nvim 起動時に自動 DL** される。すぐ入れたいなら手動:

```vim
:MasonInstall postgres-language-server
```

> ⚠️ **この LSP はプロジェクトに `postgres-language-server.jsonc` が無いと attach しない**（lspconfig: `workspace_required = true`, `root_markers = postgres-language-server.jsonc`）。単独の `.sql` を開いても**黙ったまま＝エラーも出ない**。使いたいプロジェクト直下に下記の設定ファイルを置いて初めて起動する。普段は邪魔しない opt-in 方式。

### 日常フロー

1. `postgres-language-server.jsonc` がある プロジェクトで `.sql` を開く → postgres_lsp が attach（`K` で hover、構文エラーを即検出）
2. 入力中にキーワード・関数の補完（DB 接続時はテーブル/カラムも）
3. 保存 `:w` → `sqlfluff` が整形
4. 赤波線は postgres_lsp（構文・型）と sqlfluff（lint）の両方 → `]d` で巡回

### 効く範囲（DB 接続の有無で変わる）

| 機能 | DB 未接続 | DB 接続時 |
|---|---|---|
| 構文診断（本物の PG パーサ） | ✅ | ✅ |
| 型チェック（EXPLAIN ベース） | ✅ | ✅ |
| キーワード・関数補完 | ✅ | ✅ |
| **自分のテーブル/カラム補完** | ❌ | ✅ |
| PL/pgSQL サポート | ✅ | ✅ |

> **まず DB 未接続で使い始めて OK**。本物の PostgreSQL パーサなので `ST_Intersects(...)` 等の PostGIS も正しく解釈する。テーブル/カラム補完が欲しくなったら下記で DB を繋ぐ。

### DB 接続でスキーマ補完を解禁（任意・Phase 2）

SQL を編集する**プロジェクトの直下**に設定ファイル **`postgres-language-server.jsonc`** を置く（このファイルが LSP の起動トリガも兼ねる）。中身:

```jsonc
{
  "db": {
    "host": "127.0.0.1",
    "port": 5432,
    "username": "postgres",
    "password": "postgres",
    "database": "your_db"
  }
}
```

> 🔒 **接続情報を git に commit しない**。パスワードを含むので、置いたプロジェクトの `.gitignore` にファイル名を追加すること。

### sqlfluff の方言設定（整形・lint の精度向上）

sqlfluff はデフォルト方言が `ansi`。PostgreSQL/PostGIS 構文を ansi で評価すると誤検出が増える。プロジェクト直下か `~/.sqlfluff` に:

```ini
[sqlfluff]
dialect = postgres
```

postgres 方言が `::` キャスト・`ST_*` 関数・`CREATE EXTENSION` 等を正しく通す（postgis 専用方言はないが postgres で十分）。

---

## トラブル時の切り分け順序（言語共通）

| 症状 | まず見る |
|---|---|
| 補完が出ない | `:LspInfo`（attach してるか）→ してなければ `:Mason` で LSP 確認 |
| 整形が変・効かない | `:ConformInfo`（何が走るか）→ `Space u f` で OFF してないか |
| 赤波線が多すぎ | lint の方言・設定（SQL なら `.sqlfluff` の dialect） |
| LSP が固まった | `:LspRestart` |
| そもそも色がつかない | `:checkhealth nvim-treesitter`（C compiler ✅ 必須・`docs/troubleshooting.md` 第 7 項） |

---

## 関連

- `docs/keybinds.md` — 全キーバインド（LSP・補完節）
- `docs/nvim-manual.md` — Vim 基本操作・VSCode 対応表
- `docs/troubleshooting.md` — 第 6 項（markdown 背景）・第 7 項（treesitter gcc）
- `nvim/lua/plugins/markdown.lua` — markdown の見た目調整の実体
- `nvim/lazyvim.json` — 有効化済 Extras（lang.markdown / lang.python / lang.sql）
</invoke>
