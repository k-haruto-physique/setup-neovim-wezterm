# C: の掃除（2026-11-11）と、変えた設定の戻し方

C: の空きが 8.9GB まで減ったので掃除した（本人「ストレージ容量不足が深刻」「作業ログとかキャッシュほぼいらんよなガッツリ削除しよう」）。空きは 8.9GB → 約 292GB（ページファイルの分は再起動のあとに増える）。

## 何が C: を食っていたか（掃除の前）

| 物 | 量 | どうしたか |
|---|---|---|
| ゲーム（Steam） | 約 160GB | 遊んでいない物を消した（本人の OK） |
| 動画の作業フォルダ・作業中の素材の写し | 約 120GB | 古い版（`v1`〜 の最新以外）だけ消した。撮影の元の動画の多くは、もう外付けの SSD にしか無い（C: の `Videos\<日付>_…` は SSD へのジャンクション）。C: に実物があるのは作業中の物だけ＝残した |
| `%LOCALAPPDATA%\Temp\claude` | 54GB | **Claude Code の裏の作業のログ（`tasks\*.output`）が 1 本 5GB まで膨らむ**。終わったセッションのフォルダと、24 時間書かれていない `.output` を消した |
| ページファイル | 30GB | 自動から 8〜16GB に固定（下） |
| `~/.claude/projects` の会話の記録 | 20GB | 14 日より前の `.jsonl` を消した（memory は残す） |
| NVIDIA app の更新の一時物 | 13GB | `ota-artifacts\*\post-processing` を消した |
| 休止状態のファイル | 6.3GB | 休止状態を切った（下） |
| npm・pip のキャッシュ、アプリのログ | 約 9GB | 消した |

ほかのリポの作業の物（リポの中の古い版）は、それぞれのリポの受信箱に頼んだ（ここでは触らない）。

## 変えた設定と戻し方（管理者の PowerShell）

| 設定 | 今 | 戻す |
|---|---|---|
| 休止状態（高速スタートアップも止まる） | 切った（`powercfg /h off`） | `powercfg /h on` |
| ページファイル | C: に 8192〜16384MB の固定（この起動での最大の使用は 9.2GB だった） | 自動に戻す: `Set-CimInstance -InputObject (Get-CimInstance Win32_ComputerSystem) -Property @{AutomaticManagedPagefile=$true}` → 再起動 |
| 復元ポイントの置き場 | 上限 10GB（`vssadmin resize shadowstorage /for=C: /on=C: /maxsize=10GB`） | 上限を外す: `vssadmin resize shadowstorage /for=C: /on=C: /maxsize=UNBOUNDED`（または 5% などに） |

メモリが足りずに「仮想メモリが不足」と出るようになったら、まずページファイルの上限（16384）を上げる。

## 次にまた C: が減ったら（見る順）

1. `%LOCALAPPDATA%\Temp\claude` … 動いているセッションの ID（`~/.claude/sessions/*.json` の `sessionId`）に無いフォルダと、24 時間書かれていない `tasks\*.output` は消してよい。**動いているセッションのフォルダの丸ごとは消さない**（作業の途中の物がある）。
2. 動画の作業フォルダの `v1`〜 … 最新の `v` 以外。
3. `~/.claude/projects` の古い `.jsonl`（resume できなくなるだけ・memory は別）。
4. npm・pip・uv のキャッシュ（`npm cache clean --force`・`python -m pip cache purge`・`uv cache clean`。uv は MCP サーバーが動いていると鍵を持っていて消せない）。
5. 管理者: `Dism /Online /Cleanup-Image /StartComponentCleanup`、`C:\Windows\SoftwareDistribution\Download`。

🔴 **重なり探しはジャンクションを飛ばす**: Python の `os.walk` や `Get-ChildItem -Recurse` はジャンクションの先までたどる。C: の `Videos\<日付>_…` は SSD へのジャンクションなので、たどると「C: と SSD に同じ物がある」と見えて、それを消すと **SSD の原本を消す**（2026-11-11 に一覧がこれを含み、流す前に気づいて止めた）。大きさを測る・重なりを探す時は reparse point を飛ばし、消すのは本物のフォルダだけにする。素材を C: から外すのは YouTube 側の決まった道具（MD5 で照合 → 消す → ジャンクションに張り直す）に任せる。

Claude Code の自動の許可（auto mode）は、戻せない削除とほかのセッションを止めるのを止める。消す物はスクリプトに書き出し、本人が `!` で流す（管理者の物は `! pwsh -NoProfile -Command "Start-Process pwsh -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-NoExit','-File','<スクリプト>'"`。`!` は bash で動くので pwsh で包む）。
