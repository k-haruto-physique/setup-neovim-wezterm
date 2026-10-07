# slack/ — Slack へ「投稿役」の名前で投稿する道具

Claude の Slack 接続（コネクタ）で投稿すると、送り主が本人の名前になり、本人が自分で書いた返事と見分けにくくなります。
そこで、Slack に**投稿役（Slack アプリのボット）**を 1 つ作り、Claude の投稿はすべて投稿役から出します。
返事を読むのは、これまでどおりコネクタで行います。

- 投稿役は **1 つだけ**作り、使うチャンネルすべてに招きます。
- チャンネルごとに見せる名前を変えられます（`--name`）。どのチャンネルにどの名前で出すかは、各リポの決まりか、全リポ共通の決まり（`~/.claude/CLAUDE.md`）に書きます。**このリポには書きません**（公開のため）。
- 鍵（ボットのトークン）は、この PC の **Windows 資格情報マネージャー**（汎用資格情報 `claude-slack-bot`）にだけ置きます。リポジトリには書きません。

## 初めて作るとき（10 分ほど・本人が Slack の画面で行う）

1. ブラウザで <https://api.slack.com/apps> を開き、「Create New App」→「From scratch」を選ぶ。
   名前（例: `Claude`）を入れ、自分のワークスペースを選んで作る。

2. 左の「OAuth & Permissions」を開き、「Bot Token Scopes」に次の 2 つを足す。

   - `chat:write`（投稿する）
   - `chat:write.customize`（チャンネルごとに表示名を変える）

3. 同じ画面の上の「Install to Workspace」を押し、「許可する」を押す。

4. 「Bot User OAuth Token」（`xoxb-` で始まる）の横の「Copy」を押す。
   **鍵を画面やチャットに貼らない。**コピーしたら、Claude のセッションに「コピーした」と伝えるか、自分で次を実行する。

   ```powershell
   python slack\post.py --store-token-from-clipboard
   ```

   鍵を資格情報マネージャーへしまい、クリップボードを空にします。画面には伏せ字でしか出ません。

5. 投稿役を使うチャンネルごとに、そのチャンネルの入力欄で次を打って招く（非公開チャンネルは招かないと投稿できない）。

   ```
   /invite @Claude
   ```

   （`Claude` は手順 1 で付けた名前）

6. つながるか確かめる。

   ```powershell
   python slack\post.py --check
   ```

7. 名前とアイコンを整える（任意・公式の Claude アプリと見分けるため）。

   - 「App Home」→「App Display Name」の「Edit」で、投稿役の名前と呼び名を変える。**投稿役の名前にはハイフンなどの記号が使えない**（使えるのはアポストロフィとピリオドだけ）。呼び名は小文字・数字・ピリオド・ハイフン・アンダースコア。App Manifest で名前にハイフンを入れても、投稿役の名前には反映されない。
   - 「Basic Information」→「App icon & Preview」に、同じフォルダの `bot-icon.png`（512×512）を入れる。Claude を思わせる配色で新しく描いた絵で、公式ロゴの写しではない。

## 投稿のしかた

```powershell
# 本文は UTF-8 のファイルで渡す
python slack\post.py --channel C0XXXXXXXXX --name "表示名" --file message.txt

# 返信（スレッド）にするときは、親の投稿の番号を渡す（投稿すると 1 行目に番号が出る）
python slack\post.py --channel C0XXXXXXXXX --name "表示名" --file reply.txt --thread-ts 1790000000.000000

# 送らずに中身を見る
python slack\post.py --channel C0XXXXXXXXX --name "表示名" --file message.txt --dry-run

# 投稿役が出した投稿を消す（試しの投稿の片付けなど）
python slack\post.py --channel C0XXXXXXXXX --delete-ts 1790000000.000000

# 予約投稿（時刻はこの PC の時刻。予約では表示名を変えられず、アプリの名前で出る）
python slack\post.py --channel C0XXXXXXXXX --file reminder.txt --post-at "2026-10-02 18:00"

# 投稿役の予約の一覧と、取り消し
python slack\post.py --channel C0XXXXXXXXX --list-scheduled
python slack\post.py --channel C0XXXXXXXXX --delete-scheduled Q0XXXXXXXXX
```

- 投稿役から出す投稿は、本人に通知が鳴る（本人名義のコネクタの投稿は、本人に通知が鳴らない）。**リマインダーは投稿役から出す**。
- コネクタで本人名義に予約した投稿は、投稿役からは取り消せない。Slack の画面の「予約済み」から本人が取り消す。

- コネクタで読むと、投稿役の投稿は「Message from <表示名> (B…)」のように、送り主が表示名で出る。本人の書き込みと見分けられる。

