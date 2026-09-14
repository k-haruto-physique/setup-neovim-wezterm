# Codex ステータス表示の仕様

WezTermの下端5セルに4行を描画する。Codex内蔵フッターは `[tui].status_line = []` で非表示にする。

| 行 | 表示 | データ源 |
|---|---|---|
| 1 | モデル、reasoning effort | rolloutのturn_context。未取得時はconfig.tomlの設定値 |
| 2 | context使用率/容量、5h/7d使用率、リセットまでの時間 | rolloutのtoken_count |
| 3 | 作業ディレクトリ | 起動時のcwd。ホームを `~` へ短縮 |
| 4 | Gitブランチ、変更状態、ahead/behind | gitの読み取りコマンド |

context使用率は直近ターンの入力+出力トークンをmodel_context_windowで割る。累積トークンとは異なる。5h/7dも使用率を表示する。使用率50%以上は黄色、80%以上は赤、それ未満は緑。モデルは紫、cwdは青、Gitは緑。effortはlow灰色、medium緑、high黄色、xhigh橙、max赤。

Git記号は `=` 競合、`+` ステージ済み、`!` 変更、`?` 未追跡、`x` 削除、`vN` behind、`^N` ahead。

`-Watch` は2秒間隔で更新する。初回はログ末尾16MB、更新時は256KBから最新の情報を読み、取得済みの値を保持する。描画は変更された行のみを1回の書き込みで更新し、全画面消去を行わない。データ未取得時はcontextを `unavailable` と表示する。Claude専用callbackの編集行数は取得しない。

`-SessionId` 指定時は対象thread UUIDに固定する。未指定時は同じcwdの最近更新されたログを選ぶ。同じcwdの並列セッションを自動で厳密に区別する仕組みはない。シェルで通常の `codex` を起動した場合は `Ctrl+Shift+Y` で追加する。
