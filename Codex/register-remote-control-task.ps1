# Registers Codex Remote Control as a hidden per-user logon task.
$ErrorActionPreference = 'Stop'

$taskName = 'Codex Remote Control'
$remoteControlScript = Join-Path $PSScriptRoot 'remote-control.ps1'
$pwshExe = Join-Path $PSHOME 'pwsh.exe'
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

if (-not (Test-Path -LiteralPath $remoteControlScript)) {
    throw "Remote Control script not found: $remoteControlScript"
}

$action = New-ScheduledTaskAction `
    -Execute $pwshExe `
    -Argument "-NoLogo -NoProfile -WindowStyle Hidden -File `"$remoteControlScript`""
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
