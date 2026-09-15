# トラブル対応記録

このリポジトリのセットアップで実際に遭遇した問題と解決策を残す。
**新規問題に当たったら必ず追記**（凡庸な選択を避けるための一次資料）。

---

## 1. 🔥 日本語 IME × Vim 風キーバインドが**動かない**

### 症状

- WezTerm のコピーモードで `h` `j` `k` `l` を押してもカーソル移動しない
- Neovim の Normal モードで hjkl やコマンドが効かない
- Esc を押しても Insert モードから抜けられない

### 原因

**Windows の IMM/TSF レイヤが、ASCII 文字キーを WezTerm/Neovim より先に奪っている**。

`config.use_ime = true`（WezTerm 設定）の場合、各アプリは IME を経由してキー入力を受け取る。IME が ON だと:

| キー | IME ON の挙動 |
|---|---|
| `h` `j` `k` `l` 等の文字 | IME がローマ字変換待ち状態にして握る → WezTerm/Neovim に届かない |
| 矢印キー `←↓↑→` | IME はスルー → 正常に届く |
| `Esc` | IME OFF は動作するが、その入力イベント自体が消費されることがあり Normal モード遷移しないことがある |
| `Ctrl+Shift+X` 等の修飾キー組合せ | IME はスルー → 正常に届く |

### 対策（優先順）

1. **コピーモード/Normal モードに入る前に必ず IME OFF**（`半角/全角` or `Alt+~`）
2. 矢印キーを使う（IME 影響なし）
3. **Neovim 側**: `:Tutor` で Esc 問題に当たったら `Ctrl+[` を Esc 代替として使う
4. 将来的に: 入口バインドで IME を強制 OFF する仕組み（Phase 4 検討事項）

### ステータス

- 2026-05-22: 矢印キーを WezTerm copy_mode に追加（hjkl と併設）

---

## 2. WezTerm 設定 reload しても古いハンドラが残る

### 症状

- `wezterm.lua` を編集して reload しても、過去の `wezterm.on("update-status", ...)` 等が画面に残骸を吐く
- `set_right_status` で旧 addon の文字列（`cwd=... branch=... ctx_remaining=...`）が出る

### 原因

`config.automatically_reload_config = true` は **config 値は再評価する**が、**`wezterm.on(...)` で登録した過去のイベントハンドラは解除しない**。
プロセスが生きてる限り、過去に登録した関数はメモリ上に残り続け、毎回 fire する。

### 対策

**WezTerm プロセスを完全に終了して再起動**（reload では不可）。
- 全タブ・ウィンドウを閉じる
- `Get-Process wezterm-gui` で残プロセス確認、必要に応じて `Stop-Process -Force`
- 新規 WezTerm 起動

### ステータス

- 2026-05-22: 確認・対処済み。`wezterm.lua` 内のコメントとしても明記。
- **2026-05-22 追記**: 透過率動的切替を試行錯誤する過程で同一セッション中に config reload を 30 回以上行った結果、過去の `update-status` ハンドラが蓄積し、`window_background_opacity` を md ペインだけで意図と逆の値（0.85）に書き換える現象が発生。**静的 `config.window_background_opacity = 0.95` 統一に方針変更後も、WezTerm を完全再起動するまで残骸ハンドラが上書きし続けた**。長時間のチューニングセッション後は WezTerm 再起動が必須。
- **2026-05-27 追記（精度向上）**: 一時的に入れたコピーモード時の緑背景 override（`update-status` の `overrides.colors.background`）を、ファイルを元に戻したあと **`Ctrl+Shift+R` のリロードだけで消せた**。区別: ハンドラが出す **config 値の上書き**（colors / opacity 等）は、最新クリーン版ハンドラが reload 後に最後に fire して上書きすれば reload で復帰できることがある。完全再起動が必須なのは、ハンドラの **重複登録そのものによる副作用**（残骸の文字列描画・競合による意図と逆の値書き換え）を断つ場合。「値の上書き合戦は最新版が勝てる／ハンドラの数は reload では減らせない」と覚える。

---

## 3. コピーモード突入時に「画面下に謎のプロンプト」

### 症状

WezTerm の CopyMode に入った瞬間、ペイン下部に見覚えのない「プロンプトらしき表示」が出る。
たとえば:

```
❯  
─────────────────────────────────────────
  ◆ Opus 4.7 (1M context) │ ◈ ctx:19%/1M
  ▸ ~/Documents/...
```

### 原因

**Claude Code の TUI statusline**（=Claude Code が自分の画面下部に常時描いている情報帯）。
WezTerm が画面を**凍結**し、カーソルが下方向に navigable になるため、普段視界の隅で流れていたものが初めて目に止まる。

### 対策

不要。Claude Code の正常動作。コピーモードの仕様。

### ステータス

- 2026-05-22: 切り分け完了。`wezterm cli get-text` で各ペイン下部を吸い出して確認した。

---

## 4. nvim が winget と scoop で 2 系統並存

### 症状

`where.exe nvim` が 2 つのパスを返す:
- `C:\Program Files\Neovim\bin\nvim.exe` (winget)
- `C:\Users\81809\scoop\shims\nvim.exe` (scoop)

PATH 順で勝者が決まるが、片方が自動更新で先行すると silent にバージョンが切り替わる。Claude Code の npm 版残骸問題と**同型のリスク**。

### 対策

`scoop uninstall neovim` で物理削除し、`winget` に一本化（`initial-prompt.md` の意思決定に整合）。

### ステータス

- 2026-05-22: 完了。winget 0.12.2 単独構成。

---

## 6. Markdown のヘッダー/コードブロックに背景塗りが残る

### 症状

`lang.markdown` Extras 有効化後、`render-markdown.nvim` を `enabled = false` にしても、見出し行・コードブロック・引用ブロックの**背景色塗り**が消えない。Treesitter の文字色付けは効いているのにベタ塗り背景だけが残る。

### 原因

**2 つの罠が重なっていた**:

1. **`render-markdown.nvim` のさらに下層に、Treesitter の `@markup.*` ハイライトグループ自体に背景色が設定されている**。tokyonight などの colorscheme が下記グループに `bg` を入れているため、render-markdown を無効化しても下の層が残る:
   - `@markup.heading.1.markdown` 〜 `@markup.heading.6.markdown`
   - `@markup.raw.block.markdown`（コードフェンス）
   - `@markup.quote.markdown`
   - 旧 syntax 互換の `markdownH1`〜`markdownCodeBlock` も同様

2. **`ColorScheme` autocmd だけでは取り逃す**。LazyVim は起動時に colorscheme をロード → `ColorScheme` イベント発火、そのあとにプラグイン spec の `init` が走るため、**autocmd が登録される時点で ColorScheme は既に発火し終わっている**。よって登録した autocmd が一度も呼ばれず、bg=NONE 上書きが効かない。

### 対策

`init` で 3 イベントに同じ callback を登録する:

```lua
vim.api.nvim_create_autocmd("ColorScheme",   { pattern = "*",  callback = strip })
vim.api.nvim_create_autocmd("VimEnter",      { callback = strip })  -- 起動直後の決定打
vim.api.nvim_create_autocmd("FileType",      { pattern = { "markdown" }, callback = strip })
```

`VimEnter` が決定打で、起動直後の colorscheme ロード済状態で必ず実行される。`FileType markdown` は実際に md を開いた時の念押し。

### ステータス

- 2026-05-22: `nvim/lua/plugins/markdown.lua` で対処完了。`render-markdown.nvim` 自体は `enabled = false` のまま、Treesitter のグループ bg だけを上書き除去している。

---

## 5. 既存 `%LOCALAPPDATA%\nvim` が LazyVim ではなく手書き lazy.nvim 設定だった

### 症状

LazyVim スターターを入れる前提だったが、既に手書き lazy.nvim 設定が存在し（init.lua、lua/config、lua/plugins フル装備）、内容も非自明（gruvbox-material、LSP 手書き、neo-tree、Telescope 等）。

### 対策

