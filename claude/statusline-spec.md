# statusline 設計仕様

Claude Code statusLine（`claude/statusline.ps1`）の設計仕様。
（旧独立リポ `Repositories/statusline` の `CLAUDE.md` を 2026-06-18 に本リポへ合体。本リポ root `CLAUDE.md` の自動ロードと衝突しないよう `statusline-spec.md` にリネーム。）

## 正本と実体

正本は本リポの `claude/statusline.ps1`。実体（Claude Code が実行）は `C:\Users\81809\.claude\statusline.ps1`（現状は symlink 切れの実体コピー・正本とハッシュ一致 = backlog W1。次に編集したら手動コピー or 管理者で再リンク）。

WezTerm 側 statusline addon は 2026-05-21 に廃止済み（表示は Claude Code 内蔵 statusLine）。

## 現在の表示仕様(2026-08-20 時点 — 4 段縦積み)

Claude Code 入力欄の真上に最大 4 段表示。

```
◆ Opus 5 (1M context) │ ◇ eff:high │ +12 -3
◈ ctx:58%/1M │ ◐ 5h:20% ↺3h29m ◑ 7d:75% ↺3d2h ◒ F5:63% ↺6d23h
▸ ~/Documents/Repositories/setup-neovim-wezterm
⎇ master !?
```

ultracode が効いている時は 1 段目が `◆ Opus 5 (1M context) │ ◇ eff:high+ultracode │ +12 -3` になる（2026-10-20〜・下記「effort セグメントと ultracode 検出」）。

| 段 | 内容 | 意味 |
|---|---|---|
| 1 | モデル │ effort │ 編集行数（+ vim モード） | 「今の設定と成果」系 |
| 2 | ctx │ 使用制限（5h / 7d / premium 週間） | 「残量メーター」系を一行に集約 |
| 3 | 現在地（dir） | 開発コンテキスト |
| 4 | git ブランチ + status | 開発コンテキスト |

> **なぜ縦積みか**（2026-08-20 に 2 段 → 4 段）: WezTerm を細かくペイン分割する運用だと、旧 1 段目（model〜ctx〜制限〜編集行数を横一列）は **80 列前後あり、ペイン幅で右端が切れて使用制限が見えなくなる**。statusLine payload には端末幅が含まれないため動的折り返しは不可能。よって**意味単位で固定段割り**した。
>
> **空行は出さない**: 中身の無い段（ctx 未取得 / rate_limits 不在 / git 非管理下）は行ごと落とすので、実際の行数は payload 次第で 4 行以下。セグメント連結は `Join-Segments`（空を除外して ` │ ` 結合）に一本化してあるので、先頭末尾に孤立したセパレータは出ない。

### effort セグメントと ultracode 検出

表示は `◇ eff:<段>` で、**ultracode が効いている時だけ後ろに `+ultracode`（赤）を付ける**（2026-10-20〜）。段の文字と色は ultracode の有無で変えない:

```
◇ eff:high              ← ultracode OFF
◇ eff:high+ultracode    ← ultracode ON（段は high のまま）
```

**2.1.284 で仕様が変わった**（本体の CHANGELOG「Changed Ultracode into its own toggle in /effort (Tab, or /effort ultracode [on|off]): it no longer forces xhigh effort and stays on at any effort level」）。ultracode は effort の一段（xhigh の別名）ではなく、**effort とは別のセッション単位のオンオフ**になった:

- 切り替えは `/effort ultracode [on|off]`（引数なしは on・トグルではない）か、`/effort` のスライダーで Tab。段は変わらない（`Ultracode on (this session only): dynamic workflows on every task. Effort stays high.`）
- ローカルでは `/effort <段>`・`/effort auto` で ultracode は切れない（切れるのは ssh・direct・クラウドのセッションを見る側のクライアントの時だけで、その時は文言に ` · Ultracode off` が付く）
- 効いているかは本体の `vg(ultracode, model)`＝要求していて、かつ `$M(model)`（dynamic workflows が有効で、モデルが xhigh に対応）。非対応モデルへ `/model` で替えると、要求は残っていても OFF になる
- 始まりの値は設定キー `ultracode`（`--settings` などで渡すセッション単位の物）か `--effort ultracode`（こちらは段も xhigh にする）。**`--continue`/`--resume` では transcript から戻らない**。`/clear` では持ち越す

**payload には今も出ない**（2.1.304 で確認）:

