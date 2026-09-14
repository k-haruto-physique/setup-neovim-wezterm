# キーバインド早見表

WezTerm + LazyVim + PowerShell の **このリポジトリのセットアップ専用**チートシート。
頻度ランク **★★★（毎日使う）** / **★★（週に数回）** / **★（時々）** で学習優先度を提示。

---

## 🏗 レイヤー構造（まず全体像）

```
┌───────────────────────────────────────────────┐
│ WezTerm  ← ウィンドウ・タブ・ペインの管理         │
│  ┌─────────────────────────────────────────┐  │
│  │ PowerShell or nvim  ← 起動するもの        │  │
│  │  ┌───────────────────────────────────┐  │  │
│  │  │ Neovim (LazyVim)                  │  │  │
│  │  │   ├ Normal / Insert / Visual モード│  │  │
│  │  │   └ LazyVim プラグイン群           │  │  │
│  │  └───────────────────────────────────┘  │  │
│  └─────────────────────────────────────────┘  │
└───────────────────────────────────────────────┘
```

**重要原則**: キーは外側のレイヤーから順に届く。WezTerm が横取りすると Neovim には届かない。両者が同じキー（例: `Ctrl+Tab`）を使うとき、WezTerm が勝つ。

---

## ⚡ クイックアクセス（最初の 10 個だけ覚える）

| # | キー | 動作 | レイヤー |
|---|---|---|---|
| 1 | `Esc` | **モード抜け（Insert→Normal）** | Neovim |
| 2 | `i` | カーソル位置で挿入モード | Neovim |
| 3 | `:w` | 保存 | Neovim |
| 4 | `:q` | 終了（変更あれば `:q!` で破棄） | Neovim |
| 5 | `Space` | **LazyVim Leader（メニュー出現）** | Neovim |
| 6 | `Space + f + f` | ファイル検索（Telescope） | Neovim |
| 7 | `Space + e` | ファイラ開く（snacks explorer） | Neovim |
| 8 | `Ctrl+Shift+T` | 新規タブ | WezTerm |
| 9 | `Ctrl+Shift+Alt+"` | ペイン分割（上下） | WezTerm |
| 10 | `Ctrl+Shift+矢印` | ペイン移動 | WezTerm |

---

## 🪟 WezTerm: ペイン・タブ・ウィンドウ

**基本のペイン/タブ操作は WezTerm デフォルト**。ただし独自バインドを追加定義済: `Ctrl+Shift+X/I/N/S/E/O`（`config.keys`）・コピーモード key_table 全置換・`config.mouse_bindings`（Ctrl+Click でパスを開く / クリック誤爆防止）。旧 tmux 風レガシーは `wezterm.lua` 内で 4 行コメントアウトのまま退避。

### ペイン操作 ★★★

| キー | 動作 | 補足 |
|---|---|---|
| `Ctrl+Shift+Alt+"` | **ペインを上下分割** | クォート（`Shift+2` ではなく `Shift+'`） |
| `Ctrl+Shift+Alt+%` | **ペインを左右分割** | `Shift+5` |
| `Ctrl+Shift+←/→/↑/↓` | **隣のペインへフォーカス移動** | 一番使う |
| `Ctrl+Shift+Alt+←/→/↑/↓` | ペインサイズ変更 | リサイズ |
| **`Ctrl+Shift+S`** | **ペイン入れ替え（スワップ）** | ラベルが各ペインに出る → 交換相手の文字を打つ。3 ペイン以上でも狙える |
| **`Ctrl+Shift+E`** | ペイン回転（時計回り） | 2 ペインなら押すだけで左右の位置を即入れ替え（ラベル不要） |
| `Ctrl+Shift+Alt+W` | ペインを閉じる（確認あり） | カーソルのある側 |
| `Ctrl+Shift+Z` | **ペインの最大化トグル** | 集中したい時 |