2 重保全:
- ファイルシステム: `%LOCALAPPDATA%\nvim` → `%LOCALAPPDATA%\nvim-backup-2026-05-22`
- リポジトリ: `setup-neovim-wezterm\docs\legacy-nvim\` にコピー（Git 追跡で永久保存）

`%LOCALAPPDATA%\nvim-data` も同様に `-backup-2026-05-22` にリネーム。

### ステータス

- 2026-05-22: 完了。次フェーズで LazyVim スターターをクリーン導入予定。

---

## 7. nvim 起動時 `Unmet requirements for nvim-treesitter: C compiler ❌`

### 症状

LazyVim 起動直後（`VeryLazy` autocmd）に赤字エラー:

```
Error in User Autocommands for "VeryLazy":
Unmet requirements for nvim-treesitter `main`:
- ❌ `C compiler`
- ✅ `curl`
- ✅ `tar`
- ✅ `tree-sitter (CLI)`
Press ENTER or type command to continue
```

`curl` / `tar` / `tree-sitter` は揃っているが **C コンパイラだけ欠落**。

### 原因

`nvim-treesitter`（`main` ブランチ）は各言語パーサを**実行環境でCソースからその場コンパイル**する設計。Windows 11 素の状態には gcc/clang が無いため要件未達。放置するとパーサ生成に失敗し、シンタックスハイライト・インデントが効かない。

### 対策

エラーメッセージ自身が案内する winget コマンドで **WinLibs (MinGW-w64 / gcc)** を導入:

```powershell
winget install --id=BrechtSanders.WinLibs.POSIX.UCRT -e
```

導入後の確認（**PATH 関連の教訓どおり新規ターミナルで実体確認**）:

| 確認項目 | コマンド | 期待値 |
|---|---|---|
| 実体パス | `where.exe gcc` | `...\WinLibs.POSIX.UCRT_..._8wekyb3d8bbwe\mingw64\bin\gcc.exe` |
| バージョン | `gcc --version` | `gcc.exe (MinGW-W64 x86_64-ucrt-posix-seh ...) 16.1.0` |
| nvim 側 | `:checkhealth nvim-treesitter` | `C compiler` が ✅ |

User PATH に追加された bin（新規シェルで有効・既存シェルは要再起動）:
`C:\Users\81809\AppData\Local\Microsoft\WinGet\Packages\BrechtSanders.WinLibs.POSIX.UCRT_Microsoft.Winget.Source_8wekyb3d8bbwe\mingw64\bin`

### ステータス

- 2026-05-26: WinLibs gcc **16.1.0**（UCRT / POSIX threads）を winget で導入完了。インストール直後の既存シェルでは PATH 未反映のため、実体パス直叩きで `gcc --version` 動作を確認済。**WezTerm / Neovim を再起動**すれば PATH 反映され、`:checkhealth nvim-treesitter` で C compiler ✅ になる見込み。
- **2026-06-18: 解決確認（CLOSE）**。`where.exe gcc` → WinLibs 16.1.0、nvim headless で `vim.fn.executable('gcc')=1`、さらに **treesitter パーサが 27 個コンパイル済**（bash/c/lua/sql/python/markdown 等）。パーサ生成は gcc 成功が前提なので C compiler は実働確定。backlog B4 CLOSED。

---

## 8. SQL に LSP が無い（補完・定義ジャンプ不可） → postgres_lsp 導入

### 症状

`.sql` を開いても `K`（hover）も `g d`（定義ジャンプ）も補完も効かない。整形（`:w` で sqlfluff）と Treesitter 色分けは効く。

### 原因

LazyVim の `lang.sql` Extras は **整形/lint (sqlfluff) しか入れず、LSP サーバを入れない**。Mason 実体を直接確認したところ SQL 系 LSP のバイナリが一つも無かった（2026-05-26 調査）。設定漏れではなく Extras の仕様。

### 対策（採用: postgres_lsp）

候補比較の結論:

| 候補 | 判定 | 理由 |
|---|---|---|
| `sqls` | ✗ | GitHub **archived**・Mason から消えた・lspconfig 非推奨 |
| `sqlls`（sql-language-server） | △ | 汎用。PG 固有構文に弱く、補完に DB 接続必須 |
| **`postgres_lsp`（postgres-language-server）** | ◎ **採用** | PostgreSQL 特化。本物の PG パーサ (libpg_query) で PostGIS も正しく解釈。**DB 未接続でも**構文診断・型チェック・関数補完・hover が動く。Supabase が活発にメンテ |

設定: `nvim/lua/plugins/sql-lsp.lua`（lspconfig 登録 + Mason ensure_installed）。

### 導入時の地雷（重要・mason registry v0.25.0 / lspconfig 実定義で確認済）

1. **名前を間違えると Mason が起動時にエラーを出す**（初回これで踏んだ）。正しい名前:
   - Mason パッケージ名 = **`postgres-language-server`**（×`postgrestools`。旧称につられると `ensure_installed` で「パッケージ無し」エラー）
   - 実体バイナリ = `postgres-language-server`
   - lspconfig サーバ名 = `postgres_lsp`
   - `:MasonInstall postgres-language-server` で入れる。
2. **lspconfig 既定 cmd は `{ "postgres-language-server", "lsp-proxy" }`** で正しい → `sql-lsp.lua` で cmd を上書きしない（最初 `postgrestools` で上書きしていたのが誤り）。
3. mason-lspconfig 連携は使わず `mason = false` + mason.nvim の `ensure_installed` に一本化（決定的に・名前の取り違え防止）。registry には `neovim.lspconfig: postgres_lsp` マッピングが存在する。
4. **起動条件が厳しい（最重要）**: lspconfig 定義が `workspace_required = true` / `root_markers = { "postgres-language-server.jsonc" }`。**プロジェクト直下にこのファイルが無いと attach しない**（単独 `.sql` では黙ったまま＝エラーも出ない）。使いたいプロジェクトで opt-in する設計。
5. **設定ファイル名は `postgres-language-server.jsonc`**（root_markers で確定）。これが LSP 起動トリガ兼 DB 接続設定。`db` セクションでスキーマ補完解禁。接続情報は **git に commit しない**（要 `.gitignore`）。

### ステータス

- 2026-05-26: 当初 `sql-lsp.lua` で **パッケージ名を `postgrestools` と誤記** → nvim 起動時に Mason が「パッケージ無し」エラー。registry / lspconfig 実定義を確認し `postgres-language-server` に修正・cmd 上書きも撤去。
- 2026-05-26（追記・真因判明）: 再起動でエラーが再発し続けた**本当の原因は Mason でも LSP でもなく、`sql-lsp.lua` のファイル末尾に `</content>` という不正タグが混入していたこと**（書き込み時のアーティファクト）。`</content>` の `/` が Lua のコードとして解釈され「`sql-lsp.lua:30: unexpected symbol near '/'`」= 構文エラー → プラグイン読込前に落ちるため `mason.log`/`lsp.log` には出ず、起動画面右上に "Failed to load plugins.sql-lsp" と表示。スクリーンショットで文言を確認して特定。同種の `</content>` 混入が `docs/` の 4 ファイル（cheatsheet / lang-workflows / practice-drills / vim-mental-model）にもあり除去済（md なので無害だった）。
  - 教訓: 「プラグインが読めない」系は **まず該当 .lua の構文を疑う**。`nvim --headless -c "lua assert(loadfile([[path]]))" -c "qa!"` で一発判定できる。ログに出ない＝読込前のパースエラー。
- 現状: `sql-lsp.lua` は `return {}` でクリーンに無効化（構文 OK を headless nvim で検証済）。SQL 作業は dadbod + sqlfluff + treesitter で回る。再有効化したくなったら、真因は単なる混入タグだったので**正しい設定（本項 1〜5）を入れれば素直に動く見込み**。

---

## 9. dadbod-ui で DB に繋いでも「中身が見えない」 → psql が PATH に無い

### 症状

`:DBUIToggle` で接続は出るが、展開してもテーブルが見えない／結果が出ない。「db postgres にしたけど見えない」。

### 原因

**vim-dadbod は PostgreSQL と話すのに `psql`（PostgreSQL クライアント）を内部で呼ぶ。** これが PATH に無いと、接続はできても問い合わせが空振りして中身が見えない。

実体調査（2026-05-26）:
- PostgreSQL 18 + PostGIS 3.6.2 は**インストール済・稼働中**（サービス `postgresql-x64-18` Running、5432 LISTEN）。pgAdmin 4 もあり。
- しかし `where.exe psql` が**見つからない** = User PATH に PostgreSQL の bin が無い。`psql.exe` の実体は `C:\Program Files\PostgreSQL\18\bin\psql.exe`。

> EDB / winget 版 PostgreSQL は **bin を自動で PATH に通さない**。これが Windows での dadbod 詰まりの定番。

### 対策

User PATH に `C:\Program Files\PostgreSQL\18\bin` を追記（`setx` は PATH を 1024 文字で切る事故があるため使わず、User スコープへ安全に追記）:

```powershell
$bin = "C:\Program Files\PostgreSQL\18\bin"
$userPath = [Environment]::GetEnvironmentVariable("Path","User")
if (-not ($userPath.Split(';') -contains $bin)) {
  [Environment]::SetEnvironmentVariable("Path", $userPath.TrimEnd(';') + ';' + $bin, "User")
}
```

そのあと **PATH 教訓どおり**:
1. **新規ターミナル**を開く（既存シェル・既存 WezTerm は旧 PATH のまま）
2. `where.exe psql` で実体確認（`...\PostgreSQL\18\bin\psql.exe` が出れば OK）
3. **WezTerm を完全再起動**（nvim は起動元ターミナルの環境を継承するため、古い WezTerm 配下の nvim には新 PATH が届かない）
4. nvim で `:DBUIToggle` → 接続展開 → テーブルが見えるか確認

接続が一覧に無ければ `:DBUIAddConnection` で追加（`postgresql://postgres:＜インストール時のパスワード＞@localhost:5432/postgres`）。

