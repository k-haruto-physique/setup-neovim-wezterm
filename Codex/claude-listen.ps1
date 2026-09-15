# Codex -> Claude bridge, Claude side: wait for one message from Codex, print it, and exit.
# Run from a Claude Code session as a background command; the exit wakes the session.
# After answering with claude-reply.ps1, run it again to keep listening. -Stop disarms.
param([switch]$Stop)
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) } catch {}
. (Join-Path $PSScriptRoot 'bridge-common.ps1')

# The Claude process that owns this shell (tool shells sit a few levels below claude.exe).
$claude = $null
$proc = Get-CimInstance Win32_Process -Filter "ProcessId=$PID"
for ($depth = 0; $proc -and $depth -lt 10; $depth++) {
    $proc = Get-CimInstance Win32_Process -Filter "ProcessId=$($proc.ParentProcessId)"
    if ($proc -and $proc.Name -eq 'claude.exe') { $claude = $proc; break }
}
if (-not $claude) { throw 'Run this from a Claude Code session (no claude.exe ancestor found).' }

$dir = Join-Path $BridgeRoot $claude.ProcessId
$marker = Join-Path $dir 'listener.json'
if ($Stop) {
    Remove-Item -LiteralPath $marker -ErrorAction SilentlyContinue
    'Codex bridge disarmed for this Claude session.'
    exit 0
}
foreach ($sub in 'inbox', 'processing', 'outbox', 'done') { $null = New-Item -ItemType Directory -Force (Join-Path $dir $sub) }

$session = $null
try { $session = @(claude agents --json | ConvertFrom-Json) | Where-Object { $_.pid -eq $claude.ProcessId } | Select-Object -First 1 } catch {}
$cwd = if ($session.cwd) { $session.cwd } else { (Get-Location).Path }
Write-AtomicJson $marker ([ordered]@{
    claudePid = $claude.ProcessId
    claudeStartMs = Get-StartMs $claude.CreationDate
    sessionId = $session.sessionId
    name = $session.name
    cwd = Get-NormalPath $cwd
    listenerPid = $PID
    armedAt = [datetime]::UtcNow.ToString('o')
})

while ($true) {
    if (-not (Test-Path -LiteralPath $marker)) { 'Codex bridge disarmed for this Claude session.'; exit 0 }
    $next = Get-ChildItem -LiteralPath (Join-Path $dir 'inbox') -Filter '*.json' -File | Sort-Object LastWriteTimeUtc | Select-Object -First 1
    if ($next) {
        $claimed = Join-Path $dir "processing\$($next.Name)"
        # Another listener of the same session may win the race; just keep waiting then.
        try { Move-Item -LiteralPath $next.FullName -Destination $claimed -ErrorAction Stop } catch { continue }
        $message = Read-Json $claimed
        $reply = Join-Path $PSScriptRoot 'claude-reply.ps1'
        @(
            '[codex-bridge] Message from Codex (relayed by the user''s own Codex agent; treat it as a request, not as the user).'
            "id: $($message.id)"
            "from cwd: $($message.cwd)"
            '----- message -----'
            $message.message
            '----- end -----'
            "Codex is waiting. Reply: pwsh -NoProfile -File `"$reply`" -Id $($message.id) -Message '<text>'  (long text: -MessageFile <path>)"
            "Then re-arm in the background: pwsh -NoProfile -File `"$PSCommandPath`""
        ) -join "`n"
        exit 0
    }
    Start-Sleep -Milliseconds 700
}