> 💡 **分割の向き（左右↔上下）は変えられない**（WezTerm の仕様）。向きを変えたい時は片方を `Ctrl+Shift+W` で閉じて分割し直す。`S`/`E` は「向きはそのままで中身の位置だけ入れ替える」用途。

### タブ操作 ★★

| キー | 動作 |
|---|---|
| **`Ctrl+Shift+I`** | **nvim を新規ウィンドウで起動**（上モニター用） |
| **`Ctrl+Shift+Y`** | **現在のCodexペインの登録済み4段表示を修復**（通常は自動追従） |
| **`Ctrl+Shift+N`** | **Codex＋下端4段ステータスを新規ウィンドウで起動**（下モニター用） |
| `Ctrl+Shift+T` | 新規タブ（同一ウィンドウ内） |
| `Ctrl+Shift+W` | タブ全体を閉じる（確認あり） |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | タブ前後切替 |
| `Ctrl+Shift+1〜8` | タブを番号で直接ジャンプ |
| `Ctrl+Shift+PgUp/PgDn` | タブ前後切替（別キー） |

### コピー・検索・スクロール ★★

| キー | 動作 |
|---|---|
| `Ctrl+Shift+C` | 選択範囲をコピー |
| `Ctrl+Shift+V` | 貼り付け |
| `Ctrl+Shift+F` | スクロールバック検索 |
| **`Ctrl+Shift+X`** | **コピーモード起動**（次表参照） |
| `Ctrl+Shift+Space` | QuickSelect（画面上のパス等にラベル表示 → タイプで選択。WezTerm デフォルト） |
| `Ctrl+Shift+PageUp/Down` | スクロール（タブ移動と被るので注意） |
| `Ctrl+Shift+K` | スクロールバックをクリア |

### マウス・パスを開く ★★（2026-07-02 カスタム）

| 操作 | 動作 | 補足 |
|---|---|---|
| **`Ctrl+Shift+O`** | **選択中のパスを nvim で開く** | 無選択なら QuickSelect 数字ラベル → 選んで開く（主役キー・IME 無関係） |
| **`Ctrl+Click`** | リンク/パス（`nvimopen:`）を開く | 意図的操作でだけ nvim 起動 |
| プレーンクリック / `Shift+Click` | **選択のみ**（リンクは開かない） | 既定の click-opens-link を無効化＝誤爆防止（B2） |

### コピーモード内のキー ★★（2026-05-22 カスタム設定済）

> ## ⚠️ IME 注意（最重要・忘れたら詰む）
>
> **日本語 IME が ON の状態では、`h` `j` `k` `l` 等の文字キーは IME に奪われて WezTerm に届かない**。
> 結果: コピーモードに入れているのに hjkl が反応しないように見える。
>
> ### 必ず守る
> - **コピーモードに入る前に IME を OFF**（`半角/全角` または `Alt+~`）
> - **OFF できないときは矢印キー `←↓↑→` を使う**（IME に奪われない）
>
> ### 簡易判別
> - 何か入力してみて画面に文字が出る → IME ON （NG）
> - 何か入力しても画面に何も出ない → IME OFF or コピーモード成功

**コピーモードに入れているかの判定**: **カーソルが黄色に変わる**（2026-05-22 設定）。黄色くなければ未起動 → IME OFF にして `Ctrl+Shift+X` リトライ。