- **番号の箇条書き「1.」は使わない**。Slack に送ると項目の間の空行が消える。①② や ・ で書く（`post.py` が見つけて注意を出す）。
- 段落の間・項目の間には空行を入れる。
- **太字（`*…*`）の中に「12:57・12:58」のように `:` を2つ以上入れない**。間の `:57・12:` が絵文字の記号（`:名前:`）と読まれて、太字が崩れる（2026-10-01 にコネクタで読み返して確認）。時刻は「12時57分」と書くか、太字の外に出す。

## メンションで動かす（受け口・2026-10-01〜）

Slack で投稿役をメンションすると、そのチャンネルに対応するリポで Claude Code が1回起動し、スレッドに返事を貼る。本体は `listen.py`。

- 公式の Slack 連携（Claude Tag）は Team / Enterprise のプランだけで、個人のプランでは使えない（<https://claude.com/docs/claude-tag/overview>）。だから、この PC で受ける。
- **動かせるのは対応表の `allow_users` に入れた人だけ**（ほかのメンバーがメンションしても動かない）。
- `allow_users` の先頭（または `owner`）が本人。本人以外も足すときは、`user_names` に呼び名、`user_channels` に動かしてよいチャンネルを書く（書いたチャンネルの外では動かない）。本人以外の依頼では、公開・お金・削除・外への送信・設定の変更・本人の判断が要る物を実行せず、返事で「本人に確認します」と伝える（2026-10-02〜）。
- **起動は安全装置つき**（`claude -p --permission-mode auto`＝ふだんの自動モードと同じ安全装置）。確認なし（`--dangerously-skip-permissions`）では起動しない。外から届く書き込みで何でも動かせてしまう作りは、自動モードの安全装置に止められた（2026-10-01）。安全装置が止めた操作は実行されず、返事で「PC で続けて」と伝える。
- 本人名義の LINE などの道具は外して起動する。勤務中（平日 8:00〜16:30）はブラウザの道具も外す（窓を前に出さない）。
- 受けたら 👀、終わったら ✅（失敗は ❌）の目印を付ける。同じリポへの依頼は1つずつ順番に流す。
- **@channel・@here・@everyone の投稿と、投稿役のボットの番号（`<@B…>`）でのメンションでも動く**（2026-10-04〜・本人「@channelでも動くようにして」「他のチャンネルも同様にして」）。動かせる人とチャンネルの決まりは同じ（`allow_users`・`user_channels`）。投稿役を直接メンションした投稿は、@channel が付いていても1回だけ動く。⚠️ Slack 側で、下の手順 5 に `message.channels` と `message.groups` を足しておく必要がある（足さないと、その形の投稿は届かない）。

### 初めて作るとき（本人が Slack の画面で行う・5 分ほど）

1. <https://api.slack.com/apps> で投稿役のアプリを開く。
2. 左の「Socket Mode」を開き、「Enable Socket Mode」を入れる。鍵の名前を聞かれたら `listen` などと付け、権限は `connections:write` のまま「Generate」。出てきた鍵（`xapp-` で始まる）をコピーする。
3. PC で `python slack\listen.py --store-app-token-from-clipboard`（鍵は画面に出さず、資格情報マネージャーの `claude-slack-app` にしまう）。
4. 左の「OAuth & Permissions」の「Bot Token Scopes」に `app_mentions:read` と `reactions:write` を足し、上の「Reinstall to Workspace」を押す。
5. 左の「Event Subscriptions」を開き、「Enable Events」を入れ、「Subscribe to bot events」に `app_mention` を足して「Save Changes」（Socket Mode なので Request URL は要らない）。@channel などでも動かすなら、同じ所に `message.channels`（公開チャンネル）と `message.groups`（非公開チャンネル）も足す（Bot Token Scopes に `channels:history`・`groups:history` が入る）→ 上に出る「reinstall your app」で入れ直す。
6. 対応表 `~/.claude/slack-routes.json` を置く（形は下）。個人の情報なのでこのリポには置かない＝人生管理の非公開リポの PC 控えから戻す。
7. `python slack\listen.py --check` が `RESULT: OK` になったら、`powershell -ExecutionPolicy Bypass -File slack\install-listen.ps1` で、ログオン時に自動で起動するよう登録する。

対応表の形（番号は例）:

```json
{
 "allow_users": ["U0XXXXXXXXX", "U0YYYYYYYYY"],
 "owner": "U0XXXXXXXXX",
 "user_names": {"U0YYYYYYYYY": "呼び名"},
 "user_channels": {"U0YYYYYYYYY": ["C0XXXXXXXXX"]},
 "work_hours": {"days": [0, 1, 2, 3, 4], "start": "08:00", "end": "16:30"},
 "channels": {
  "C0XXXXXXXXX": {"label": "p01-例", "repo": "C:/Users/<you>/Documents/Repositories/<リポ>", "name": "投稿役の表示名"}
 }
}
```