- payload ビルダーは `...KS(He)&&{effort:{level:m2(He,be)}}` の 1 キーだけ。`m2` が返すのは low / medium / high / xhigh / max の 5 値のみ。再描画のウォッチ対象 `B$r`（tokenUsage・permissionMode・vimMode・mainLoopModel・fastMode・effortValue・thinkingEnabled・prStatus）にも ultracode は無い
- 子プロセスの `CLAUDE_EFFORT` は段の写しだけで、`*ULTRACODE*` の環境変数は無い。`~/.claude/sessions/<pid>.json` にも無い
- 外へ出す口（SDK の `get_settings` の `applied.ultracode`・Remote Control の `is_ultracode_active`）はあるが、statusLine の子プロセスからは読めない

**確実な足跡は transcript の attachment レコード**。本体の `zIr` が、普通のプロンプト（か delivered turn の始まり）の直後に書く:

```json
{"attachment":{"type":"ultra_effort_enter","reminderType":"full"},"type":"attachment","timestamp":"…","sessionId":"…"}
{"attachment":{"type":"ultra_effort_exit"},"type":"attachment","timestamp":"…","sessionId":"…"}
```

`zIr` は覚えている発言を後ろから見て直近の `ultra_effort_*` と比べ、効いているのに直近が enter でなければ enter/full、enter の後に人の発言が 10 回たまったら enter/sparse、効いていないのに直近が enter なら exit を出す。main thread だけ（subagents の transcript には出ない）で、dynamic workflows が無効なら呼ばれない。スキルの起動・`!` の bash・ローカルのスラッシュコマンドでも呼ばれない。

statusline は transcript を**前から順に読んで状態を追う**（最後に効いたアンカーが今の状態・何も無ければ OFF）。1 行は上から順に最初に当たった種類として扱う:

| 順 | アンカー（エスケープされていない生 JSON の部分文字列） | 状態 |
|---|---|---|
| 1 | `"attachment":{"type":"ultra_effort_enter"` | ON |
| 1 | `"attachment":{"type":"ultra_effort_exit"` | OFF |
| 2 | 人のプロンプト行（`"origin":{"kind":"human"}` を含み `"attachment":{` を含まない・スキルの起動行 `"content":"<command-message>` と `"/"` で始まる入力 `"content":"/` は除く） | 圧縮で保留中なら OFF（ON のままなら直後の enter/full で ON に戻る）。それ以外は何もしない |
| 3 | `/effort` の結果が `Ultracode on (this session only)…` か、末尾に ` · Ultracode on` | ON |
| 3 | `/effort` の結果が `Ultracode off. Effort stays …` か、末尾に ` · Ultracode off` | OFF |
| 3 | `/effort status` の `Current effort level: …`・`Effort level: auto …` で ` · Ultracode on` が無い | OFF（status は「今効いているか」を言う） |
| 3 | `/effort` の結果のそれ以外（`Set effort level to …`・`Effort level set to auto`・`Cleared effort …`・`Ultracode isn't available …` ほか） | **読み飛ばす**（前のアンカーを上書きさせない） |
| 4 | `"subtype":"compact_boundary"`（その時 ON） | 保留（ON のまま・下記） |

`/effort` の結果（`"content":"<local-command-stdout>`）は切り替えた瞬間に書かれる（`type:"system",subtype:"local_command"` と `type:"user"` の 2 形）。enter/exit は次のプロンプトまで書かれないので、その窓を塞ぐ補助。` · ` の点は U+00B7（コードでは `[char]0x00B7`）。人のプロンプト行を stdout より先に見るのは、**人が `<local-command-stdout>Ultracode on (…` で始まる文を貼った時に、/effort の結果と取り違えない**ため（実 transcript で本物の stdout の行に `origin` が付いた例は 0 件）。

> **旧版（2026-08-20）の判定が新仕様で外れていた点**: ① payload の段が xhigh の時しか読まなかった＝high のまま ultracode を入れても出なかった ② `Set effort level to …`・`Effort level set to auto`・`Cleared effort …` を OFF として扱っていた＝ローカルでは ultracode を保つので、ON なのに消えた ③ 新しい文言 `Ultracode on (this session only)`・`Ultracode off.` を拾っていなかった。旧文言 `Set effort level to ultracode …`・`Current effort level: ultracode` は 2.1.286 以降の本体に無い。

#### 圧縮の扱い（保留）

圧縮の後、本体は圧縮前の enter を忘れる。そのため:

- ON のまま → 圧縮後の最初の普通のプロンプトで enter/full が**必ず**書き直される
- 圧縮の後に stdout の残らない経路（Remote Control からの effort 変更・`/model` で非対応モデルへ・workflows の無効化）で OFF になる → exit が**二度と書かれず**、ファイル上は圧縮前の enter が最後に残る