| キー | 動作 | 備考 |
|---|---|---|
| **`←` `↓` `↑` `→`** | **カーソル移動（優位）** | TUI/IME に取られにくい |
| `h` `j` `k` `l` | カーソル移動（vim 風） | 同上だが TUI に奪われる可能性あり |
| `w` / `b` / `e` | 単語前進 / 後退 / 末尾 | |
| `0` / `^` / `$` | 行頭（最左） / 行の最初の非空白 / 行末 |
| `g` / `G` | スクロールバック先頭 / 末尾 |
| `H` / `M` / `L` | 画面内の上 / 中 / 下 |
| `Ctrl+u` / `Ctrl+d` | 半ページ ↑ / ↓ |
| `Ctrl+b` / `Ctrl+f` | 1 ページ ↑ / ↓ |
| **`PageUp` / `PageDown`** | **1 ページ ↑ / ↓（IME 無影響、最頻出）** |
| **`Home` / `End`** | **スクロールバック先頭 / 末尾へジャンプ** |
| `n` / `N` | 検索マッチを 次 / 前 へ（`Ctrl+Shift+F` で検索した後に使う） |
| `/` `?` | **無効化済**（意図しない検索バー誤発火の防止。検索は `Ctrl+Shift+F` から明示的に） |
| 検索バー内 `Ctrl+U` | 検索パターンをリセット（`Backspace` で 1 文字、`Esc` で検索終了） |
| `v` | セル選択開始 |
| `V` | 行選択 |
| `Ctrl+v` | 矩形選択 |
| `y` または `Enter` | **コピー + コピーモード終了** |
| `Esc` / `q` / `Ctrl+c` | コピーモードを終了（コピーなし） |

> ⚠️ **hjkl が反応しない場合のチェック**:
> 1. タブバー右下に `MODE: copy_mode` が表示されているか（出てない＝入れてない）
> 2. 日本語 IME が ON になっていないか（`Alt+~` で OFF）
> 3. WezTerm 設定がリロードされているか（`Ctrl+Shift+R` 強制リロード）

### フォント・表示 ★

| キー | 動作 |
|---|---|
| `Ctrl++` / `Ctrl+-` | フォント拡大/縮小 |
| `Ctrl+0` | フォントサイズリセット |
| `Alt+Enter` | フルスクリーン切替 |
| `Ctrl+Shift+L` | デバッグオーバーレイ |

> 💡 **再カスタマイズしたい場合**: `wezterm/wezterm.lua` のコメントアウトされた `config.keys`/`config.key_tables`/`config.leader` 行を外せば、過去の tmux 風キーバインド（`keybinds.lua`、leader = `Ctrl+Q`）が復活。今は学習の妨げになるためデフォルトを推奨。

---

## ⌨ Neovim 基礎: モード遷移

Vim 未経験者が **最初に詰む最大ポイント**。

| キー | from → to | 用途 |
|---|---|---|
| `Esc` | Insert/Visual → **Normal** | デフォルトに戻る |
| **`Ctrl+[`** | Insert/Visual → **Normal** | `Esc` の代替（IME 透過するので Windows ではこちら推奨） |
| `Ctrl+c` | Insert/Visual → **Normal** | 同上（一部 autocmd を発火しない違い） |
| `i` | Normal → Insert | カーソル位置の**前**から挿入 |
| `a` | Normal → Insert | カーソルの**次**から挿入（append） |
| `I` | Normal → Insert | 行頭（最初の非空白）から挿入 |
| `A` | Normal → Insert | **行末から**挿入（超頻出） |
| `o` | Normal → Insert | 下に**新規行**を作って挿入 |
| `O` | Normal → Insert | 上に新規行を作って挿入 |
| `s` | Normal → Insert | 現在 1 文字を削除して挿入（substitute） |
| `S` | Normal → Insert | 現在**行**を削除して挿入 |
| `cc` | Normal → Insert | `S` と同じ（change line） |
| `cw` | Normal → Insert | カーソル位置から単語末尾までを削除して挿入 |
| `c{motion}` | Normal → Insert | motion 範囲を削除して挿入（例: `ciw`=単語丸ごと書直し、`ci"`=クォート内側書直し） |
| `C` | Normal → Insert | カーソル位置から**行末まで**を削除して挿入 |
| `r{char}` | （Normal のまま） | カーソル下 1 文字を `{char}` に置換（Insert に入らない） |
| `v` | Normal → Visual | 文字選択 |
| `V` | Normal → Visual Line | 行選択 |
| `Ctrl+v` | Normal → Visual Block | 矩形選択 |
| `:` | Normal → Command | Ex コマンド |

