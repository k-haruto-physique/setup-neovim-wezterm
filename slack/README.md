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

- 消すとき: `schtasks /delete /tn game-channel-watch /f`
- `game-channel-watch` の中では Claude（`claude -p`）が調べて本文を返すだけで、Slack に書けるのは `post.py` だけ（Claude には投稿の道具を渡していない）。同じ週に2回は出さない印をリポ側に残す。
- ログは `%LOCALAPPDATA%\game_watch\logs\`（`RESULT:` 行が無いログは失敗）。

## 困ったとき

| 出た言葉 | 直し方 |
|---|---|
| `not_in_channel` / `channel_not_found` | そのチャンネルで `/invite @投稿役の名前` を打つ |
| `missing_scope` | 手順 2 の権限を足し、同じ画面で「Reinstall to Workspace」を押す（鍵は変わらないことが多いが、変わったらしまい直す） |
| `invalid_auth` / `token_revoked` | 鍵をコピーし直して `--store-token-from-clipboard` をやり直す |
| 鍵が見つからない | 手順 4 をやる。環境変数 `SLACK_BOT_TOKEN` があれば、そちらが優先される |

自己テスト（ネットにつながない）: `python slack\post.py --self-test`
