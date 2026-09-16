# Registers the Codex tab-bar status writer as a hidden per-user logon task.
#
# Why a scheduled task and not wezterm.lua: launching the watcher from
# `wezterm.background_child_process` produced a 0xc0000142 (STATUS_DLL_INIT_FAILED)
# modal dialog every 30 seconds on 2026-09-16 — wezterm-gui has no console, so
# `conhost --headless pwsh` cannot initialise underneath it. Task Scheduler does
# provide a usable session, which is the same reason 'Codex Remote Control' uses it.
# wezterm.lua therefore only *reads* the files this writes (troubleshooting #29).
$ErrorActionPreference = 'Stop'

$taskName = 'Codex Tab Bar Status'
$watcherScript = Join-Path $PSScriptRoot 'tabbar-status.ps1'
$pwshExe = Join-Path $PSHOME 'pwsh.exe'
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

if (-not (Test-Path -LiteralPath $watcherScript)) {
    throw "Tab bar status script not found: $watcherScript"
}

# conhost --headless keeps a PseudoConsoleWindow from ever appearing; see the A/B
# measurement recorded in register-remote-control-task.ps1.
$conhostExe = Join-Path $env:SystemRoot 'System32\conhost.exe'
$action = New-ScheduledTaskAction `
    -Execute $conhostExe `
    -Argument "--headless `"$pwshExe`" -NoLogo -NoProfile -WindowStyle Hidden -File `"$watcherScript`""
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
    -Description 'Writes Codex session status files that wezterm.lua renders in the tab bar.' `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -User $currentUser `
    -RunLevel Limited `
    -Force | Out-Null

# The script itself holds a Local\CodexTabBarStatus mutex, so starting a second
# copy is harmless: the duplicate exits immediately.
Start-ScheduledTask -TaskName $taskName
Write-Output "Registered and started scheduled task: $taskName"