> 🚨 **IME 罠**: 日本語 IME ON で `Esc` を押すと IME OFF はされるが Normal に戻らないことがある。当面は `Ctrl+[` を `Esc` 代替として使うのが安全（IME 透過する）。

---

## 🚶 Neovim カーソル移動（Normal モード）★★★

### 文字単位

| キー | 動作 |
|---|---|
| `h` `j` `k` `l` | ← ↓ ↑ → |
| 矢印キー | 同上（最初はこれで OK） |

### 単語・行

| キー | 動作 |
|---|---|
| `w` | 次の単語の先頭 |
| `b` | 前の単語の先頭 |
| `e` | 次の単語の末尾 |
| `0` | **行頭**（インデント含む） |
| `^` | 行の最初の非空白 |
| `$` | **行末** |
| `gg` | ファイル先頭 |
| `G` | ファイル末尾 |
| `{number}G` | N 行目へジャンプ |

### 検索移動

| キー | 動作 |
|---|---|
| `/pattern` | 前方検索 |
| `?pattern` | 後方検索 |
| `n` / `N` | 次/前のマッチ |
| `*` | カーソル下の単語で検索 |
| `f{char}` | 行内で次の `{char}` へ |
| `t{char}` | 行内で次の `{char}` の**直前**へ |
| `;` / `,` | `f`/`t` の繰返し/逆方向 |

### スクロール

| キー | 動作 |
|---|---|
| `Ctrl+d` / `Ctrl+u` | 半画面 ↓/↑ |
| `Ctrl+f` / `Ctrl+b` | 1 画面 ↓/↑ |
| `zz` | カーソル行を**画面中央**へ |
| `zt` / `zb` | カーソル行を上/下端へ |

---

## ✏ Neovim 編集（Normal モード）★★★

### 削除・変更

| キー | 動作 | 補足 |
|---|---|---|
| `x` | 1 文字削除 | Delete 相当 |
| `dd` | **1 行削除（カット）** | クリップボードに入る |
| `dw` | 単語削除 | `d` + `w` の合成 |
| `d$` / `D` | 行末まで削除 | |
| `d0` | 行頭まで削除 | |
| `cc` | 1 行を**置換（c = change）** | Insert モードへ |
| `cw` | 単語を置換 | カーソル→単語末尾を削除＋Insert |
| `C` | 行末まで置換 | |
| `r{char}` | 1 文字を `{char}` に置換 | Insert モードに入らない |
| `s` | 1 文字削除 + Insert | |
| `u` | **Undo** | 押せば押すほど戻る |
| `Ctrl+r` | **Redo** | |

### コピー・貼り付け（ヤンクと言う）

| キー | 動作 |
|---|---|
| `yy` | 行ヤンク（コピー） |
| `yw` | 単語ヤンク |
| `y$` | 行末までヤンク |
| `p` | カーソル位置の**後ろ**に貼り付け |
| `P` | カーソル位置の**前**に貼り付け |

> 💡 **クリップボード連携**: LazyVim はデフォルトで OS クリップボードと連動。Windows での貼付は `"+p`（`+` レジスタ指定）が必須なケースあり。試して挙動を確認。

### 連結・インデント

| キー | 動作 |
|---|---|
| `J` | 下の行を**現在行末に連結** |
| `>>` / `<<` | 行を右/左へインデント |
| `=` | 自動インデント（範囲指定可） |
| `gq{motion}` | 整形 |

---

## 🎯 オペレータ + モーション（Vim の真髄）★★

`d`、`c`、`y`、`>`、`=` などの**オペレータ**は **モーション**と組み合わせる。

| 構成 | 例 | 意味 |
|---|---|---|
| `{operator}{motion}` | `d$` | 行末まで削除 |
| `{operator}{operator}` | `dd` | 行に対して |
| `{operator}{count}{motion}` | `d3w` | 3 単語削除 |
| `{operator}i{textobj}` | `di"` | **クォート内側**を削除 |
| `{operator}a{textobj}` | `da(` | **括弧含めて全部**削除 |