### ステータス

- 2026-05-26: User PATH に `C:\Program Files\PostgreSQL\18\bin` 追記済（Claude が実行・確認済）。**新規ターミナル + WezTerm 完全再起動**でユーザー側が `where.exe psql` と `:DBUIToggle` を確認するのが残タスク。

### 追記: 「見えない」の真因はもう一つあった ― 接続先 DB の間違い

PATH（psql）に加え、**接続先 DB を間違えていた**のが主因。ユーザーは dadbod を初期 DB `postgres`（空）に向けていたが、実データは **`kanro_db`**（水道管路 GIS 業務 DB・14 スキーマ・テーブル 500 超）にあった。空 DB を覗いていたので「見えない」。

対策:
1. `nvim/lua/config/options.lua` に `vim.g.dbs` を定義し **接続先を `kanro_db` に固定**（`:DBUIToggle` に「kanro_db (local)」が最初から出る）。URL は `postgresql://postgres@localhost:5432/kanro_db`（パスワードは書かない）。
2. 認証は **`%APPDATA%\postgresql\pgpass.conf`**（`localhost:5432:*:postgres:＜pw＞`）。psql/dadbod が無人で読む。
3. **検証済（2026-05-26）**: `psql -w -d kanro_db`（pgpass 経由・プロンプト無し）で接続成功・21 スキーマ取得。dadbod も同経路。残るは WezTerm 完全再起動のみ。

### ステータス（2026-06-18 CLOSE）

headless で全層検証し解決確定（backlog B3 CLOSED）:
- `where.exe psql` → PostgreSQL 18.3。**pgpass 無人接続成功**（`psql -U postgres -w -d kanro_db`）で **587 テーブル / 15 スキーマ**取得。MCP `mcp__postgres__query` でも 587/15 一致（別経路で裏取り）。
- nvim 実 config で `vim.g.dbs` = `kanro_db (local)` / `postgresql://postgres@localhost:5432/kanro_db`（user=postgres → pgpass 一致）。`:DBUI` コマンド存在・`vim-dadbod`/`-ui`/`-completion` 実体あり。
- 残るは GUI で `:DBUIToggle` のツリー目視のみ（下層が全通過のため飾り）。
- 罠（自戒）: 素の `psql -w -d kanro_db` は **OS ユーザー名で接続**するため pgpass(`postgres`)と不一致で `no password supplied`。dadbod と同条件にするには **`-U postgres` 明示**が必須。

> 教訓: dadbod で「接続は出るのに空」のときは **(a) psql が PATH にあるか (b) 接続先 DB 名が正しいか** の 2 点を必ず疑う。MCP（`mcp__postgres__query`）で実 DB の中身を確認すると DB 名の取り違えが一発で分かる。

---

## 10. MCP（postgres/playwright/notionApi）が `/doctor` で 3 件 timeout エラー

### 症状

- `/doctor` で postgres / playwright / notionApi の 3 つが `connection timed out after 30000ms`。
- だが `claude mcp list` では全部 ✓ Connected と出る（**1 個ずつ順に確認するため取りこぼす**）。
- 2026-06-16 のログで確定: その日の**最初の起動（16:44, コールド）で 3 つ同時に 30s timeout → 2 分後の再起動（16:46, ウォーム）では 3 つとも 2〜3 秒で成功**。

### 原因

`npx -y <pkg>@<ver>` は**バージョン固定でも起動のたびに npm レジストリへ解決問い合わせが走る**。3 つ同時のコールド起動（その日初回・npm キャッシュ冷え・ディスク冷え）で 30s 制限を超過する。2026-06-08 の「バージョン固定＋グローバル導入」対処は**ウォーム起動を 1.3s に縮めただけ**で、コールド timeout は残っていた。DB 到達・ブラウザ・トークンは無関係。

### 対策（恒久・採用）

**`npx` を完全に外し、グローバル導入済みパッケージの実体を `node <entry.js>` で直叩き**する。npx のレジストリ解決がゼロになり、コールドでも即起動（実測: postgres 172ms / playwright 432ms）。

`claude mcp` CLI で user スコープを surgical に書換え（`.claude.json` は巨大かつ casing 重複キーがあり手編集・JSON round-trip は危険なので CLI を使う）:

```powershell
$node = "C:\Program Files\nodejs\node.exe"
$nm   = "C:\Users\81809\AppData\Roaming\npm\node_modules"
# notion トークンは既存 config から読み出して保全（画面に出さない）
$tok  = (Get-Content "$env:USERPROFILE\.claude.json" -Raw | ConvertFrom-Json -AsHashtable).mcpServers['notionApi'].env['NOTION_TOKEN']

claude mcp remove postgres -s user; claude mcp remove playwright -s user; claude mcp remove notionApi -s user
& claude mcp add postgres   -s user -- $node "$nm\@modelcontextprotocol\server-postgres\dist\index.js" "postgresql://postgres:＜postgresのパスワード＞@localhost:5432/kanro_db"
& claude mcp add playwright -s user -- $node "$nm\@playwright\mcp\cli.js"
& claude mcp add notionApi  -s user -e "NOTION_TOKEN=$tok" -- $node "$nm\@notionhq\notion-mcp-server\bin\cli.mjs"
```

実体 entry は各 package の `package.json` の `bin` フィールドで確認（postgres=`dist/index.js`、playwright=`cli.js`、notion=`bin/cli.mjs`）。node は絶対パス推奨（MCP 起動コンテキストの PATH に依存しない）。

> パッケージ更新時は `npm i -g <pkg>@<新ver>` するだけ。**entry パスは変わらない**ので MCP 設定の再編集は不要。これも npx 版より楽。

### ステータス

- 2026-06-16: 3 サーバを node 直叩きへ移行・`claude mcp list` で全 ✓・直接起動を実測（172/432ms）。playwright も `0.0.75 → 0.0.76` に更新。**反映は次回 Claude Code 起動から**（`/doctor` で 3 件消えるか確認が残タスク）。
- **2026-06-18: 解決確認（CLOSE）**。MCP ログ（`mcp-logs-*/*.jsonl` の `debug` フィールド）実測で、当日初回コールド起動でも postgres 644ms / playwright 635ms / notionApi 392ms と全て sub-second 接続。06-16 朝の npx 版コールド（3 件とも 30s timeout）と対照になり、`npx→node 直叩き`の恒久対処が効いていると確定。`docs/backlog.md` の CLOSED へ転記済。
- 注意（別件・要確認）: notion トークンが config 上はまだ旧トークン（`ntn_***`）のままに見える。memory では 06-08 に「旧トークン（`ntn_***`）失効 → 新統合トークンに差し替え済」とあるが値が一致して見える。timeout とは無関係（接続成功＝プロセス起動成功で、401 は API 呼び出し時にしか出ない）。Notion が空応答／401 のときはトークン再発行と対象ページの Connections 追加を疑う。

### 教訓

- **MCP が「list では OK なのに /doctor で timeout」=同時コールド起動の競合**。`claude mcp list` の逐次 ✓ に騙されない。真偽は `%LOCALAPPDATA%\claude-cli-nodejs\Cache\<proj>\mcp-logs-<srv>\*.jsonl` の `Successfully connected in Nms` / `timed out` で確定する。
- **stdio 系 MCP は `npx` を介さず実体直叩きが最速・最安定**。npx は「未導入でも動く」利便性と引換えに毎回レジストリ解決コストを払う。常用するなら固定版グローバル導入＋直叩き一択。

---

## 11. 同名 `"LazyVim/LazyVim"` spec に `init` を複数書くと黙って 1 つしか動かない

### 症状

- markdown を開いても `conceallevel` が 0 にならない（実測 2 のまま）＝ `markdown.lua` の conceal オフ設定が効かない。
- 非 tokyonight カラースキームに対する「透過保険」ColorScheme autocmd（`colorscheme.lua`）も発火しない。
- エラーは一切出ない（黙って死ぬので気づきにくい）。

