# Codex -> Claude bridge, Codex side: hand one message to a listening Claude Code session
# and print Claude's reply. The Claude session must be running claude-listen.ps1 (armed).
[CmdletBinding(DefaultParameterSetName = 'Text')]
param(
    [Parameter(ParameterSetName = 'Text', Mandatory, Position = 0)][string]$Message,
    [Parameter(ParameterSetName = 'File', Mandatory)][string]$MessageFile,
    [int]$ClaudePid,
    [string]$Name,
    [string]$Cwd = (Get-Location).Path,
    [ValidatePattern('^[0-9a-f]{8}$')][string]$Conversation,
    [int]$TimeoutSec = 1800
)
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) } catch {}
. (Join-Path $PSScriptRoot 'bridge-common.ps1')
if ($MessageFile) { $Message = Get-Content -LiteralPath $MessageFile -Raw -Encoding utf8 }
if ([string]::IsNullOrWhiteSpace($Message)) { throw 'Message is empty.' }

# Armed listeners whose Claude process is still the same one (PIDs get reused).
$armed = foreach ($marker in Get-ChildItem -LiteralPath $BridgeRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object { Join-Path $_.FullName 'listener.json' }) {
    if (-not (Test-Path -LiteralPath $marker)) { continue }
    $listener = Read-Json $marker
    $process = Get-Process -Id $listener.claudePid -ErrorAction SilentlyContinue
    # Claude Code's auto-update renames a running exe to claude.exe.old.<n>; the start time still guards PID reuse.
    if (-not $process -or $process.ProcessName -notmatch '^claude(\.exe\.old\.\d+)?$' -or [Math]::Abs((Get-StartMs $process.StartTime) - $listener.claudeStartMs) -gt 2000) { continue }
    $listener | Add-Member -NotePropertyName dir -NotePropertyValue (Split-Path $marker) -PassThru
}
$armed = @($armed)
$targets = if ($ClaudePid) { @($armed | Where-Object claudePid -eq $ClaudePid) }
    elseif ($Name) { @($armed | Where-Object name -eq $Name) }
    else { $want = Get-NormalPath $Cwd; @($armed | Where-Object { $_.cwd -ieq $want }) }
if (-not $targets.Count) {
    $known = if ($armed.Count) { ($armed | ForEach-Object { "$($_.name) (pid $($_.claudePid), $($_.cwd))" }) -join '; ' } else { 'none' }
    [Console]::Error.WriteLine("ask-claude: no listening Claude session matches. Listening sessions: $known. Ask the user to tell that Claude session to arm Codex/claude-listen.ps1, or pass -ClaudePid / -Name.")
    exit 1
}
try {
    $target = Select-BridgeTarget $targets 'listening Claude sessions' { param($l) "$($l.name) (pid $($l.claudePid), $($l.cwd))" } 'Pass -ClaudePid, or -Name if that name is unique.'
} catch {
    [Console]::Error.WriteLine("ask-claude: not sent, $($_.Exception.Message -replace '^BRIDGE_AMBIGUOUS: ', '')")
    exit 6
}

$turnInfo = Register-BridgeTurn $Conversation 'codex'
if ($turnInfo.Refused) { [Console]::Error.WriteLine("ask-claude: refused, $($turnInfo.Refused)"); exit 4 }

$id = [guid]::NewGuid().ToString('N')
$inbox = Join-Path $target.dir "inbox\$id.json"
Write-AtomicJson $inbox ([ordered]@{
    id = $id; from = 'codex'; cwd = Get-NormalPath $Cwd; createdAt = [datetime]::UtcNow.ToString('o')
    conversation = $turnInfo.Id; turn = $turnInfo.Turn; maxTurns = $turnInfo.Max; message = $Message
})
[Console]::Error.WriteLine("-> Claude session $($target.name) (pid $($target.claudePid)) cwd=$($target.cwd) id=$id")
[Console]::Error.WriteLine("   conversation=$($turnInfo.Id) turn $($turnInfo.Turn)/$($turnInfo.Max) (continue it with -Conversation $($turnInfo.Id))")
if (-not (Get-Process -Id $target.listenerPid -ErrorAction SilentlyContinue)) {
    [Console]::Error.WriteLine('  claude> listener is between messages; this one waits in the inbox until Claude re-arms.')
}

$outbox = Join-Path $target.dir "outbox\$id.json"
$deadline = [datetime]::UtcNow.AddSeconds($TimeoutSec)
while (-not (Test-Path -LiteralPath $outbox)) {
    if ([datetime]::UtcNow -ge $deadline) {
        if (Test-Path -LiteralPath $inbox) {
            Remove-Item -LiteralPath $inbox -Force
            [Console]::Error.WriteLine("Timed out after $TimeoutSec s; Claude never picked the message up, so it was withdrawn.")
        } else {
            [Console]::Error.WriteLine("Timed out after $TimeoutSec s; Claude is still working on it. The reply will appear in $outbox.")
        }
        exit 3
    }
    Start-Sleep -Milliseconds 700
}
$answer = Read-Json $outbox
Move-Item -LiteralPath $outbox -Destination (Join-Path $target.dir "done\$id.reply.json") -Force
Write-Output $answer.reply
exit 0