圧縮を読み飛ばすと後者で「ずっと ON」と嘘をつき、圧縮で OFF に倒すと前者で「長いターンの途中の自動圧縮のたびに、次のプロンプトまで消える」。そこで**圧縮の時点で ON なら保留にして ON を保ち、次の人のプロンプト行で OFF に倒す**（ON のままならその直後の enter/full で ON に戻る）。実 transcript（2.1.286 以降の行）で、圧縮の時点で ON・その後に人が発言した 22 回すべてがこの規則どおりだった（21 回は直後に enter/full、1 回は再開を挟んで本当に OFF）。enter/exit 42 件はすべて人のプロンプト行の 40 行以内に書かれていた。

人のプロンプト行から除く物: attachment の入れ子（途中で送った追加メッセージ＝`queued_command` の中にも `"origin":{"kind":"human"}` が入る）と、`zIr` が走らないことがある行＝スキルの起動行と、`/` で始まる入力（コマンド名の形でない `/c/Users/…` や実在するパスで始まる文は、添付を作らずに送られる）。どちらも `origin` は付くので、保留を解くと enter が来ないまま次の普通のプロンプトまで消える。除いた行では保留が続く（本当に OFF なら 1 ターン ON が残る＝安全側ではないが短い）。

#### モデルの表（transcript を読まずに OFF）

xhigh に対応しないモデルでは ultracode は効かない。本体 `Zgt` の既定の固定表（2.1.304）＝`claude-3-*`・`claude-opus-4-0/4-1/4-5/4-6`・`claude-sonnet-4-0/4-5/4-6`・`claude-haiku-4-5`。payload の `model.id` がこれに当たる時は読まずに OFF（`$UC_NO_XHIGH`・日付の付いた ID・`[1m]`・Bedrock / Vertex の書き方も当たるようにしてある）。本体と同じ向き＝安全側。

塞ぐ穴: `/effort ultracode on` の直後にプロンプトを送らず `/model` でこの表のモデルへ替えると、enter が一度も書かれない＝exit も永久に書かれず、アンカーだけでは ON のまま残る。

#### 2 つの AND ゲート（アンカーの行ごと。欠けた行は無かった物として扱う）

| # | ゲート | 何を防ぐか |
|---|---|---|
| 1 | 行の `sessionId` == payload の `session_id` | 別セッションのレコードの混入 |
| 2 | 行の `timestamp` >= このプロセスの `startedAt` | **`--continue` の再開穴**。transcript は再開で同じファイル・同じ `sessionId` に追記され続け、ultracode は再開で戻らないので、再起動前の enter を拾わない。`startedAt` は `~/.claude/sessions/$env:CLAUDE_PID.json` から取る（`CLAUDE_PID` は claude が子プロセスへ注入。`/clear` などで会話が替わると本体がこのファイルの `sessionId` を書き直す＝`En({sessionId:…})`） |

旧ゲート「payload の `effort.level` が `xhigh` の時だけ読む」は撤去した（どの段でも ON になりうる）。代わりに **effort が payload に無い時と、モデルが上の表に当たる時は読まない**。pid ファイルは本体が busy/idle のたびに切り詰めてから書き直す（`fs/promises` の `writeFile`）ので、書きかけ（空・空白だけ・途中で切れた JSON）を読んだ時だけ、同じ会話の控え（下記）の `startedAt` を使う。

**誤検出防止の要**: アンカーは**エスケープされていない生 JSON の部分文字列**。ツール出力に同じ語が出ても JSON 内では `\"attachment\"` とエスケープされるので**構造的に一致しない**。

#### 読んだ所までの控え（差分読み）

段を問わず毎回読むようになったので（旧版は xhigh の時だけ）、毎回の全走査をやめた。プロセスごとに `%TEMP%\claude-statusline\uc-<CLAUDE_PID>.json` へ次を控え、次回は**追記された分だけ**読む:

```json
{"path":"<transcript_path>","sid":"<session_id>","startedAt":1792454668126.0,"offset":2901773,"tail":"<offset の直前 4KB の SHA-256>","on":false,"pending":false}
```