### 原因

`nvim/lua/plugins/` の複数ファイルが同じプラグイン名 `"LazyVim/LazyVim"` の spec に **それぞれ `init` を書いていた**（`colorscheme.lua` 透過保険 / `markdown.lua` conceallevel=0 / `markdown.lua` strip_md_bg の計 3 つ）。

lazy.nvim は同名 spec の fragment を**マージするが、`init`/`config` は `opts` のように合成せず last-wins（最後の 1 つだけ採用）**する。`opts`/`cmd`/`event`/`ft`/`keys` はリスト/テーブルマージされるが、`init`/`config` は metatable の `__index` チェーンでスカラ解決され、最も後ろの fragment の値だけが残る（`lazy.core.plugin` の `M._values` に init は含まれない）。fragment 順 = **ファイル名アルファベット順 → ファイル内の配列順**。

結果、`markdown.lua` 内の最後の init（strip_md_bg）だけが生き残り、他 2 つの init は一度も呼ばれていなかった。

### 対策

**同名 spec の `init` は 1 つに統合する**（衝突自体を消す）。`colorscheme.lua` の単一 `"LazyVim/LazyVim"` spec の init 内で、透過保険・conceallevel=0・strip_md_bg の 3 つの autocmd 登録をまとめて行うようにした。`markdown.lua` からは `"LazyVim/LazyVim"` spec を削除（render-markdown 無効化と nvim-lint の spec は別プラグインなので残す）。

> ❌ **`config/autocmds.lua` への移設は今回は不適**。autocmds.lua は **VeryLazy で読まれる**ため、そこで `VimEnter` autocmd を登録しても VimEnter は既に発火済みで動かず、`ColorScheme` も既にロード済テーマに fire しない。init は colorscheme ロード前に登録される必要がある（strip_md_bg が VimEnter を「決定打」にしている理由）。よって init 集約が正解。

### 検証

```bash
nvim --headless probe.md -c 'lua vim.defer_fn(function() print(vim.wo.conceallevel) vim.cmd("qa!") end,1200)'   # → 0
# ColorScheme autocmd 一覧に透過保険 + strip_md_bg の両方が出ること
```

### ステータス

- 2026-06-16: `colorscheme.lua` に 3 autocmd を集約・`markdown.lua` の重複 spec を削除。headless で conceallevel=0・ColorScheme autocmd 8 件を確認。各 spec ファイルに「init を分けて書くな」と注記済。

### 教訓

- **同名プラグイン spec に `init`/`config` を分散させない**。複数の起動時処理が必要なら 1 つの init に集約するか、別々の一意なプラグイン名にぶら下げる。`opts` は安全にマージされるが `init`/`config` は last-wins で黙って消える。

---

## 12. あるペインだけ入力が効かなくなる → 修飾キー stuck（勝手に復活）

### 症状

- WezTerm で**フォーカス中のペインのキー入力が効かなくなる**（別ウィンドウは無事）。
- **stuck はウィンドウ単位**: 同一ウィンドウ内なら複数ペインが「同時に死んだ」ように見える（2026-07-06 に 2 ペイン同時凍結 → 両方修飾タップで復活、を実測。1 個の stuck で説明がつく）。**別ウィンドウ同士で同時発生**した場合のみ別要因（compositor/GPU 停滞等）を疑う。次回発生時は「同一ウィンドウか別ウィンドウか」を 1 行記録すること。
- しばらくすると**勝手に復活**する（何をして直ったか本人も不明なことが多い）。
- ペイン/プロセスは全て生存（`wezterm cli list` で全ペイン正常・`is_zoomed:false`・key_table 暴発もなし＝コピーモードでもない）。

### 原因

**修飾キー（Ctrl/Shift/Alt/Win）の key-up を WezTerm が取りこぼし、「押しっぱなし」状態のまま**になっている。修飾キーを押したまま**別ウィンドウへフォーカス移動**（Alt+Tab、別ウィンドウクリック、グローバルショートカット）すると、key-up イベントが別ウィンドウに飛んで WezTerm に届かない。以後そのウィンドウでは普通のキーが「Ctrl+○」等のショートカット扱いになり、**入力が効かないように見える**。もう一度その修飾キーを押して離すと状態がクリアされる＝「勝手に復活」の正体。

WezTerm × Windows の**積年の既知問題**。`20260117` 系（最新）でも残っており、`clear_modifiers_on_focus_loss` のような設定フラグは存在しない。**コードでは直せない**（API で stuck 状態を強制クリアできない）。

### 切り分け手順（次回発生時・5 秒）

1. **Ctrl・Shift・Alt・Win を 1 回ずつ単独でタップ** → 即復活すれば**修飾 stuck 確定**（本項）。
2. 直らなければ **半角/全角で IME OFF** → 適当キー（IME 変換 stuck の切り分け＝地雷 #1 の亜種）。
3. それでもなら**そのペインをマウスでクリックして再フォーカス**。

### 対策

| 種別 | 内容 |
|---|---|
| 恒久（運用） | 固まったら **修飾キーを 1 回タップ**（正規の直し方） |
| 予防 | 修飾キーを**押したまま Alt+Tab しない**（離してから切替）。頻度が激減 |
| コード修正 | 無い（追う価値低） |

### ステータス

- 2026-07-02: 4 ペイン（全 claude セッション）運用中に 1 ペインの入力不能が発生 → **Ctrl/Shift/Alt/Win タップ（切り分け手順①）で復活し、修飾キー stuck と確定**。`wezterm cli list` で全ペイン生存を確認済。設定バグではなく OS レベルの入力状態 stuck。
- 2026-07-06: **2 ペイン同時凍結** → 片方は即タップで復活、もう片方もフォーカスし直して再タップで復活（フォーカスした状態でタップするのが肝）。同時多発は「stuck がウィンドウ単位」の性質と整合。
- 2026-08-20: 「**画面を切り替えた時**にペインがバグって文字入力できなくなる」と再発の報告。「画面切替時」という発生条件自体が本項の原因（修飾キーを押したままフォーカス移動 → key-up 取りこぼし）と完全に一致する。**wezterm.lua（Lua 設定）は無関係**: config にはキーの修飾子状態を触る API が無く、同じ設定でも他ウィンドウは無事（入力不能がウィンドウ単位で分かれる）ことが設定非起因の証拠。切り分け手順①（修飾キータップ）で直るなら本項、直らなければ #13。
- 2026-07-06 上流裏取り（監査）: 最新 nightly（2026-06-27）まで追っても key-up 取りこぼしの修正・緩和フラグは**存在しない**（関連 wezterm/wezterm#4621 も open のまま）＝**アップグレードでは直らない**。運用回避（タップ）継続が正解。

### 教訓

- 「1 ペインだけ入力不能 → 勝手に復活」= **ほぼ修飾キー stuck**。まず修飾キーをタップさせる。設定を疑う前に `wezterm cli list` で全ペイン生存・非 zoom・非コピーモードを確認すれば、config 側の犯人探しに時間を溶かさずに済む。

---

## 13. あるペインだけ入力不能 → 修飾キータップで直らない版（Claude Code TUI の描画 wedge）

> #12（修飾キー stuck）と**症状が似ているが別物**。#12 の直し方（修飾キータップ）が効かなかったらこちら。

### 症状

- **特定の Claude Code ペイン**（アイドル ✳）だけキーボード入力を受けつけない。
- **勝手に画面下部へスクロール**する／末尾に貼り付いたまま。
- `Ctrl/Shift/Alt/Win` の単独タップ（#12 の対処）でも**直らない**。

### 切り分け（`wezterm cli get-text` で中を覗く）

```powershell
wezterm cli list --format json | ConvertFrom-Json | Where-Object { $_.pane_id -eq <N> } | Format-List pane_id,is_zoomed,cursor_visibility
wezterm cli get-text --pane-id <N>
```

2026-07-03 の実例では、入力不能ペインの中身が:

```
 Esc to cancel · Tab to amend · ctrl+e to
 explain
（以下、本文は空白）
```

で `cursor_visibility: Hidden`。これは **Claude Code の TUI（Ink/React 製）が何らかのオーバーレイ状態で描画 wedge している**状態。OS の修飾キー stuck ではなく、**そのペインの Claude プロセス側の TUI 状態**が原因。

### 対策（ユーザーの直接操作＝これが確実）

上から順に:

1. **マウスでペイン内を物理クリック**してフォーカス（クリックは focus/修飾 stuck を迂回）
2. **`Esc` を1〜2回**（フッターの "Esc to cancel" が正規の脱出）→ `❯` プロンプトに戻る
3. 戻らなければ **`Ctrl+C`** 1回（現在処理の割り込み）
4. それでも wedge なら最終手段: **そのペインを閉じて、同じ cwd で `claude --continue`**（セッション＝会話は復元される。ペインだけ作り直す）

### 🚫 やってはいけない: Claude（アシスタント）側からの遠隔修復

2026-07-03 に遠隔修復を試みて**逆効果**だったので明記する:

| 遠隔手段 | 結果 |
|---|---|
| `wezterm cli send-text`（Esc/文字を注入） | **Claude Code の TUI に入力として届かない**。send-text は「paste 扱い」で送るが、Claude Code は bracketed-paste モードのため注入文字をキーストロークとして拾わない。**正常なペインでも `a` が composer に出ない**ことで確認済 |
| `wezterm cli zoom-pane`（SIGWINCH 再描画狙い） | wedge を解けないうえ **mux の CLI 応答をデッドロック**させた。以後 `wezterm cli list` すら 8s timeout（exit 124）。ハングした `wezterm.exe`（**`wezterm-gui.exe` ではない** client プロセス）を kill しても mux は復旧せず |

重要: **この mux ハングはユーザーのキーボード入力には影響しない**（GUI のキー処理は別系統で生きている）。影響は「Claude の遠隔操作」だけ。だが遠隔で直そうとすると副作用が出るので、**入力不能ペインの復旧は必ずユーザーの直接操作で行う**。mux は放置すれば回復するか、wedge ペインが解消すれば戻る（GUI 再起動は全セッションを閉じるので不可）。

- kill してよいのは `wezterm.exe`（CLI client 残留）だけ。`wezterm-gui.exe`（実ウィンドウ本体・複数モニターで複数存在しうる）は**絶対 kill しない**。判別: `Get-Process wezterm*` で ProcessName と StartTime を見る。

### ステータス

- 2026-07-03: 4 ペイン運用中、アイドルの Claude ペイン（Instagram-project-v2）が入力不能＋末尾自動スクロール。修飾キータップで直らず。`get-text` で "Esc to cancel" オーバーレイの wedge と特定。**遠隔修復（send-text / zoom-pane）は不発かつ mux CLI をデッドロックさせたため打ち切り**。復旧はユーザーの直接操作（クリック→Esc→Ctrl+C→最終 `claude --continue`）に一本化。頻発するとの申告。backlog **W3** に登録。

### 上流の正体（2026-07-06 監査で裏取り）

anthropics/claude-code に**同型バグ報告が多数**あり、これは **Claude Code 本体（Node/Ink TUI）の不具合クラス**: #20572（spinner 静止・入力不能・Esc 無効、イベントループのデッドロック疑い）、#25286（全キー無視）、#22970（Windows で起動直後から入力層フリーズ）、#23211（**Windows Terminal でも発生＝ターミナル非依存。v2.1.30 の regression が版更新で修正された実例**）。複数 OS・複数ターミナルで再現しており **wezterm 固有ではない**。

→ 対策は 2 つだけ: **(1) claude 本体をこまめに更新する**（版依存が実証済）。**(2) wezterm 側の設定変更（GPU レンダラー含む）で直そうとしない**（効果ゼロ。#14 参照）。W3 発生時は `claude --version` をこのステータス欄に併記して版依存を特定する。

### 教訓

- **#12 と #13 の分岐点は「修飾キータップで直るか」**。直れば #12（OS の修飾 stuck）、直らず `get-text` にオーバーレイが見えたら #13（Claude TUI の描画 wedge）。
- **入力不能ペインを Claude（アシスタント）に遠隔で直させようとしない**。send-text は Claude TUI に届かず、pane 操作系は mux を wedge させるリスク。人間の直接操作が最短・最安全。

---

## 14. GPU レンダラー（WebGpu）は試して不採用 → 既定 OpenGL のまま

### 経緯

- 2026-07-03: 凍結問題の対策候補として `config.front_end = "WebGpu"` + `config.webgpu_power_preference = "HighPerformance"` を wezterm.lua に追加（Optimus 構成: Intel iGPU + RTX 3050 で省電力側 GPU が選ばれる可能性への対処）。**未コミットのまま 3 日稼働**。
- 2026-07-06: 全体監査の stability 次元で上流裏取り → **不採用と決定し削除**。

### 不採用の根拠

1. **凍結 2 種はどちらも GPU 非起因**: #12（修飾 stuck）は GPU 変更**前**の 07-02 に初発、#13 は Claude Code 本体のバグクラス。つまり WebGpu 化は何も直さない。
2. **WebGpu は同型環境で故障報告が複数**（いずれも open）:
   - wezterm/wezterm#4278: Win11 + Optimus（iGPU+RTX）で WebGpu のみ間欠入力ラグ → **OpenGL で完治**
   - #4502: Win11 + NVIDIA で **WebGpu だと `window_background_opacity` が壊れる**（本環境の透過 0.95 直撃）
   - #7611: **本機と同一ビルド**（20260117）で G-SYNC 誤発動 → TUI 中マウス激重（`max_fps` 指定でも無効）
3. wezterm 本家も WebGpu を既定化した直後に **OpenGL へ差し戻した**経緯あり（公式 front_end doc: "The default for front_end is again OpenGL"）。

### 対処

- **Optimus のアダプタ固定が必要なら Windows 設定 > グラフィックス で `wezterm-gui.exe` を「高パフォーマンス」指定**（config 変更不要でアダプタ選択の目的を達成できる）。→ backlog **B7**
- wezterm 更新判断: 最新 nightly に **IME 半角/全角トグル × ペイン分割のクラッシュ修正（#7529）**があり本ユーザーの操作パターンに直接関係するが、W2/W3 は直らないため**据え置き**。IME トグル起因のクラッシュを 1 度でも観測したら GitHub releases から直接更新（winget の nightly はハッシュ不一致報告 #7623/#7713 あり）。

### 教訓

- 「調子が悪い → GPU/レンダラーをいじる」は本環境では**筋が悪い**。凍結の正体は #12（OS 入力状態）と #13（Claude 本体）で確定しており、レンダラー変更はどちらにも効かず新しい故障モード（入力ラグ・透過破損）だけ持ち込む。
- 挙動に効く設定変更は**その日のうちにコミット + backlog 記録**（symlink 運用では未コミットでも live に効いてしまい、`git checkout` 一発で黙って巻き戻るドリフト状態になる）。

---

2026-09-14 完了確認（B7 CLOSED）: Windows設定によるWezTermのGPU高パフォーマンス固定について、ユーザーが「b7ok」と確認。既定OpenGLでの運用を継続する。

## 15. `powershell/profile.ps1` が一度も読まれていなかった → WezTerm の既定シェルが cmd.exe

### 症状

2026-07-16、「対話起動を既定で Remote Control 化する」ために `profile.ps1` に `claude` ラッパーを実装（`3d9475b`）したのに、**起動しても Remote Control にならない**。

### 原因（実プロセスで確定）

`wezterm.lua` に `default_prog` が無く、WezTerm は **Windows 既定の cmd.exe** を起動していた。プロセスツリー実測:

```
wezterm-gui.exe (4656)
 └─ cmd.exe ×6          ← WezTerm の既定シェル
     └─ claude.exe ×5   ← 稼働中の全 Claude セッション
```

pwsh は 1 つも走っていない（statusline の `-NoProfile` 実行を除く）。つまり `$PROFILE` → `profile.ps1` の dot-source が**発火する機会そのものが無く**、`claude` ラッパーだけでなく `repo`/`v`/`vrepo`/`kanro`/`remote`/`usage` の**全関数が最初から死んでいた**（2026-06-18 の B5 新設以来）。README/CLAUDE.md の「シェル: PowerShell（cmd.exe は使用しない）」とも矛盾していた。

**教訓**: 「シェル関数を書いた」は「シェルがそれを読む」を意味しない。プロファイル方式の実装は**プロセスツリーで親シェルを実測**してから信じる（`Get-CimInstance Win32_Process`）。

### 対処

1. `wezterm.lua` に `config.default_prog = { "pwsh.exe", "-NoLogo" }` を明示（`-NoProfile` は付けない＝付けると独自コマンドが全滅）。
2. Remote Control の自動接続は**シェル層でやらない**。`~/.claude/settings.json` の `"remoteControlAtStartup": true` が正解（下記 #16）。ラッパーは撤去した。

### 副次的な地雷: 実行中インスタンスには反映されない

