# Codex ステータス表示の仕様

内蔵フッターは `[tui].status_line = ["model-with-reasoning", "context-remaining", "thread-name"]`。モデル＋effort、コンテキスト残量、セッション名をCodex自身が表示する。`/rename <名前>` で命名でき、未命名の場合は名前を省略する。contextの計算と表示を自作しない。

WezTerm下端4セルの自作ペインに3行を描画する。

| 行 | 表示 | データ源 |
|---|---|---|
| 1 | 5h/7d使用率、リセットまでの時間 | 対象rolloutのtoken_count.rate_limits |
| 2 | 作業ディレクトリ | 対象rolloutのsession_meta/turn_context.cwd。ホームを `~` へ短縮 |
| 3 | Gitブランチ、変更状態、ahead/behind | gitの読み取りコマンド |

5h/7dは使用率。50%以上は黄色、80%以上は赤、それ未満は緑。cwdは青、Gitは緑。

Git記号は `=` 競合、`+` ステージ済み、`!` 変更、`?` 未追跡、`x` 削除、`vN` behind、`^N` ahead。

`-Watch` は2秒間隔で更新する。初回はログ末尾16MB、更新時は256KBから最新の情報を読み、取得済みの値を保持する。描画は変更された行のみを1回の書き込みで更新し、全画面消去を行わない。データ未取得時は制限を `limits: unavailable` と表示する。Claude専用callbackの編集行数は取得しない。

## セッションの識別と寿命

自動表示は `~/.codex/status-panes/<CLI PID>-<owner pane ID>.json` を介して対象threadへ結び付ける。WezTermは全タブを走査するが表示は対象ペインの下端4セルだけを分割し、元のフォーカスを保持する。WindowsのforegroundはMCP子プロセスになることがあるため、ppidを辿って実際のcodex.exeを識別する。

起動直後はタイトルのUUIDで捕捉する。CLI 0.154.0ではタイトルのUUIDが29文字へ省略されるため、一意に一致するrolloutだけを採用する。SessionStartは最初のターンで完全なUUID・transcript・cwdを通知し、既存表示を更新する。共有mutexとatomic renameでタイトル捕捉とフックの競合を防ぐ。

threadが変われば制限・cwdをリセットする。モデル/effortの表示は内蔵フッターへ委譲する。SessionEnd、CLI終了、ownerペイン消失のいずれでも表示が終了する。PID再利用はプロセス開始時刻で検出し、古いSessionEndは別threadのbindingを終了させない。

制限のリセット時刻はepochを保持し、毎描画で残時間を計算する。ログの制限値は最後に取得したスナップショットであり、全セッションで同時に更新される保証はない。

UUIDが一致しない場合にcwdの別セッションへフォールバックしない。`-SessionId` は単発診断用にも使える。SessionIdなし・bindingなしの単発診断のみcwdの最近更新されたログを選ぶ。`CODEX_HOME` を指定した隔離環境で8件の回帰テストを実行できる。

公式参照: [Codex hooks](https://learn.chatgpt.com/docs/hooks)、[WezTerm split](https://wezterm.org/config/lua/pane/split.html)。


## 分割後の配置維持と操作案内

監視中はCLIの幾何情報も読み、表示がownerと同じタブ/左端/幅、直下（owner.top + owner.rows + 1）、高さ4セルであることを確認する。分割で崩れた場合は既存表示を `split-pane --move-pane-id` でowner直下へ移動する。ユーザーのCodexやシェルは移動・終了させない。ズーム中は修復しない。ownerが6行以下の場合も追加縮小を避ける。移動前のGUI focused_pane_idを復元する。

既定の分割キー（Ctrl+Alt+Shift+5 / 引用符系）を明示定義し、表示が選択中ならownerを分割対象にする。新しいシェルへフォーカスする。

`[tui.keymap.composer].toggle_shortcuts = []` で `? for shortcuts` を非表示にする。これは `?` のヘルプoverlayも無効にする。内蔵status_lineとは別設定であり、起動済みCLIには次回起動時に反映する。全フッター行を消す設定ではないため、実行中の中断・queue・終了確認などの案内は残る。根拠: [Codex footer実装](https://github.com/openai/codex/blob/main/codex-rs/tui/src/bottom_pane/footer.rs)、[keymap実装](https://github.com/openai/codex/blob/main/codex-rs/tui/src/keymap.rs)。