- `offset` は最後の改行の次のバイト。書きかけの最後の 1 行（改行なし）は数えずに次回へ回す
- 使う条件: 同じ `path`・`sid`・`startedAt`、`offset` <= 今の長さ、追記分 <= 40MB、**今のファイルの `offset` の直前 4KB の指紋が `tail` と同じ**。どれかが外れたら最初から読む。指紋は、本体が書いた行を消して後ろを詰め直す「墓標の削除」（`performRemoveByUuid`・ストリームのやり直しなどで起きる）で、位置だけ合って中身がずれたのを見抜くため（直前が改行かだけでは、行末の共通の欄＝sessionId・version・slug で偶然そろう）
- 値の形まで確かめる（`path`・`sid`・`tail` が文字列、`on`・`pending` が真偽値、`startedAt` > 0、`offset` >= 0）。形が合わない控え・旧形式の控えは無かった物として最初から読み、書き直す
- 最初から読む時は 40MB 超なら末尾 32MB だけ（途中から読んだ 1 行目は捨てる）。最初から読むのは、ふつうはプロセスの起動直後＝ゲート 2 を通る行はまだ末尾にしか無いので、窓で取りこぼさない（窓より前は「無かった」扱い＝始まりは OFF なので、取りこぼしても向きは安全側）
- 書く時は別名（`uc-<pid>.json.<pwsh の PID>.tmp`）に書いてから置き換える（書きかけを読まれない）。置き換えに失敗しても一時ファイルは消す。控えが無かった回だけ、7 日より古い `uc-*` を消す
- 一時ファイルなので消えても困らない（次の回に最初から読むだけ）。`%TEMP%` の掃除で消えてよい

旧版の「毎回の全走査（40MB 超は末尾 32MB）」は、行の数で重さが決まり、負荷の高い時の実測で 40MB 手前が 1 回約 1 秒・510MB の末尾 32MB で 0.5〜0.8 秒だった（2026-10-20）。さらに、40MB を超える会話で ON の最中に enter から 32MB 以上進むと、窓が最後の enter を切り落として `+ultracode` が消えた（実 transcript 2 本・345 プロンプト中 9 時点）。差分読みはこの両方を解く。

実測（2026-10-20・ほかのセッションも動いている中・中央値）。statusline は毎回新しい pwsh で動くので、本番に近いのは「新しいプロセス」の列:

| 場面 | 新しいプロセス | 同じプロセスで繰り返し |
|---|---|---|
| 控えあり・追記なし | 約 75〜100ms | 約 4〜8ms |
| 控えあり・追記 100KB〜1MB | 約 80〜110ms | 約 15〜25ms |
| 控えなし（初回）0.7MB / 10MB / 40MB 手前 | 約 95〜115 / 120〜190 / 180〜340ms | 約 8〜10 / 30〜70 / 90〜210ms |
| 控えなし（初回）510MB（末尾 32MB） | 約 265ms | 約 130ms |
| スクリプト全体（pwsh の起動込み・控えあり） | 約 0.76〜0.94 秒 | — |

新しいプロセスの約 80ms は、関数を初めて呼ぶ費用（JIT・SHA-256 の初回）がほとんどで、読む量はほぼ効かない。スクリプト全体の大半は pwsh の起動（約 0.25 秒）と git などほかの節（約 0.5 秒）。旧版の毎回の全走査は「控えなし」の列と同じ費用が**毎回**掛かり、負荷の高い時は 40MB 手前で 1 回約 1 秒・510MB の末尾 32MB で 0.5〜0.8 秒だった。指紋（4KB の読み直しと SHA-256）で増えるのは 1 回約 10ms で、全体の揺れ（±100ms 以上）に埋もれる。

#### 検証（2026-10-20・2.1.304）

- **規則の裏付け**（2.1.286 以降の行を含む実 transcript 全体）: 圧縮の時点で ON・その後に人が発言した 22 回すべてが保留の規則どおり（21 回は直後に enter/full・1 回は再開で本当に OFF）。enter/exit 42 件はすべて人のプロンプト行の 40 行以内。本物の `/effort` の結果の行に `origin` が付いた例は 0 件
- **実 transcript を途中で切った写し**（6 本・1,771 か所）: PowerShell の判定と、規則の文面だけから独立に書いた Python の判定の不一致 0。再開の穴（ゲート 2）も 2 本で確認
- **実 transcript を少しずつ伸ばす再生**（6 本・1,447 回・510MB の会話も最後まで・行の途中の切れ目と 40MB ちょうどの一括追記を含む）: 控えを使った差分読みの結果・`offset`・状態・指紋が、窓なしの全走査と毎回一致。控えを捨てたのは各列の最初の 1 回だけで、ほかはすべて指紋を照合して差分読みになった。旧版の 32MB の窓で取りこぼしていた時点もすべて正しく ON。行を消して詰め直した陽性対照（直前の 1 バイトは改行のまま）も指紋で見抜いた
- **合成の試験**（約 500 件: `/effort` の文言 18 種・圧縮と保留・スキル行と `/` 行・ゲート・40MB の窓・控えの壊れ方と旧形式・pid ファイルの書きかけ・同時実行・墓標の削除・7 日の片付け・モデルの表 40 表記・表示の色と並び・空の stdin や壊れた行）: 外れは意図して残した参考の 2 件だけ（下の「まれな並び」の 1 件と、大文字小文字だけ違う指紋＝`-ceq` に直した）
- **反証**（本体のコードを読んで穴を探す側）を 2 回。見つかった穴は直したか、下の「残るリスク」に書いた
- 本セッション（xhigh・ultracode OFF）の実物でスクリプト全体を流し、`◇ eff:xhigh` と出ることを確認。ON の写しでは `◇ eff:high+ultracode`、低い段・max でも `+ultracode` が付くことを確認