`automatically_reload_config = true` でも、**`default_prog` の変更は稼働中の WezTerm に反映されなかった**（実測: 編集 1 分後も `wezterm cli spawn` は cmd.exe を起動）。config は symlink 経由（`~/.config/wezterm/wezterm.lua` → repo）で、ウォッチャは repo 側の書き込みを拾えていない疑いが濃い。

検証は**独立プロセス**で行える（既存ウィンドウを壊さない）:

```powershell
wezterm --config-file <repo>\wezterm\wezterm.lua start --always-new-process
# → 子プロセスが pwsh.exe なら OK。実測で cmd.exe → pwsh.exe を確認
```

→ **反映には WezTerm の完全再起動が必要**。

---

2026-09-14 解決確認（B8 CLOSED）: 稼働中WezTerm直下のシェルはpwsh -NoLogo、新規PowerShellでrepo/v/usage/remoteを認識。ユーザーも実機状態を「概ね問題なさそう」と確認。完全再起動の確認待ちは終了。

## 16. Remote Control を全セッションで自動接続にする → `remoteControlAtStartup`（シェル層でやらない）

### 結論

`~/.claude/settings.json` に **`"remoteControlAtStartup": true`** を入れる。これだけで、起動経路（cmd / pwsh / 別ランチャ）に**一切依存せず**全対話セッションが Remote Control になる。

### 根拠（claude.exe 2.1.211 の実体から確認）

公式 docs には「`/config` に *Enable Remote Control for all sessions* トグルがある」とあるが**キー名は非公開**。バイナリから特定した:

```js
// zod スキーマ（settings）
remoteControlAtStartup: A.boolean().optional()
  .describe("Start Remote Control bridge automatically each session")

// 読み取り: settings.json が優先・レガシー config にフォールバック
function HAo(){ return zL()?.settings.remoteControlAtStartup ?? Et().remoteControlAtStartup }

// 起動時の判定（At = --remote-control フラグ / U0e() = 上記設定）
Bg = !(ra()||Boolean(Re)) && !ut(process.env.CLAUDE_CODE_REMOTE) && (At || U0e())
```

→ 設定 `true` は **`--remote-control` を毎回付けたのと等価**。同じ family の `inputNeededNotifEnabled`・`agentPushNotifEnabled` が既に settings.json で機能していることとも整合。

### 注意

- **既存セッションには遡及しない**（次の起動から）。
- セッション名の接頭辞は既定 **hostname**。当日日付にしたい時だけ `remote` 関数（`20260716-fix-bug`）を使う。設定側で日付にはできない（`env` は静的なため）。
- 無効化キーは別物: `disableRemoteControl` / `CLAUDE_CODE_DISABLE_REMOTE_CONTROL=1`。
- `claude config get/list` は**サブコマンドとして既に存在しない**（引数がプロンプトとして解釈され、普通にセッションが走って課金される）。設定確認は `/config` かファイル直読で。

---

## 17. Codex Remote Control のWindows自動起動

### 症状

Codex CLI 0.154.0 でログオン時の自動起動を設定すると、公式コマンドが次の理由で終了する。

- `codex remote-control`: `socket directory is not private to the current user`
- `codex remote-control start`: `host Job Object prevents daemon detachment` または daemon 停止時のアクセス拒否

### 原因

前景コマンドは `C:\tmp\codex-rc-*` を通常の一時ディレクトリとして先に作った後、Windows側で「保護済み・現ユーザーだけ・継承可能ACEが1個」という厳密なDACLを要求する。作成済みディレクトリは継承ACLになるため検証を通らない。管理デーモン方式は親プロセスの Job Object から子を分離できることが前提で、Codexセッションやタスクスケジューラからは失敗する。

### 対処

`Codex/register-remote-control-task.ps1` でユーザーのログオンタスクを登録し、タスクから次を foreground 常駐させる。

```powershell
codex app-server --remote-control --listen ws://127.0.0.1:14567
```

待受は localhost 限定。タスク状態が `Running`、`http://127.0.0.1:14567/readyz` が HTTP 200 なら起動完了。ログは `~/.codex/logs/remote-control.log`。

2026-09-11 実機確認: タスクは `Running`、`127.0.0.1:14567` は `Listen`、`/readyz` は HTTP 200。自動承認は別設定で、`~/.codex/config.toml` の `approval_policy = "on-request"` と `approvals_reviewer = "auto_review"` を使用する。

2026-09-14 更新: ユーザーの再依頼により、自動承認は `approval_policy = "never"` + `sandbox_mode = "danger-full-access"` の確認なし実行へ変更。既存セッションは再起動まで以前の権限のまま。

---

## 18. Codex の status_line は項目を増やしても1行のまま

### 症状と原因

`[tui].status_line = ["model-with-reasoning", "context-remaining", "current-dir", "git-branch"]` を設定しても、4段ではなく4項目が横1行に並ぶ。Codexの設定値は「行」ではなく内蔵フッター内の「項目」の配列で、外部コマンドや複数行を描画する機能は現行版にない。

### 対処

内蔵フッターを `status_line = []` で非表示にし、WezTermの下端5セルを専用ペインとして分割する。

- `Ctrl+Shift+N`: Codex本体と4段ステータスを組にして新規ウィンドウで起動
- `Ctrl+Shift+Y`: 選択中の既存Codexペイン下端へ4段ステータスを後付け

専用ペインでは `Codex/statusline.ps1 -Watch` がrollout JSONLを読み、Claude版と同じ4段構成を2秒間隔で更新する。Codex本体の入力フォーカスは上側へ戻し、下側は5セル固定なので通常操作を妨げない。

2026-09-14 実機確認: 稼働中Codexの下端へ5行高のペインを追加し、モデル/effort、context/5h/7d、cwd、Gitの4行を読み取り確認。現在のセッションは `-SessionId` で固定した。未指定時は同じcwdの最近更新されたセッションを使うため、同じリポジトリの並列セッションでは表示対象が切り替わり得る。既存Codexの内蔵1行フッターは再起動まで残る場合がある。

同日の点滅修正: 更新ごとに全画面消去してからログを読む処理で、一時的に空白になっていた。全画面消去を撤去し、情報取得後に変更された行だけを一括描画する方式へ変更。

同日の再開時の復旧: 前回の表示専用ペインだけが別タブに残り、新しいCodexタブには表示がなかった。旧表示ペインは前回のSessionIdへ固定されていたため、現在のセッション用に下端5セルの表示を作り直し、旧表示ペインのみ終了した。タブの閉じるボタンを有効化し、`Ctrl+Shift+W` はタブ全体、`Ctrl+Shift+Alt+W` は選択中ペインのみを確認付きで閉じるよう明示した。Codexを通常のシェルから再開する場合は、その新しいペインで `Ctrl+Shift+Y` を使う。


## 19. Codex並列セッションの表示混線とスキルアイコン警告（2026-09-14）

旧表示はcwdの最新rolloutを推測する方式で、同じリポジトリの並列セッションを区別できなかった。`Codex/session-status.ps1` とSessionStart/SessionEndフックでCLI PID・WezTerm pane ID・thread UUIDを結合する方式へ変更した。起動直後は端末タイトルで捕捉し、最初のターンで完全UUIDへ更新する。再開・終了も表示へ追従し、表示専用タブを残さない。モデル/effortは現在のタイトル、cwd/contextは対象rollout、Gitはそのcwdから取得する。UUIDが曖昧な場合は `unavailable` とし、別セッションを選ばない。

同cwd・異なるモデルの空セッション2個に各5セルの独立表示が作られることを実機確認した。検証用タブ・ウィンドウはすべて閉じ、他業務の4ペインは維持した。現在のCodex表示も5セルへ戻した。今後の回帰確認は `python Codex/test-session-status.py` でGUIを開かず8件（混線・不存在・省略UUID・衝突・0トークン・cwd・モデル即時更新・thread切替/終了）を検証する。

稼働中WezTermはsymlinkの正本を編集してもreloadしなかった。リンクの属性日時だけを更新しても反映せず、検証したsymlink自身を同ディレクトリ内で一時改名して直ちに戻すとreloadを確認できた（セッションの再起動なし）。設定には正本Luaパスを `add_to_config_reload_watch_list` へ追加し、以後の正本編集を監視する。イベントハンドラがreloadで消えない既知仕様は残るが、自動表示はPID/ペインの表示タイトルと共有throttleで重複を避ける。

スキルの実際の警告はExcelプラグインの `interface.icon_small/icon_large` が許可されたplugin/assets外を指していたこと。`repair-skill-icons.ps1` はアイコンをplugin/assetsへコピーし参照を修正する。修復後にCodexの `skills/list` を当リポジトリと他業務4リポジトリで実行し、読み込みエラー0を確認した。キャッシュ更新で再発した場合は同スクリプトを再実行する。

