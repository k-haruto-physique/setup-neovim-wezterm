# Codex ステータス表示の仕様

2026-09-16 にタブバー方式へ移し、2026-10-01 に旧方式（下端 4 段の専用ペイン）を削除した。経緯は `CHANGELOG.md` と troubleshooting #29。

## 置き場所

| 値 | 置き場所 | 理由 |
|---|---|---|
| モデル＋effort / context 残量 / セッション名 / リポ名 / ブランチ | Codex 内蔵 status line | セッションごとに違う。タブバーはウィンドウに 1 本なので、ここに出すとどのセッションの値か分からなくなる |
| 5h / 7d 使用制限 | タブバー右（`set_right_status`） | アカウント共通で 1 つで足り、切れると困る。タブバーはウィンドウ幅なので分割で縮まない |

## 内蔵 status line

`[tui].status_line = ["model-with-reasoning", "context-remaining", "thread-name", "project-name", "git-branch"]`（正本 `statusline.toml`）。幅が足りないと末尾から切れる（5 項目で約 96 桁）。

- `context-remaining` は**残り**の割合（`Context 59% left` ＝ 59% 残っている）。Claude 側の statusline の `ctx:N%` は使った割合なので、向きが逆。
- `thread-name` は `/rename` するまで項目ごと出ない。
- `git-branch` は 0.154.0 では出ない（2026-10-01 実測。最初のやりとりの後・190 桁のペインでも出なかった）。backlog W7。
- `terminal_title = ["app-name", "session-id", "model-with-reasoning"]` は**変えない**。タブバーの書き手と `wezterm.lua` が、タイトル `codex | <thread UUID> | <model>` で Codex のペインを見分けている。

## タブバー（使用制限）

- 書き手 `tabbar-status.ps1`: ログオンタスク `Codex Tab Bar Status` で常駐（2 秒間隔・多重起動は mutex で防ぐ）。全 WezTerm GUI のソケットを自分で探し（タスクは `WEZTERM_UNIX_SOCKET` を継承しない）、Codex のペインのタイトルの UUID から rollout を解決して、最も新しく書かれた rollout の `token_count.rate_limits` を `%LOCALAPPDATA%\Temp\codex-status\account.json` に書く。Codex のペインが無い時は値を `null` にする。`heartbeat` は失敗しても進める。見つからない状態が続いた時だけ `errors.log` に 1 行残す。
- 読み手 `wezterm.lua`（`update-status`）: 1 秒に 1 回だけ読む。`updated` が 30 秒より古ければ出さない。アクティブなペインが Codex の時だけ `◐ 5h:N% ↺残り │ ◑ 7d:N% ↺残り` を出す。50% 以上は黄、80% 以上は赤、それ未満は緑。
- Codex のペインがあるウィンドウは、タブが 1 つでもタブバーを出す（`window_has_codex`。Codex が見えなくなってから 5 秒は出したまま）。それ以外のウィンドウは `hide_tab_bar_if_only_one_tab = true` のまま。
- 🚫 `wezterm.lua` から書き手を起動しない（0xc0000142 のダイアログ・troubleshooting #29）。

## 操作案内の非表示

`[tui.keymap.composer].toggle_shortcuts = []` で `? for shortcuts` を非表示にする。これは `?` のヘルプoverlayも無効にする。内蔵status_lineとは別設定であり、起動済みCLIには次回起動時に反映する。全フッター行を消す設定ではないため、実行中の中断・queue・終了確認などの案内は残る。根拠: [Codex footer実装](https://github.com/openai/codex/blob/main/codex-rs/tui/src/bottom_pane/footer.rs)、[keymap実装](https://github.com/openai/codex/blob/main/codex-rs/tui/src/keymap.rs)。