#### 残るリスク

1. **1 ターンの遅れ（stdout の残らない切り替え）**: 次の経路では transcript に何も残らないので、次の普通のプロンプトの enter/exit まで表示が前のまま（自己修復する）。
   - Remote Control の `apply_flag_settings` で effortLevel だけ送る（ultracode も切れる）
   - **作業中（ターンの途中）に打った `/effort`**: 即時実行の local-jsx で、結果は通知に出るだけで transcript に残らない。ultracode のターンは長いので、この窓は長くなりうる
2. **切り替えた直後は描き直されない**: `/effort ultracode on|off` だけでは statusline は再実行されない（ウォッチ対象 `B$r` に ultracode が無い）。次の応答で描き直される時には `/effort` の結果が transcript にあるので正しく出る。すぐ見たいなら `statusLine.refreshInterval`（秒）を足す手があるが、周期ごとに pwsh の起動が走るので入れていない。
3. **途中で workflows を無効にした時**（圧縮を挟まない場合）: `zIr` そのものが呼ばれず exit が書かれない＝`+ultracode` が残る。`/effort status` を打てば、その結果（` · Ultracode on` が無い）で OFF に直る。
4. **`/clear` の直後**: 新しい transcript には最初のプロンプトまで印が無い＝ON を持ち越していても出ない（最初のプロンプトの enter/full で出る）。
5. **再開を ON で始めた時**（設定キー `ultracode: true`・`--effort ultracode`・Remote Control の effort の種まき）: 再開前の最後の印が enter だと本体は何も書かない（もう enter なので）。ゲート 2 で古い enter を捨てるので、10 発言後の enter/sparse まで出ない。今の `settings.json` にこのキーは無い。
6. **控えが途中で使えなくなった時**（40MB 超の会話で、一度に 40MB を超える追記・墓標の削除で縮んだ・控えが消えた）: 末尾 32MB の窓で読み直すので、ON の最中に最後の enter がそれより前だと `+ultracode` が消え、その状態が控えに残る（次の enter＝最大 10 発言後まで）。向きは安全側。控えを消して伸ばし続けた実験で、3 本の会話で 4〜30 回の更新のあいだ消えた。
7. **スキルや `/` で始まる入力のターン**: 圧縮の後の最初の発言がこれだと保留が続くので、圧縮の前に stdout の残らない OFF（残るリスク 1）があった時は、そのターンの間 ON が残る（実例 0）。
8. **まれな並び**（どれも実データでの例は無し・反証の合成試験で確認）: 会話の途中の `/resume` で、別のプロセスが自分の起動後に書いた enter を拾う（次のプロンプトまで嘘の ON）／圧縮で残された区間（`preservedMessages`）に enter が入っていると、enter/full が書かれないのに保留を解いて OFF（最大 10 発言）／Esc の取り消しや巻き戻しで enter が会話から外れた後に stdout の残らない OFF が重なる（嘘の ON）／`/effort` 以外の local-command-stdout（フォークしたスキルの結果など）の文面に ` · Ultracode on|off` が入る（取り違え）／PID の再利用・同じ会話の再開・pid ファイルの書きかけの 3 つが重なった 1 回だけ、前のプロセスの控えで ON と出る（次の回に直る）。
9. **陳腐化**: attachment レコードと `/effort` の文言とモデルの表は claude 内部実装であり公開仕様ではない（文言は 2.1.286 で一度変わった）。将来変わっても**静かに `+ultracode` 無しへ縮退するだけ**で誤表示にはならない（モデルの表は新しい非対応モデルが増えると取りこぼすが、その時はアンカーどおりの表示に戻るだけ）。次回監査で claude.exe 実体に対して再確認すること。

