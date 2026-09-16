# wezterm/ の注意（wezterm/ 配下を触るときだけ読み込まれる）

ルートの `CLAUDE.md` から 2026-09-15 に移設。全体ルール（編集はリポジトリ側パス・IME 注意など）はルート側。

## リロード挙動

- `config.automatically_reload_config = true`。色・キー等は保存で再読込。ただし完全再起動（プロセス kill）が要るものが 2 種:
  - `wezterm.on(...)` 登録イベントハンドラは reload で**解除されない**（addon 系の挙動変更）
  - **`default_prog` の変更は稼働中インスタンスに乗らない**（2026-07-16 実測。symlink 経由の config をウォッチャが拾えていない疑い）。反映検証は既存ウィンドウを壊さずに `wezterm --config-file <repo>\wezterm\wezterm.lua start --always-new-process` で行う（#15）

## 透過率（現状: 静的 0.95 統一 / nvim 検出は廃止済）

透過率は静的 `config.window_background_opacity = 0.95` で統一。
**nvim ペインを検出して透過率を動的切替する仕組み（`pane_is_nvim()` / OSC 1337 `IS_NVIM` 送信 / 0.85↔0.95 切替）は実装していない**。当初は動的切替を検討したが Windows TUI で `get_user_vars()`・title・foreground プロセス検出のいずれも不安定（LSP 子プロセスが一瞬 foreground を奪う等）で廃止した。経緯は `docs/troubleshooting.md` 第 2 項。

残っているのは次の 2 つのみ:
- `nvim/lua/config/options.lua` の `titlestring = "%t - NVIM (%{getcwd()})"`（ペイン名で nvim を視認しやすくする用途。透過率制御には未使用）
- `wezterm.lua` の `update-status` ハンドラが、過去 addon ハンドラ残骸による opacity 書換えを抑止するため毎フレーム 0.95 を明示 override

## Codex ステータス（タブバー右・2026-09-16）

`update-status` が `%LOCALAPPDATA%\Temp\codex-status\account.json` を読み、**アクティブペインが Codex の時だけ** `set_right_status` で 5h/7d 使用制限を出す。書き手は `Codex/tabbar-status.ps1`（ログオンタスク `Codex Tab Bar Status` が常駐させる）。

- **置き場所の原則**: タブバーはウィンドウに 1 本しかない。だから**アカウント共通で、切れると困る値**（使用制限）だけを置く。セッション固有の値（モデル / context / cwd / branch）は Codex 内蔵 `status_line` がペインの中で持つ。まとめるとどのセッションの cwd か分からなくなる。
- `hide_tab_bar_if_only_one_tab = false` はこの表示の前提（true だと 1 タブ時にバーごと消える）。
- **タブバー背景は端末と同じ不透明色**（`TERMINAL_BG = "#000000"`＝color_scheme 未指定時の WezTerm 既定を明示したもの）。以前は `rgba(0, 0, 0, 0)` の完全透明で、タブの右側＝使用制限を出す領域だけが `window_background_opacity = 0.95` を無視して素通しになり数字が読めなかった。`format-tab-title` の `edge_background` も同色にして筋が残らないようにしてある。`config.colors` に足したキーは、`update-status` の copy_mode override（colors を丸ごと置換する）にも**同じものを足す**こと。
- 旧方式（セッションごとに下端 4 段ペインを分割）は廃止。ペイン幅は分割で 47 桁まで落ち、内蔵行すら 63 桁で切れるのが理由。詳細 `docs/troubleshooting.md` #29。

## gotcha

- **🚫 `wezterm.lua` から子プロセスを起こさない**: `wezterm.background_child_process` で `conhost --headless pwsh` を常駐起動しようとしたら、**30 秒ごとに `0xc0000142`（STATUS_DLL_INIT_FAILED）のモーダルダイアログ**が出た（2026-09-16 実測。System ログ ID 26 で 6 件）。`wezterm-gui.exe` はコンソールを持たない GUI プロセスなので、子の conhost が初期化できない。常駐はタスクスケジューラの責務（`Codex/register-*-task.ps1`）。`automatically_reload_config = true` は**保存した瞬間に本番へ出る**ので、GUI からの子プロセス起動は必ず手で 1 回試してからループに入れる。

- **reload とイベントハンドラ残骸**: 旧 Claude Code addon 等の `wezterm.on()` が config reload では消えない。完全再起動が必要。詳細 `docs/troubleshooting.md` 第 2 項。
- **`Search:` バー誤発火**: `act.CopyMode("ClearPattern")` を Multiple action 内で呼ぶと副作用で search overlay が出る。**ClearPattern は使わない**。
- **CopyMode key_table 上書きの罠**: `config.key_tables.copy_mode = {...}` は WezTerm デフォルトを完全置換（fall through しない）。必要なキーは全て自前で定義する（矢印キー優位＋hjkl 併設、`/` `?` は誤発火防止で `act.Nop`）。逆に **`config.mouse_bindings` は既定とマージ**される（消したい既定バインドは明示上書きが必要）。
- **GPU レンダラー**: `front_end = "WebGpu"` + `HighPerformance` は 2026-07-03 に試して**不採用**（Optimus/NVIDIA 環境で入力ラグ・透過破損の上流報告多数、かつ凍結 2 種= #12/#13 はどちらも GPU 非起因）。既定 OpenGL のまま運用。Optimus のアダプタ固定は Windows 設定 > グラフィックス で行う。詳細 `docs/troubleshooting.md` #14。
