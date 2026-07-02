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

- WezTerm の**特定ペインだけ**キー入力が効かなくなる（他ペインは生きている）。
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

### 教訓

- 「1 ペインだけ入力不能 → 勝手に復活」= **ほぼ修飾キー stuck**。まず修飾キーをタップさせる。設定を疑う前に `wezterm cli list` で全ペイン生存・非 zoom・非コピーモードを確認すれば、config 側の犯人探しに時間を溶かさずに済む。