- 対応表は、メンションのたびに読み直す（足しても受け口の再起動は要らない）。
- 試す: `python slack\listen.py --simulate <チャンネル番号> "依頼" --no-run`（起動内容を見るだけ）／`--no-post`（実際に起動し、返事は画面に出すだけ）。
- 記録: `%LOCALAPPDATA%\claude-slack-listen\listen.log`。止める: `schtasks /end /tn claude-slack-listen`。外す: `install-listen.ps1 -Uninstall`。
- PC を作り直したとき: 手順 3・6・7 だけをやり直す（Slack 側の設定は残っている）。

### ワークスペースを分けて使う（2026-10-01〜）

仕事用など、別のワークスペースでも投稿役と受け口を使える。ワークスペースごとに Slack アプリを 1 つ作り、短い名前（英小文字・例 `work`）を決めて、すべての道具に `--workspace <名前>` を付ける。

- 鍵の置き場: `claude-slack-bot-<名前>`（投稿役）・`claude-slack-app-<名前>`（受け口）
- 対応表: `~/.claude/slack-routes-<名前>.json`（形は上と同じ）
- 受け口: `install-listen.ps1 -Workspace <名前>` でタスク `claude-slack-listen-<名前>` を登録（ワークスペースごとに 1 つ動く）
- 投稿: `python slack\post.py --workspace <名前> --channel … --file …`
- アプリは manifest から作ると速い（「Create New App」→「From a manifest」）。権限は `chat:write`・`chat:write.customize`・`app_mentions:read`・`reactions:write`、`socket_mode_enabled: true`、bot event は `app_mention`。

## PC を作り直したとき（戻し方）

鍵は PC の中にしか無いので、新しい PC では**しまい直す**だけです（投稿役そのものは Slack 側に残っています）。

1. <https://api.slack.com/apps> で投稿役を開き、「OAuth & Permissions」の「Bot User OAuth Token」をコピーする。
2. `python slack\post.py --store-token-from-clipboard`
3. `python slack\post.py --check`

チャンネルへの招待は Slack 側に残っているので、やり直しは要りません。

### 無人で投稿役を使うタスク（タスクスケジューラ）

鍵をしまい直したあと、次のタスクを登録し直す。どれも「ログオン中だけ動く」（LogonType=Interactive）形で、資格情報マネージャーの鍵を読む。パスワードは保存しない。

| タスク名 | いつ | 登録し直す方法 |
|---|---|---|
| `game-channel-watch` | 毎週日曜 13:00（2026-10-01〜） | 動画用の非公開リポの作業ツリー（`gh repo list` で探す・ブランチ名は同リポのメモにある）で `powershell -ExecutionPolicy Bypass -File scripts\setup_game_watch_task.ps1` |
| `game-sale-watch` | 毎週 水曜・土曜 18:00（2026-10-07〜） | 同じ作業ツリーで `powershell -ExecutionPolicy Bypass -File scripts\setup_sale_watch_task.ps1` |

- 消すとき: `schtasks /delete /tn game-channel-watch /f`
- `game-channel-watch` の中では Claude（`claude -p`）が調べて本文を返すだけで、Slack に書けるのは `post.py` だけ（Claude には投稿の道具を渡していない）。同じ週に2回は出さない印をリポ側に残す。
- ログは `%LOCALAPPDATA%\game_watch\logs\`（`RESULT:` 行が無いログは失敗）。
- `game-sale-watch` は Claude を使わない（公式ストアの値段を Python で読んで下書きを作り、`post.py` で出すだけ）。消すとき: `schtasks /delete /tn game-sale-watch /f`。ログは `%LOCALAPPDATA%\game_sale_watch\logs\`。

## 困ったとき

| 出た言葉 | 直し方 |
|---|---|
| `not_in_channel` / `channel_not_found` | そのチャンネルで `/invite @投稿役の名前` を打つ |
| `missing_scope` | 手順 2 の権限を足し、同じ画面で「Reinstall to Workspace」を押す（鍵は変わらないことが多いが、変わったらしまい直す） |
| `invalid_auth` / `token_revoked` | 鍵をコピーし直して `--store-token-from-clipboard` をやり直す |
| 鍵が見つからない | 手順 4 をやる。環境変数 `SLACK_BOT_TOKEN` があれば、そちらが優先される |
| アプリの設定画面で保存すると「Hmm, something's gone wrong.」 | Chrome の自動翻訳を切る（アドレスバーの翻訳のマーク →「英語」）。翻訳が入るとイベント名 `app_mention` が日本語に置き換わり、保存が失敗する（2026-10-01 実害）。原文に戻したら「Discard Changes」で捨てて読み直してから、もう一度追加して保存 |
| メンションしても 👀 が付かない | `listen.log` に「受けた」が無ければ Slack 側。「Event Subscriptions」が On で `app_mention` が入っているか、権限を足した後に「Reinstall」したか（`--check` の後で投稿役の権限を確かめる）。2 つのセッション（や窓）で同じ設定画面を同時に触ると、保存が上書きされて消える |

自己テスト（ネットにつながない）: `python slack\post.py --self-test`