#### 不採用にした経路

| 経路 | 却下理由 |
|---|---|
| payload / `effort.level` | 段しか載らない（ultracode の欄が無い） |
| `CLAUDE_EFFORT` 環境変数 | 段の写し。`*ULTRACODE*` env は存在しない |
| `~/.claude/sessions/<pid>.json` | effort/ultracode フィールドを持たない（`startedAt` の取得にだけ使用） |
| `~/.claude/settings.json` の `ultracode` キー | 静的な**入力**であって live state ではない。対話の切り替え（`/effort ultracode`・スライダー）は保存されず、Remote Control や `/model` はキーに触れずに OFF にできる＝**嘘をつきうる**ので却下（2026-08-20 に一旦実装したが撤去） |
| SDK の `get_settings`・Remote Control の `is_ultracode_active` | 外向けの control protocol / メタデータで、statusLine の子プロセスからは届かない |
| assistant 行の `effort`・`perTurnEffort` | 段だけ。ultracode の欄は無い |
| `workflow_keyword_request` の attachment | プロンプトに「ultracode」の語が入った**そのターンだけ** Workflow を使わせる合図。セッションのオンオフではない |
| `~/.claude/history.jsonl` | 打鍵コマンドを記録するだけで結果ではない（失敗した `/effort ultracode on` も残る）。引数無しの `/effort`（スライダー）が 194 件中 192 件＝カバー率 ~1%。作業中の `/effort` の穴（残るリスク 1）を塞ぐ候補だが、失敗の取り違えのほうが嘘の ON になるので入れていない |
| system-reminder のテキスト（`Ultracode is on:`） | 単独では transcript に永続化されない（attachment の `rendered` に入るが、同じレコードなので attachment の type を見れば足りる） |
| Claude 本体の TUI インジケータ | プロセス内 React ストア。ディスクに出ない。（余談: **セッション名を付けるとこのインジケータは丸ごと消える** — `$5 ? … : …` の else 側にしか存在せず、復活させる設定は無い。statusline 側で持つ必要があるのはこのため・2026-08-20 の観察） |

### カラーパレット (Catppuccin Frappe)

Mocha の公式落ち着き版。長時間視認しても疲れにくい muted トーン。

| 用途 | 色 | hex |
|---|---|---|
| sep / labels / brackets / size 表記 | overlay0 | `#737994` |
| git branch / safe (<50%) / 追加行 (+N) | green | `#a6d189` |
| ctx ラベル | teal | `#81c8be` |
| model | mauve | `#ca9ee6` |
| vim mode / xhigh effort | peach | `#ef9f76` |
| warn (50-80%) | yellow | `#e5c890` |
| danger (≥80%) / 削除行 (-N) / max effort / `ultracode` | red | `#e78284` |
| (定義のみ・未使用 dead) | blue | `#8caaee` |

> dir / branch は**無着色（プレーン）**で描画（旧 blue 割当は廃止、`$BLUE` は定義のみで未使用）。effort レベルは離散値で色が変わる（下記「effort セグメント」）。

### アイコン (Unicode 標準幾何記号 — Nerd Font 不要)

| 項目 | 記号 | コード |
|---|---|---|
| model | ◆ | U+25C6 BLACK DIAMOND |
| effort | ◇ | U+25C7 WHITE DIAMOND |
| ctx | ◈ | U+25C8 |
| 5h | ◐ | U+25D0 |
| 7d | ◑ | U+25D1 |
| Fable5 / premium 週間 | ◒ | U+25D2 CIRCLE WITH LOWER HALF BLACK |
| reset 残時間 | ↺ | U+21BA ANTICLOCKWISE OPEN CIRCLE ARROW |
| dir | ▸ | U+25B8 |
| branch | ⎇ | U+2387 ALTERNATIVE KEY SYMBOL |

### 数値セマンティクス

ctx / 5h / 7d / Fable5 週間はすべて **使用率(USED %)** 表示で統一(大きいほど危険)。ステージカラーも used に基づく判定:

- `< 50%` 緑(safe)
- `50-80%` 黄(warn)
- `>= 80%` 赤(danger)

### effort セグメント (◇ eff:)

`data.effort.level` を離散表示（USED% ではないので上記 <50/50-80/≥80 閾値とは別系統）:
`low`=overlay0(dim) / `medium`=green / `high`=yellow / `xhigh`=peach / `max`=red。

ultracode が効いている時だけ、段の後ろに `+`（overlay0）と `ultracode`（red）を付ける（`◇ eff:high+ultracode`）。段の文字と色は変えない。判定は上の「effort セグメントと ultracode 検出」。

