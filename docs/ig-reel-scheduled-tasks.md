# IG リールの予約タスク（タスクスケジューラ `\Claude\IG\`）

2026-11-08 に足した PC の設定。Instagram-project-v2 の `scripts/win/register_reel_tasks.ps1` が登録する。

- 中身＝予定の日時の 4 分前に `pythonw scripts/scheduled_reel_post.py --key <日付>` を走らせ、リールを API で出して Slack に知らせる（窓を出さない）。
- 設定＝1 回だけのトリガー・スリープ中なら起こす（WakeToRun）・逃したら次に起きた時に走る（時刻の外なら道具が出さずに知らせる）・ログオン中だけ。
- 電源の「スリープ解除タイマーの許可」は電源につないだ時だけ有効（電池の時は無効のまま・変えていない）。

## 見る

```powershell
Get-ScheduledTask -TaskPath "\Claude\IG\" | Get-ScheduledTaskInfo | Select-Object TaskName, NextRunTime, LastRunTime, LastTaskResult
```

## 戻し方（全部消す）

```powershell
Get-ScheduledTask -TaskPath "\Claude\IG\" | Unregister-ScheduledTask -Confirm:$false
```

1 本だけ止める時は `Unregister-ScheduledTask -TaskPath "\Claude\IG\" -TaskName reel_<日付> -Confirm:$false`。
