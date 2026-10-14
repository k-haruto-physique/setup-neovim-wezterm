# session-snapshot.ps1 を、画面の出ないユーザーのログオンタスク「Claude Session Snapshot」として登録して起動する。
# 2026-10-14・troubleshooting #32。管理者は要らない。登録し直しても安全（-Force・道具の側で 1 つだけ動く）。
#
# 止める・外す:
#   Stop-ScheduledTask -TaskName 'Claude Session Snapshot'
#   Unregister-ScheduledTask -TaskName 'Claude Session Snapshot' -Confirm:$false
# 外しても cc／cn は動く（cc は控えが無いフォルダでは claude --continue になる）。restore だけが使えなくなる。
#
# wezterm.lua から起動しない理由は Codex/register-tabbar-status-task.ps1 と同じ（0xc0000142・troubleshooting #29）。
# conhost --headless で、PowerShell の窓が一瞬も出ないようにする（Codex/register-remote-control-task.ps1 の実測）。
$ErrorActionPreference = 'Stop'

$taskName = 'Claude Session Snapshot'
$script = Join-Path $PSScriptRoot 'session-snapshot.ps1'
$pwshExe = Join-Path $PSHOME 'pwsh.exe'
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

if (-not (Test-Path -LiteralPath $script)) { throw "見つかりません: $script" }
if (-not (Test-Path -LiteralPath $pwshExe)) { throw "pwsh 7 から実行してください（$pwshExe がありません）" }

$conhostExe = Join-Path $env:SystemRoot 'System32\conhost.exe'
$action = New-ScheduledTaskAction `
    -Execute $conhostExe `
    -Argument "--headless `"$pwshExe`" -NoLogo -NoProfile -WindowStyle Hidden -File `"$script`""
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $currentUser
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -ExecutionTimeLimit (New-TimeSpan -Days 3650)

Register-ScheduledTask `
    -TaskName $taskName `
    -Description 'Records open Claude Code sessions every 2 minutes so restore can reopen them after a restart.' `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -User $currentUser `
    -RunLevel Limited `
    -Force | Out-Null

# 古い版がまだ動いていれば止めてから起動する。Stop-ScheduledTask は conhost だけを止め、中の pwsh は残る
# （2026-10-14 実測）。残った古い版が印（Mutex）を持ったままだと、新しい版はすぐ終わり、古い版が書き続ける。
Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
Get-CimInstance Win32_Process -Filter "Name='pwsh.exe'" |
    Where-Object { $_.CommandLine -and $_.CommandLine.Contains($script) } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-ScheduledTask -TaskName $taskName
Write-Output "登録して起動しました: $taskName（登録し直した時は、古い版を止めてから）"