### reset 残時間 (↺)

5h/7d は `resets_at`(Unix epoch) から残時間を算出し ↺ 付きで併記: `>=1d → 3d3h` / `>=1h → 2h13m` / それ未満 → `47m`。absent または経過済みなら非表示。

### Git status symbols (Starship `$all_status` 準拠)

`=` conflict, `+` staged, `!` modified, `?` untracked, `x` deleted, `v` behind, `^` ahead

着色なし(プレーン)で表示。

## 動作確認方法

```pwsh
# スクリプト単体の出力確認(JSON ダミー)
echo '{"workspace":{"current_dir":"C:\\Users\\81809\\Documents\\Repositories\\statusline"},"model":{"display_name":"Opus 4.7"},"context_window":{"used_percentage":58,"context_window_size":1000000},"rate_limits":{"five_hour":{"used_percentage":20},"seven_day":{"used_percentage":75}}}' | pwsh -NoProfile -NonInteractive -File C:\Users\81809\.claude\statusline.ps1

# Claude Code が実際にスクリプトを呼んでいるかの監視
Get-Content C:\Users\81809\.claude\statusline_debug.log -Tail 5
```

ユニットテストは無い。Claude Code 画面下端の視覚確認 + debug log のエントリ更新が事実上のテスト。

## 既知の罠

### Windows + Git Bash の backslash escape

