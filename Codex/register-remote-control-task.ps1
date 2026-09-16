# Registers Codex Remote Control as a hidden per-user logon task.
$ErrorActionPreference = 'Stop'

$taskName = 'Codex Remote Control'
$remoteControlScript = Join-Path $PSScriptRoot 'remote-control.ps1'
$pwshExe = Join-Path $PSHOME 'pwsh.exe'
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

if (-not (Test-Path -LiteralPath $remoteControlScript)) {
    throw "Remote Control script not found: $remoteControlScript"
}

# 2026-09-16: wrap in `conhost --headless` so no console window is ever created.
# `-WindowStyle Hidden` does NOT prevent the window: it creates one and hides it after
# PowerShell finishes initializing, so a PseudoConsoleWindow stays visible for a moment
# on every logon. Measured A/B on this machine (EnumWindows polled every 25ms):
#   A `pwsh.exe -WindowStyle Hidden`              -> PseudoConsoleWindow visible, ran OK
#   B `conhost.exe --headless pwsh.exe ...`       -> no window at all, ran OK
# Keep `-WindowStyle Hidden` as well (belt and braces); keep LogonType Interactive
# because the app-server is expected to live in the user's interactive session.
$conhostExe = Join-Path $env:SystemRoot 'System32\conhost.exe'
$action = New-ScheduledTaskAction `
    -Execute $conhostExe `
    -Argument "--headless `"$pwshExe`" -NoLogo -NoProfile -WindowStyle Hidden -File `"$remoteControlScript`""
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $currentUser
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -ExecutionTimeLimit (New-TimeSpan -Days 3650)

$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existingTask -and $existingTask.State -eq 'Running') {
    Write-Output "Scheduled task is already running: $taskName"
    exit 0
}

Register-ScheduledTask `
    -TaskName $taskName `
    -Description 'Starts the local Codex app-server with Remote Control enabled.' `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -User $currentUser `
    -RunLevel Limited `
    -Force | Out-Null

Start-ScheduledTask -TaskName $taskName
Write-Output "Registered and started scheduled task: $taskName"
