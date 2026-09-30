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

## 投稿のしかた

```powershell
# 本文は UTF-8 のファイルで渡す
python slack\post.py --channel C0XXXXXXXXX --name "表示名" --file message.txt

# 返信（スレッド）にするときは、親の投稿の番号を渡す（投稿すると 1 行目に番号が出る）
python slack\post.py --channel C0XXXXXXXXX --name "表示名" --file reply.txt --thread-ts 1790000000.000000

# 送らずに中身を見る
python slack\post.py --channel C0XXXXXXXXX --name "表示名" --file message.txt --dry-run
```

- **番号の箇条書き「1.」は使わない**。Slack に送ると項目の間の空行が消える。①② や ・ で書く（`post.py` が見つけて注意を出す）。
- 段落の間・項目の間には空行を入れる。

## PC を作り直したとき（戻し方）

鍵は PC の中にしか無いので、新しい PC では**しまい直す**だけです（投稿役そのものは Slack 側に残っています）。

1. <https://api.slack.com/apps> で投稿役を開き、「OAuth & Permissions」の「Bot User OAuth Token」をコピーする。
2. `python slack\post.py --store-token-from-clipboard`
3. `python slack\post.py --check`

チャンネルへの招待は Slack 側に残っているので、やり直しは要りません。

## 困ったとき

| 出た言葉 | 直し方 |
|---|---|
| `not_in_channel` / `channel_not_found` | そのチャンネルで `/invite @投稿役の名前` を打つ |
| `missing_scope` | 手順 2 の権限を足し、同じ画面で「Reinstall to Workspace」を押す（鍵は変わらないことが多いが、変わったらしまい直す） |
| `invalid_auth` / `token_revoked` | 鍵をコピーし直して `--store-token-from-clipboard` をやり直す |
| 鍵が見つからない | 手順 4 をやる。環境変数 `SLACK_BOT_TOKEN` があれば、そちらが優先される |

自己テスト（ネットにつながない）: `python slack\post.py --self-test`