Claude Code は Windows + Git Bash インストール環境では statusLine コマンドを Git Bash 経由で起動する。`settings.json` の `command` 内の `\` は Git Bash がエスケープとして食って path 解決に失敗 → **エラー無しで silent fail**(debug log にも残らない)。

必ず forward slash で書く:
```json
"command": "pwsh -NoProfile -NonInteractive -File C:/Users/81809/.claude/statusline.ps1"
```

公式ドキュメント (https://code.claude.com/docs/en/statusline → Windows configuration) に記載されている既知の挙動だが、ハマると原因特定が極めて困難。

## アーキテクチャ

`Claude Code が JSON を stdin に流す → statusline.ps1 がパース → 2 行を stdout に出力 → Claude Code が入力欄の上に描画` というシンプル構造。

更新トリガー(公式仕様):
- 新規アシスタント応答ごと
- `/compact` 完了時
- パーミッションモード変更時
- vim モードトグル時
- 300ms デバウンス

## データソース

| 表示項目 | ソース |
|---|---|
| モデル名 | `data.model.display_name` |
| effort レベル | `data.effort.level` |
| ultracode（`+ultracode`） | payload に無いので `data.transcript_path` の transcript（attachment・`/effort` の結果・圧縮・人のプロンプト行）＋ `~/.claude/sessions/$env:CLAUDE_PID.json` の `startedAt`。読んだ所までの控えは `%TEMP%\claude-statusline\uc-<CLAUDE_PID>.json`。`data.model.id` が xhigh 非対応の表に当たる時は読まない |
| ディレクトリ | `data.workspace.current_dir`(`~` 短縮 + 末尾 10 階層) |
| Git ブランチ / dirty / ahead-behind | `git rev-parse` / `git status --porcelain` / `git rev-list` |
| Context 使用率 | `data.context_window.used_percentage` + `context_window_size` |
| 5h / 7d レート使用率 + reset 残時間 | `data.rate_limits.{five_hour,seven_day}.used_percentage` / `.resets_at` |
| Fable5 / premium 週間制限（◒）| `data.rate_limits.{seven_day_overage_included,seven_day_opus,seven_day_sonnet}`（優先順で最初の 1 つ）。**2.1.216 では payload に未搭載＝現在は非表示**。下記「前方互換」参照 |
| 編集行数 (+追加 / -削除) | `data.cost.total_lines_added` / `data.cost.total_lines_removed`（>0 のみ表示） |
| Vim mode | `data.vim.mode` |

レート情報は Claude.ai Pro/Max 加入者のみ初回 API 応答後に含まれる。それまでは `rate_limits` フィールド自体が無いのでセグメントは非表示になる(コード側でガード済み)。

### Fable5 週間制限の前方互換（◒ セグメント・2026-07-21 追加）

**現状**: Claude Code 2.1.216 の statusLine payload の `rate_limits` は `five_hour` / `seven_day` の 2 つ**しか**載らない（claude.exe のビルダー `I={...x.five_hour&&…,...x.seven_day&&…}` を直接確認）。「Fable 5 の週間制限」は payload には**来ない**。

だが値自体は claude 内部に存在する:
- 出所はレスポンスヘッダ `anthropic-ratelimit-unified-7d_oi-*`（`hyu()` がメモリ `Fkt` にパース）。
- claude の内部ラベル表 `$kt` に **`seven_day_overage_included:"Fable 5 limit"`**（兄弟 `seven_day_opus:"Opus limit"` / `seven_day_sonnet:"Sonnet limit"`）が実在。`/usage` や警告文（"try /model opus · more runway"）はこれを使う。
- ディスク永続の `cachedUsageUtilization`（`.claude.json`）も候補だが、**現在不在**かつスキーマ別系統（`overage_included` を持たない）＝読めない。

**設計**: statusline.ps1 は `seven_day_overage_included`（無ければ `seven_day_opus` → `seven_day_sonnet`）を優先順で読む。**今日は payload に無いので何も描画しない（前方互換の休眠状態）**。将来 Claude Code が premium-weekly キーを payload に載せた瞬間、追加作業ゼロで `◒ F5:xx%` が自動点灯する。内部ラベル表が既にある以上、payload 搭載は時間の問題という判断。

**もし「今すぐ数値を出す」なら**: usage エンドポイントを叩く自前ポーラー（scheduled task → キャッシュ JSON → statusline が読む）が唯一の手だが、未公開 OAuth 経路・トークン取扱い・claude 更新での破綻リスクを抱えるため 2026-07-21 時点では**採らない**（低保守方針）。将来 payload 搭載が来なければ再検討。

## セッション変遷ログ (2026-05-19 〜 2026-05-21)

1. **初期**: WezTerm 側で ccusage + git + statusline_input.json 経由で画面下端に表示。Claude Code 内蔵 statusLine は非表示問題で使えなかった
2. **2026-05-19**: dump 専用 `statusline_dump.ps1` を廃止し `statusline.ps1` 1 本に統合。空文字返却が非表示の原因だったため、表示文字列を返すように修正
3. **2026-05-21**:
   - Windows + Git Bash の backslash escape 問題を発見 → settings.json の path を `/` 区切りに修正 → 内蔵 statusLine が表示可能に
   - WezTerm 側 addon を削除(set_right_status のクリア用退避ハンドラだけ残置)
   - 1 行 → 2 行レイアウト化(画面幅切れ対策) — 2026-08-20 にさらに 5 行化(ペイン分割対策)
   - 5h/7d を残量 → 使用率に変更
   - ctx を残量 → 使用率に変更(すべて「大きいほど危険」で統一)
   - 時刻表示削除
   - カラーを Catppuccin Mocha → Frappe(落ち着き muted トーン)に変更
   - 1 段目を runtime info、2 段目を dir/branch に並べ替え
   - dir/branch は無着色のプレーンテキスト化
   - Nerd Font アイコンが描画されなかったので Unicode 標準幾何記号に変更

途中で試した没案: 背景塗りつぶし pill 風 / 透明風 muted 暗背景 / 時刻表示あり版。

## 関連ファイル

- 実体スクリプト: `C:\Users\81809\.claude\statusline.ps1`
- 設定: `C:\Users\81809\.claude\settings.json`(`statusLine.command` は `/` 区切りで `statusline.ps1` を指す)
- スクリプト呼び出しデバッグログ: `C:\Users\81809\.claude\statusline_debug.log`
- (歴史的)WezTerm 設定: `C:\Users\81809\.config\wezterm\wezterm.lua` — addon 削除済み、退避ハンドラ + タブバー下端化のみ残存

## 既存の軽い技術的負債(影響無し、お好みで掃除可)

1. **dead dump コード**: `statusline.ps1` は `statusline_input.json` への JSON dump を毎回続けているが、現在読者は存在しない。3 行 + 1 ファイル書き込みのコストが残るが視覚的影響ゼロ
2. **`~/.claude/statusline_dump.ps1`**: 旧 dump 専用版が残置されている。誰からも呼ばれていないので削除可
3. **`~/.claude/*.bak*`**: 設定/スクリプトのバックアップ複数。安定後に削除可
4. **WezTerm の `update-status` 退避ハンドラ**: 旧 addon 残骸クリア用。WezTerm を完全再起動した後は不要(削除可)
5. **WezTerm 下端タブバー設定**: `tab_bar_at_bottom = true` + `hide_tab_bar_if_only_one_tab = false` は元々 statusline 描画領域確保のための設定。statusline 廃止後は下端に薄い空タブバーが残る。デフォルトに戻すなら両方反転 + `format-tab-title` の単一タブ特例も撤去
