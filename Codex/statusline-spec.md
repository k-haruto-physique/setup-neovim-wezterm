# Codex ステータス表示の仕様

WezTermの下端5セルに4行を描画する。Codex内蔵フッターは `[tui].status_line = []` で非表示にする。

| 行 | 表示 | データ源 |
|---|---|---|
| 1 | モデル、reasoning effort | 現在の端末タイトルを優先、次にrolloutのturn_context。未取得時はbindingのモデル |
| 2 | context使用率/容量、5h/7d使用率、リセットまでの時間 | rolloutのtoken_count |
| 3 | 作業ディレクトリ | 対象rolloutのsession_meta/turn_contextのcwd。ホームを `~` へ短縮 |
| 4 | Gitブランチ、変更状態、ahead/behind | gitの読み取りコマンド |

context使用率は直近ターンの入力+出力トークンをmodel_context_windowで割る。累積トークンとは異なる。5h/7dも使用率を表示する。使用率50%以上は黄色、80%以上は赤、それ未満は緑。モデルは紫、cwdは青、Gitは緑。effortはlow灰色、medium緑、high黄色、xhigh橙、max赤。

Git記号は `=` 競合、`+` ステージ済み、`!` 変更、`?` 未追跡、`x` 削除、`vN` behind、`^N` ahead。

`-Watch` は2秒間隔で更新する。初回はログ末尾16MB、更新時は256KBから最新の情報を読み、取得済みの値を保持する。描画は変更された行のみを1回の書き込みで更新し、全画面消去を行わない。データ未取得時はcontextを `unavailable` と表示する。Claude専用callbackの編集行数は取得しない。

## セッションの識別と寿命

自動表示は `~/.codex/status-panes/<CLI PID>-<owner pane ID>.json` を介して対象threadへ結び付ける。WezTermは全タブを走査するが表示は対象ペインの下端5セルだけを分割し、元のフォーカスを保持する。WindowsのforegroundはMCP子プロセスになることがあるため、ppidを辿って実際のcodex.exeを識別する。

起動直後はタイトルのUUIDで捕捉する。CLI 0.154.0ではタイトルのUUIDが29文字へ省略されるため、一意に一致するrolloutだけを採用する。SessionStartは最初のターンで完全なUUID・transcript・cwdを通知し、既存表示を更新する。共有mutexとatomic renameでタイトル捕捉とフックの競合を防ぐ。

threadが変わればcontext・制限・cwdをリセットする。モデル/effortは `/model` の変更を次のターン前にも反映する。SessionEnd、CLI終了、ownerペイン消失のいずれでも表示が終了する。PID再利用はプロセス開始時刻で検出し、古いSessionEndは別threadのbindingを終了させない。

使用量はlast_token_usage.total_tokensを使い、0も有効値として扱う。累積total_token_usageへの代替は行わない。制限のリセット時刻はepochを保持し、毎描画で残時間を計算する。ログの制限値は最後に取得したスナップショットであり、全セッションで同時に更新される保証はない。

UUIDが一致しない場合にcwdの別セッションへフォールバックしない。`-SessionId` は単発診断用にも使える。SessionIdなし・bindingなしの単発診断のみcwdの最近更新されたログを選ぶ。`CODEX_HOME` を指定した隔離環境で8件の回帰テストを実行できる。

公式参照: [Codex hooks](https://learn.chatgpt.com/docs/hooks)、[WezTerm split](https://wezterm.org/config/lua/pane/split.html)。