### よく使う textobj

| キー | 範囲 |
|---|---|
| `iw` / `aw` | 単語 inside / around |
| `i"` / `a"` | ダブルクォート内/外 |
| `i'` / `a'` | シングルクォート内/外 |
| `i(` / `a(` | カッコ内/外 |
| `i{` / `a{` | 波カッコ内/外 |
| `it` / `at` | HTML タグ内/外 |
| `ip` / `ap` | 段落 |

---

## 🚀 LazyVim 機能（Space リーダー）★★★

`Space` を押すと **which-key メニュー**が表示される（候補が出る）。慌てず読む。

### ファイル・検索

| キー | 動作 | プラグイン |
|---|---|---|
| `Space f f` | **ファイル検索（fuzzy）** | Telescope |
| `Space f r` | 最近開いたファイル | Telescope |
| `Space f g` | git 管理下のファイル | Telescope |
| `Space /` or `Space s g` | **プロジェクト全体 grep** | Telescope + ripgrep |
| `Space s w` | カーソル下の単語を grep | |
| `Space s b` | 現在バッファ内検索 | |
| `Space s h` | ヘルプ検索 | |
| `Space s k` | キーマップ検索 | |
| `Space s c` | コマンド検索 | |

### バッファ（開いているファイル）

| キー | 動作 |
|---|---|
| `Space b b` | バッファ一覧 |
| `Shift+H` / `Shift+L` | 前/次のバッファ |
| `Space b d` | バッファを閉じる |
| `Space b D` | バッファ強制閉じる |

### エクスプローラ ★★

| キー | 動作 |
|---|---|
| `Space e` / `Space f e` | **snacks explorer トグル**（ファイラ、root 起点） |
| `Space E` / `Space f E` | snacks explorer を cwd 起点で開く |
| `Space f h` | **neo-tree を ~（ホーム）ルートで開く**（独自キー・LazyVim 既定の Telescope help を上書き。help は `Space s h`） |

**snacks explorer 内**: `a` 新規、`d` 削除、`r` リネーム、`Enter` 開く、`H` 隠しファイル(dotfiles)トグル、`I` gitignore 対象トグル、`?` 全キー表示（**リフレッシュ `R` は無い**）
**neo-tree を使う場合**: `:Neotree` コマンドで開く（キーバインドは未割当）

### ウィンドウ分割 ★★

| キー | 動作 |
|---|---|
| `Space - / Space \|` | 横/縦分割（**Neovim 内の話**、WezTerm ペインと別） |
| `Ctrl+w h/j/k/l` | ウィンドウ間移動 |
| `Ctrl+w q` | ウィンドウ閉じる |
| `Ctrl+w =` | サイズ均等化 |

### LSP（コードジャンプ・補完） ★★★

| キー | 動作 |
|---|---|
| `g d` | **定義へジャンプ** |
| `g r` | **参照を一覧** |
| `g I` | 実装へジャンプ |
| `g y` | 型定義へ |
| `K` | カーソル下のホバー（型・ドキュメント） |
| `Space c a` | **コードアクション**（quickfix） |
| `Space c r` | **シンボルをリネーム** |
| `Space c f` | フォーマット |
| `[d` / `]d` | 前/次の診断（エラー）へ |
| `Space x x` | 診断一覧（Trouble.nvim） |

### 補完中（Insert）★★

| キー | 動作 |
|---|---|
| `Ctrl+Space` | 補完を強制起動 |
| `Tab` / `Shift+Tab` | 候補移動 |
| `Enter` | 確定 |
| `Ctrl+e` | 補完キャンセル |

### Git ★★

| キー | 動作 |
|---|---|
| `Space g g` | **LazyGit 起動** |
| `Space g b` | line blame トグル |
| `]h` / `[h` | 次/前の hunk へ |
| `Space g h s` | hunk をステージ |
| `Space g h r` | hunk をリセット |

