# Lifecycle hook: exact session -> owning terminal pane, never cwd inference.
[CmdletBinding()]
param([Nullable[int]]$RepairPaneId, [Nullable[int]]$OwnerProcessId)
$ErrorActionPreference = 'Stop'
$registry = Join-Path $env:USERPROFILE '.codex/status-panes'
if ($null -ne $RepairPaneId) {
    if ($null -eq $OwnerProcessId) { exit 0 }
    $env:WEZTERM_PANE = "$RepairPaneId"
    $savedPath = Join-Path $registry "$OwnerProcessId-$RepairPaneId.json"
    if (-not (Test-Path -LiteralPath $savedPath)) { exit 0 }
    $saved = Get-Content -LiteralPath $savedPath -Raw | ConvertFrom-Json
    if ($saved.ended) { exit 0 }
    $event = [pscustomobject]@{ session_id = $saved.sessionId; transcript_path = $saved.transcriptPath; cwd = $saved.cwd; model = $saved.model; hook_event_name = 'SessionStart' }
    $ownerProcess = Get-CimInstance Win32_Process -Filter "ProcessId = $OwnerProcessId"
    if (-not $ownerProcess -or (([datetime]$saved.ownerStartedAt) - $ownerProcess.CreationDate.ToUniversalTime()).Duration().TotalMilliseconds -gt 2) { exit 0 }
} else {
    $reader = [IO.StreamReader]::new([Console]::OpenStandardInput(), [Text.Encoding]::UTF8)
    $event = $reader.ReadToEnd() | ConvertFrom-Json
    $reader.Dispose()
    $ancestor = Get-CimInstance Win32_Process -Filter "ProcessId = $PID"
    $ownerProcess = $null
    for ($depth = 0; $depth -lt 12 -and $ancestor; $depth++) {
        $ancestor = Get-CimInstance Win32_Process -Filter "ProcessId = $($ancestor.ParentProcessId)"
        if ($ancestor.Name -eq 'codex.exe') { $ownerProcess = $ancestor; break }
    }
}
if ($env:WEZTERM_PANE -notmatch '^\d+$' -or $event.session_id -notmatch '^[a-fA-F0-9-]{29,36}$' -or -not $ownerProcess) { exit 0 }
$ownerPane = [int]$env:WEZTERM_PANE
$bindingPath = Join-Path $registry "$($ownerProcess.ProcessId)-$ownerPane.json"
$mutex = [Threading.Mutex]::new($false, "Local\CodexStatus-$($ownerProcess.ProcessId)-$ownerPane")
$locked = $false
try {
    $locked = $mutex.WaitOne(1500)
    if (-not $locked) { throw 'Status pane binding is busy' }
    $old = if (Test-Path -LiteralPath $bindingPath) { Get-Content -LiteralPath $bindingPath -Raw | ConvertFrom-Json } else { $null }
    if ($event.hook_event_name -eq 'SessionEnd') {
        if ($old -and $old.sessionId -eq $event.session_id) {
            $old.ended = $true
            $temp = "$bindingPath.$PID.tmp"
            [IO.File]::WriteAllText($temp, ($old | ConvertTo-Json -Depth 5))
            [IO.File]::Move($temp, $bindingPath, $true)
        }
        exit 0
    }
    New-Item -ItemType Directory -Path $registry -Force | Out-Null
    $panes = @(& wezterm cli list --format json | ConvertFrom-Json)
    if ($LASTEXITCODE -ne 0) { throw 'Could not list WezTerm panes' }
    if (-not ($panes | Where-Object pane_id -eq $ownerPane)) { exit 0 }
    $statusPane = ($panes | Where-Object title -eq "Codex status:$($ownerProcess.ProcessId):$ownerPane" | Select-Object -First 1).pane_id
    $binding = [ordered]@{
        sessionId = $event.session_id; transcriptPath = $event.transcript_path
        cwd = $event.cwd; model = $event.model
        ownerPaneId = $ownerPane; ownerPid = $ownerProcess.ProcessId
        ownerStartedAt = $ownerProcess.CreationDate.ToUniversalTime().ToString('o')
        statusPaneId = $statusPane; ended = $false
    }
    $temp = "$bindingPath.$PID.tmp"
    [IO.File]::WriteAllText($temp, ($binding | ConvertTo-Json -Depth 5))
    [IO.File]::Move($temp, $bindingPath, $true)
    if ($null -eq $statusPane) {
        $statusPane = & wezterm cli split-pane --pane-id $ownerPane --bottom --cells 5 --cwd $event.cwd -- pwsh.exe -NoLogo -NoProfile -File (Join-Path $PSScriptRoot 'statusline.ps1') -Watch -BindingPath $bindingPath
        if ($LASTEXITCODE -ne 0 -or "$statusPane" -notmatch '^\d+$') { throw 'Could not create status pane' }
        # Do not activate a remote or inactive session.
    }
} catch {
    New-Item -ItemType Directory -Path $registry -Force | Out-Null
    Add-Content -LiteralPath (Join-Path $registry 'errors.log') -Value "$(Get-Date -Format o) pane=$ownerPane $($_.Exception.Message)"
} finally {
    if ($locked) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
