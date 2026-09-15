# Shared helpers for the Claude <-> Codex bridge (ask-codex / ask-claude / claude-listen / claude-reply).
# One folder per Claude process: listener.json marks it armed; inbox -> processing -> done, replies in outbox.
# Under Temp on purpose: Codex's Windows sandbox (CodexSandboxUsers) may only write there and in its workspace.
# Directly under LOCALAPPDATA it gets "Access denied" with sandbox_mode = "workspace-write".
$BridgeRoot = if ($env:CODEX_CLAUDE_BRIDGE_ROOT) { $env:CODEX_CLAUDE_BRIDGE_ROOT } else { Join-Path $env:LOCALAPPDATA 'Temp\codex-claude-bridge' }
# Runaway guards: exchanges per conversation, and asks across all conversations per window.
$BridgeMaxTurns = 10
$BridgeRateLimit = 20
$BridgeRateWindowMinutes = 30

function Get-NormalPath([string]$Path) { [IO.Path]::GetFullPath($Path).TrimEnd('\', '/') }

# Writers rename a finished temp file so readers never see half a message.
function Write-AtomicJson([string]$Path, $Object) {
    $temp = "$Path.tmp"
    [IO.File]::WriteAllText($temp, ($Object | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temp -Destination $Path -Force
}

function Read-Json([string]$Path) { Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json }

function Get-StartMs($StartTime) { [DateTimeOffset]::new($StartTime).ToUnixTimeMilliseconds() }

# Pick exactly one target or refuse: guessing between sessions can hand context to the wrong one (backlog B14).
# Returns $null for no candidates; throws "BRIDGE_AMBIGUOUS: ..." (callers exit 6) for more than one.
function Select-BridgeTarget($Candidates, [string]$What, [scriptblock]$Describe, [string]$Hint) {
    $list = @($Candidates)
    if ($list.Count -eq 0) { return $null }
    if ($list.Count -eq 1) { return $list[0] }
    $described = ($list | ForEach-Object { & $Describe $_ }) -join '; '
    throw "BRIDGE_AMBIGUOUS: $($list.Count) $What match: $described. $Hint"
}

# Count one exchange before sending. Returns Id/Turn/Max, or Refused with the reason (callers exit 4).
function Register-BridgeTurn([string]$Conversation, [string]$From) {
    if (-not $Conversation) { $Conversation = [guid]::NewGuid().ToString('N').Substring(0, 8) }
    $null = New-Item -ItemType Directory -Force (Join-Path $BridgeRoot 'conversations')
    # Both sides may ask at once; an exclusive open of the lock file serializes the counter update.
    $lockPath = Join-Path $BridgeRoot 'turns.lock'
    $lock = $null
    for ($try = 0; -not $lock; $try++) {
        try { $lock = [IO.File]::Open($lockPath, 'OpenOrCreate', 'ReadWrite', 'None') }
        catch { if ($try -ge 50) { throw 'Bridge turn counter stayed locked for 5 s.' }; Start-Sleep -Milliseconds 100 }
    }
    try {
        $nowMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        $logPath = Join-Path $BridgeRoot 'asks.log'
        $recent = @(if (Test-Path -LiteralPath $logPath) {
            Get-Content -LiteralPath $logPath | Where-Object { $_ -match '^\d+ ' -and [long]($_ -split ' ')[0] -gt $nowMs - $BridgeRateWindowMinutes * 60000 }
        })
        $convPath = Join-Path $BridgeRoot "conversations\$Conversation.json"
        $turns = if (Test-Path -LiteralPath $convPath) { [int](Read-Json $convPath).turns } else { 0 }
        $result = [ordered]@{ Id = $Conversation; Turn = $turns + 1; Max = $BridgeMaxTurns; Refused = $null }
        if ($turns -ge $BridgeMaxTurns) {
            $result.Refused = "conversation $Conversation already used $BridgeMaxTurns exchanges; stop and report to the user"
        } elseif ($recent.Count -ge $BridgeRateLimit) {
            $result.Refused = "$($recent.Count) asks in the last $BridgeRateWindowMinutes minutes (limit $BridgeRateLimit); stop and report to the user"
        } else {
            Write-AtomicJson $convPath ([ordered]@{ id = $Conversation; turns = $turns + 1; lastFrom = $From; lastAtMs = $nowMs })
            Set-Content -LiteralPath $logPath -Value (@($recent) + "$nowMs $Conversation $From") -Encoding utf8
        }
        [pscustomobject]$result
    } finally { $lock.Dispose() }
}