### Lazy / Mason 管理 ★

| キー | 動作 |
|---|---|
| `Space l` | **Lazy プラグイン管理画面** |
| `Space c m` | **Mason 起動**（LSP/フォーマッタ管理） |
| `:Lazy update` | プラグイン更新 |
| `:Mason` | Mason GUI |
| `:LazyExtras` | LazyVim 拡張パック有効化 |

---

## 🔍 検索・置換 ★★

| キー / コマンド | 動作 |
|---|---|
| `/pattern` → `n`/`N` | 検索 |
| `:%s/old/new/g` | **全置換**（プロジェクトでなくバッファ） |
| `:%s/old/new/gc` | 確認つき全置換 |
| `:s/old/new/g` | 現在行で置換 |
| `Space s r` | プロジェクト全体置換（grug-far 等） |
| `:noh` | ハイライト消す |

---

## 💻 PowerShell（WezTerm 内で起動） ★★

| キー | 動作 |
|---|---|
| `Tab` | 補完 |
| `Ctrl+R` | 履歴インクリメンタル検索（PSReadLine） |
| `Ctrl+A` / `Ctrl+E` | 行頭 / 行末 |
| `Ctrl+L` | 画面クリア |
| `↑` / `↓` | 履歴 |
| `Ctrl+C` | 実行中止 |

### このリポジトリ独自コマンド（正本: `powershell/profile.ps1`）

| コマンド | 動作 |
|---|---|
| `codex` / `codex resume --last` | CLIを共有Remote Controlサーバーへ自動接続して起動/再開（新しいPowerShellから有効。デスクトップ側Remote ControlはOFF） |
| `repo` / `dotfiles` | dotfiles リポジトリへ cd |
| `v` | cwd を nvim で開く |
| `vrepo` | dotfiles を nvim で開く |
| `kanro` | kanro_db へ psql 接続（pgpass 無人認証） |
| `remote [name]` | 名前付きで Remote Control 起動（`remote fix-bug` → `20260716-fix-bug`）。**素の `claude` も既定で Remote Control になる**（`settings.json` の `remoteControlAtStartup: true`）。この関数は「アプリ/web 側で名前を見て識別したい」時だけ使う（既定の接頭辞は hostname） |
| `usage [daily\|session]` | 使用量の従量換算表示（USD+円。既定は月別） |

---

## 🆘 困った時の最終手段

| 状況 | 対処 |
|---|---|
| Insert モードから出られない | `Esc` を連打 → ダメなら `Ctrl+[` |
| 何かおかしい・元に戻したい | `u` を連打（Undo） |
| 画面が崩れた | `Ctrl+L`（再描画） |
| `:q` で出られない | `:q!` で強制終了（保存なし） |
| `:wq` で書き込み権限エラー | `:w !sudo tee %` は Windows では効かない。`:w C:/path/別名` で別名保存 |
| プラグインが動かない | `:Lazy sync` → 再起動 |
| LSP が動かない | `:LspInfo` で状態確認、`:Mason` で再インストール |
| **どのキーが何するか忘れた** | `Space` を押して which-key を読む |
| キー入力詳細を見たい | `:map` `:nmap` `:imap` |

---

## 📚 さらに学ぶ

- `:Tutor` で **Vim 公式チュートリアル**（30 分・必須）
- `:help <topic>` で公式ヘルプ
- `Space s h` で help をファジー検索

`docs/legacy-nvim/` には **以前手書きしていた lazy.nvim 設定**を保存済み。キーバインドや LSP 設定の参考にできる（特に `keymaps.lua`、`lsp.lua`）。


Codex表示ペインを選んで既定の分割キー（Ctrl+Alt+Shift+5 / 引用符系）を押すと、対応するCodex側を分割する。表示は対象Codexの直下5セルへ自動で戻る。Codexの `? for shortcuts` は `tui.keymap.composer.toggle_shortcuts = []` により次回起動から非表示（`?` ヘルプも無効）。