セットアップと正確な寿命/データ仕様は `Codex/README.md`、`Codex/statusline-spec.md` を参照。


同日の配置修正: Codex本体を分割すると旧表示が元のタブ最下段へ残り、表示ペインを選んで分割すると5行のシェルが出来ていた。ownerと表示の幾何情報を照合し、違う場合は既存表示だけをowner直下5セルへ移動する監視を追加。既定の分割キーは表示からownerへ対象を戻す。現状の2つのCodex表示を各owner直下に置き直し、ユーザーが開いたシェルは保持した。GUIを増やさず、配置検証を加えた回帰9件成功。

`? for shortcuts` はCodexの内蔵操作案内。status_lineを空にしても残る。composer.toggle_shortcutsを空配列にすると当該案内と `?` ヘルプoverlayが無効になる。設定正本statusline.tomlとinstallerへ追加しユーザー設定へ反映。既存CLIは次回起動時に反映するため、進行中のセッションを終了しない。


## 20. 自作contextとCodex内蔵の残量が一致しない（2026-09-14）

自作はrolloutのlast_token_usage.total_tokens/model_context_windowを使用率として表示していたが、Codex内蔵context残量とは計算・更新の扱いが一致しない。ユーザー判断でモデル＋effort・context-remaining・thread-nameを内蔵フッターへ移行した。名前は `/rename <名前>`。自作は制限/cwd/Gitの3行、下端4セル。installerとstatusline.tomlへ記録しユーザー設定にも反映。既存CLIの内蔵フッターは次回起動、または `/statusline` から項目を選択して反映する。既存の自作監視プロセスも次回起動で新しいスクリプトを読む。実機反映確認はB9へ集約する。


2026-09-14 実機確認（B9 CLOSED）: 現在のセッションでnever + danger-full-access、ユーザー設定で内蔵モデル/effort/context/名前とshortcuts非表示を確認。ユーザーが表示・動作を概ね問題なしと確認し、#17〜#20の次回起動確認待ちは終了。

## 21. スキル説明短縮警告・コピーモードの強調不足（2026-09-14）

`Skill descriptions were shortened to fit the skills context budget` はスキルの読込失敗ではなく、説明文の総量超過。アイコン参照修復では解消しない。ユーザー設定のclaude-cowork業務プラグイン14個（apollo/bio-research/brand-voice/common-room/cowork-plugin-management/customer-support/finance/human-resources/legal/marketing/operations/product-management/sales/slack-by-salesforce）を無効化し、開発・データ・デザイン・検索・文書・ブラウザ系を維持した。削除はしていない。`codex debug prompt-input hi` の新しいプロンプトで短縮警告・予算超過警告が無いことを確認。既存CLIの表示は次回起動で確認する。

コピーモードの選択色を黄背景/黒文字に明示し、マウス併用時のactive/inactive highlightも指定した。Shift+VとSpaceの選択バインドを追加。copy_mode中はLua側のCodex表示自動追加を止め、設定が同じ場合はset_config_overridesを呼ばない。黄色カーソルはSteadyBlockにする。CopyModeへ入るだけでは選択は始まらない。行コピーはIME OFF → Ctrl+Shift+X → Shift+V → 矢印 → Enter。Luaロードとshow-keysは成功。実機での強調・安定性はB11で確認する。既存の別プロセスによる表示配置修復と旧イベントハンドラはこの変更だけでは停止しない。

2026-09-14 実機確認（B11 CLOSED）: CopyModeの黄背景選択・コピーについてユーザーが「概ね問題なさそう」と確認。再発時は本項を起点に調査する。

## 22. Codex Remote Controlタスクとデスクトップが競合（2026-09-14）

タスクはReady、14567の待受無し。起動し直すとHTTP /readyzは200だったが、RPC `remoteControl/status/read` はerrored。logs_2.sqliteのremote_controlログでHTTP 409 `Remote app server already online` を確認。デスクトップ（ChatGPT.exe子のapp-server）が同じinstallation/server登録でConnectedとなっており、タスク側が競合した。現在のWezTerm CLIは別PIDのローカルサーバーで動作しているため、デスクトップの接続成功だけではこのCLI会話の自動接続を証明できない。

今回起動した競合タスクだけを停止し、稼働中デスクトップ/CLIは維持した。HTTP 200は常駐サーバーの起動確認に限り、Remote Control接続完了の根拠にはしない。今後CLIを常駐サーバーへ`--remote ws://127.0.0.1:14567`で接続するか、デスクトップ側を残すかの選択をユーザーへ提示。B10で回収する。前回#17の「Remote Control接続済み」の扱いはこの確認で訂正する。


#22 更新（同日、CLI中心の方針で解決）: ユーザーがデスクトップのRemote ControlをOFFにし、常駐側RPC connectedを確認。CLI起動をstart-codex.ps1へ一本化し、PowerShell codex関数とCtrl+Shift+Nから共通サーバーへ--remote接続する。cwdを明示し、resume/fork/agentsも同経路。管理コマンド/exec/help/versionは素通し。未起動時はタスク開始、RPC connectedを確認してから対話起動。タスクをStartWhenAvailable付きで再登録しRunning/connectedを確認。PTYで新しいthread UUIDとモデル/effort/cwd/YOLOを確認、プロンプト送信無し。B10 CLOSED。既存CLIはローカルサーバーのままなので次回起動または共有サーバーへresumeで反映。

#22 追記（同日14:49、「スマホから見えない」再発）: 常駐サーバーはRPC `connected` で正常。原因は**CLI側**。WezTermのpwsh（9:08起動）が `codex` 関数追加（profile.ps1 11:25更新）より前のシェルだったため、13:51の `codex` が素の `codex.exe`（`--remote` 無し・プロセス内ローカルサーバー）で起動し、共有サーバーの `thread/list` では全スレッド `notLoaded`＝スマホに出るライブ会話が無かった。判定: `Get-CimInstance Win32_Process` で codex.exe のコマンドラインに `--remote ws://127.0.0.1:14567` があるか。復旧: そのCodexを終了 → 同ペインで `. $PROFILE` → `codex resume --last`（新規タブならそのまま）。Claude側からTUIへのキー送信・プロセスkillはしない（#13と同じ理由）。

#22 恒久対処（同日、ユーザー要望「Claude Codeと同じ仕様に」）: Codex 0.154.0 には `remoteControlAtStartup` 相当が無い（TUIに `--remote-control` 無し・`codex features list` の `remote_control` は `removed`）。そこで**profile関数を撤去し、`codex.exe` と同じフォルダへ `codex.ps1` シムを配置**（`Codex/install-codex-shim.ps1`）。PowerShellは同一PATHフォルダ内で.ps1を.exeより先に解決する（スクラッチで実測）ため、PATH・プロファイルの読込時期に依存せず**既存シェルでも**次の `codex` から共有サーバー経由になる。検証: `pwsh -NoProfile` で `Get-Command codex` → codex.ps1、`codex --version` とパイプ入力はexeへ素通し（exit 0）、インストーラは冪等。Codex更新でbinが置換されても `remote-control.ps1` がログオン時に再配置。対象外: cmd.exe（PATHEXTで.exe優先）・exeフルパス直接起動・デスクトップアプリ。

2026-09-14 実機確認（B12 CLOSED）: 現在のCLIが共有サーバー経由でresumeしていることをプロセスで確認後、ユーザーがスマホに現在の会話が「表示されてる」と確認。シムの対話起動・スマホ表示の確認待ちは終了。

## 23. DiXiM USBソフトの「引数が正しくありません」（2026-09-14）

ユーザー画像のウィンドウはdixim-security-endpoint-usb。実プロセスはTemp/DiXiM Security Endpoint for USB@E/dixim-security-endpoint-usb.exe -nocopy、DigiOnの署名Valid、版1.0.0.61。接続中のBUFFALO RUF3-KEV、E: UTILITIES/OPEN_KEV.exe/DiXiMSecurityEndpointと一致する。USB付属のウイルスチェックソフトが発生元で、Codex/WezTermのエラーダイアログではない。

同ソフトのログではD:/E:のDBT_DEVICEREMOVECOMPLETEの直後にBackupDir() failedが反復し、bootDriveLetter:E drive not foundも記録されている。USBの取り外し/再認識時に保存先を失う状態が候補。ただし画像の引数エラーを直接記録した行は見つからず、同じ根本原因とは確定できない。まず安全な取り外し後にPC本体のUSBポートへ差し直して切り分ける。継続する場合はこの版・画像・USBログをBUFFALOサポートへ提示。認証/隔離データやTemp一式を削除する処置、ウイルスチェックの無効化は実施していない。製品仕様: https://www.buffalo.jp/press/detail/20250108-01.html

