# Slack のメンション受け口（listen.py）を、ログオン時に自動で起動するよう登録する（2026-10-01）。
# 窓は出さない（pythonw）。ログオン中だけ動く（LogonType=Interactive＝資格情報マネージャーの鍵が読める）。
# 先にアプリの鍵と対応表を用意してから流す（README.md「メンションで動かす」）。
#   登録して起動: powershell -ExecutionPolicy Bypass -File slack\install-listen.ps1
#   外す        : powershell -ExecutionPolicy Bypass -File slack\install-listen.ps1 -Uninstall
param([switch]$Uninstall)
$ErrorActionPreference = 'Stop'
$name = 'claude-slack-listen'
if ($Uninstall) {
    Stop-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $name -Confirm:$false
    'RESULT: OK — 登録を外した'
    exit 0
}
$py = (& python -c "import sys;print(sys.executable)").Trim()
$pyw = Join-Path (Split-Path $py) 'pythonw.exe'
if (-not (Test-Path $pyw)) { throw "pythonw.exe が見つからない: $pyw" }
$script = Join-Path $PSScriptRoot 'listen.py'
& python $script --check
if ($LASTEXITCODE -ne 0) { throw 'listen.py --check が通らない＝鍵か対応表が足りない（README.md「メンションで動かす」）' }
$action = New-ScheduledTaskAction -Execute $pyw -Argument "`"$script`"" -WorkingDirectory $PSScriptRoot
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable `
    -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName $name -Action $action -Trigger $trigger -Settings $settings -Principal $principal `
    -Description 'Slack のメンションで Claude Code を起動する受け口（setup-neovim-wezterm/slack/listen.py）' -Force | Out-Null
Start-ScheduledTask -TaskName $name
'RESULT: OK — 登録して起動した（記録: %LOCALAPPDATA%\claude-slack-listen\listen.log）'