## 24. `hi` の開始リマインダー（UserPromptSubmit フック）が文字化けして届く（2026-09-15）

### 症状

`hi` で開始したとき、フックの追加指示が `�Z�b�V�����J�n�v���g�R��` のように化けて Claude に届く（2026-09-14 の `hi` で実物を確認。/doctor で発見）。ファイル読込の指示が読めないため、GO ゲートが CLAUDE.md 本文頼みになっていた。

### 原因

フックとして起動された pwsh は、標準出力を**コンソールのコードページ（CP932）**で書き出す。Claude Code はフックの出力を **UTF-8** として読む。`.claude/hooks/session-start-reminder.ps1` の `ConvertTo-Json` は日本語をそのまま出力していたため、CP932 のバイト列が UTF-8 として解釈されて化けた。スクリプトファイル自体の文字コード（BOM 無し UTF-8）は無関係。手元の pwsh で直接実行すると OutputEncoding が utf-8 なので、再現しない点に注意。

### 対処

`ConvertTo-Json -Compress -Depth 10 -EscapeHandling EscapeNonAscii` に変更した。日本語を `\uXXXX` にエスケープし、JSON を ASCII だけにすれば、コードページに関係なく壊れない。

検証: `cmd /c "chcp 932 & echo {""prompt"":""hi""} | pwsh -NoProfile -NonInteractive -File <hook>"` で、出力が ASCII のみ（1,555 文字）であること、`ConvertFrom-Json` で元の日本語に戻ること、`hi` 以外のプロンプトでは出力が空であることを確認。

### 教訓

- Windows で日本語を出力する pwsh フックは、**JSON を EscapeNonAscii にする**か、スクリプトの冒頭で `[Console]::OutputEncoding = [Text.Encoding]::UTF8` にする。
- 同じ /doctor で見つかった他リポジトリのフック問題 2 件は、各セッションに依頼済み。
  - sendai-waterworks-bureau: `args` で相対パス `.claude/hooks/hi-gate.ps1` を渡しているため、作業フォルダがリポジトリ直下でないと exit 64 になる。`${CLAUDE_PROJECT_DIR}` を使う形への修正を依頼。→ **2026-09-15 修正済（sendai `1c5d915`・本人承認）**。リポジトリ外から実行して、旧形式の再現・新形式の exit 0・挨拶以外で沈黙を確認済み。常に失敗していたのではなく、作業フォルダ依存だった（リポジトリ直下で起動したセッションでは発火していた）。
  - Instagram-project-v2: `norm_sweep.py` が単独 1.7 秒のところ、SessionStart の 8 本同時実行で 5〜11 秒かかり、compact のたびに走っている。matcher "startup" 化などを依頼。

## 25. コピーモードにすると背景（透過・backdrop）が点滅して消える（2026-09-15）

### 症状

Claude Code のペインで `Ctrl+Shift+X`（コピーモード）に入ると、ウィンドウ背景が点滅したり、消えたりする。#21（B11）で選択色を足した後に報告された。

### 原因

`update-status` ハンドラが、`json_encode(window:get_config_overrides()) ~= json_encode(overrides)` で「変わった時だけ `set_config_overrides`」としていた。ところが **Lua テーブルのキー順は不定**で、コピーモード中の override は入れ子の `colors`（選択色・カーソル色・tab_bar）を持つため、文字列比較が毎回不一致になる。Claude の TUI は常に再描画するので `update-status` が頻繁に発火し、そのたびに override が再適用され、`win32_system_backdrop`・透過が張り直されて点滅していた。通常時は `window_background_opacity` の 1 キーだけなので、比較がたまたま一致して目立たなかった。

### 対処

比較をやめ、**モード（copy/normal）が切り替わった時だけ** `set_config_overrides` を呼ぶようにした。状態は `wezterm.GLOBAL["override_mode_<window_id>"]` に持つ（reload を跨いで残る。入れ子テーブルへの書き込みは反映が不確かなのでフラットなキーにした）。`wezterm --config-file <repo>\wezterm\wezterm.lua show-keys` で読み込み成功（exit 0）を確認。

### 注意

- 旧ハンドラ（json 比較版）は reload では**解除されない**（#2）。保存での自動 reload 後も点滅が残るなら、旧ハンドラの残骸が原因なので WezTerm の完全再起動が必要。
- 実機での確認は、コピーモードに入って背景が点滅しないこと、選択が黄背景で見えること。

## 26. Codex が起動しない「Remote Control is not connected (errored)」（2026-09-15）

### 症状

`codex` で起動すると、`start-codex.ps1` が `Remote Control is not connected (errored)` を投げて止まる。

### 原因

#22 の 409 競合が再発した。Codex のログ（`~/.codex/logs_2.sqlite`・target `remote_control`）では、**デスクトップ版の内部 app-server（9/11 から起動したまま）が 07:55:53 に Errored → Connected** で登録を取り、08:15 起動の常駐サーバーは `HTTP error: 409 Conflict ... "Remote app server already online"` を 30 秒ごとに繰り返していた。ネットワークは正常（chatgpt.com:443 到達）。9/14 にデスクトップ側を OFF にしたはずだが、起動しっぱなしのデスクトップ版がスリープ明けなどに再接続したとみられる（設定が ON に戻ったのかは未確定）。

`start-codex.ps1` は「connected になるまで最大 30 秒待ち、ダメなら throw」だったため、競合中は **CLI 自体が起動できなくなっていた**。スマホに見えないだけで CLI としては使える状態なのに、止めてしまうのは過剰だった。

### 対処

- `start-codex.ps1`: 共有サーバーが応答していれば、`errored` は 3 秒、それ以外は 30 秒まで待つ。未接続なら**警告を出して `--remote` で起動を続ける**（ローカル専用 CLI には黙って切り替えない方針は維持）。共有サーバー自体が 30 秒応答しない時だけ throw する。PowerShell パーサで構文エラー 0 を確認。
- 根本対処はユーザー操作: デスクトップ版 Codex の Remote Control を OFF にするか、デスクトップ版を完全終了する。常駐サーバーは 30 秒以内に自動再接続し、共有サーバーに乗っている CLI の会話もスマホに出る。デスクトップ版のプロセスは Claude 側から kill しない。

### 追記: 会話が分かれる仕組みと「CLI 軸」の運用（同日 12:03 決着）

- **Remote Control はアカウントで 1 つ。** デスクトップ版の内部 app-server（stdio 専用で、外から `--remote` 接続できない）と常駐サーバーは、同じ installation id（`~/.codex/.codex-global-state.json` の `electron-local-remote-control-installation-id`）で競合する。CLI の会話を、デスクトップ版とスマホの両方でライブ共有する手段は現行仕様に無い（openai/codex #45386 が未対応）。
- **デスクトップ版が Remote Control を持っている間は、CLI の会話がスマホとデスクトップ版に出ても、それは写し。** 08:27:21 にデスクトップ版が各リポジトリの会話を `originator: Codex Desktop` として 11 本作成した（`01a0a23f-…`）。スマホからの入力は、11:58 に写し `01a0a23f-203d…` 側で `thread/resume` され、CLI の元の会話 `01a0a23b…` には入らなかった＝**会話が分岐した**。自動では合流しない。
- **決定（ユーザー）: CLI 軸＝案 C。** デスクトップ版の「設定 → Connections → Control this Mac or PC」を OFF にした。ログでは 12:03:08 にデスクトップ側が `remoteControl/disable` → `Connected→Disabled`、12:03:33 に常駐サーバーが `connected`。以後、スマホは常駐サーバー上の CLI の会話そのものに入力する（同じサーバーの同じ会話なので分岐しない）。
- **運用ルール:** CLI の会話に**デスクトップ版から打たない**（打つとデスクトップ版の写しに入って分岐する）。デスクトップ版は別の作業用。`codex` 起動時に「Remote Control is errored」と警告が出たら、デスクトップ版の上記設定が ON に戻っていないか確認する。
- **実機確認（同日）:** 案 C への切替後、ユーザーがスマホから CLI の会話へ送信し「大丈夫そう」と確認（分岐なし）。
- **訂正（同日・ユーザー実機）:** デスクトップ版では、CLI の会話への入力が**仕様としてできない**（入力欄が無効）。上の「デスクトップ版から打たない」は注意ではなく、アプリ側がすでに防いでいる。分岐が起きうるのは「デスクトップ版が Remote Control を持っている間に、スマホから写しに打つ」経路だけ。案 C ならこの経路も無い。
