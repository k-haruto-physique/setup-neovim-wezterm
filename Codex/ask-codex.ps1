# Claude -> Codex bridge: send one message to a live Codex thread on the shared app-server
# and print Codex's final reply. The CLI shows the turn exactly like input from the phone
# (same server, same thread), so the conversation never forks.
[CmdletBinding(DefaultParameterSetName = 'Text')]
param(
    [Parameter(ParameterSetName = 'Text', Mandatory, Position = 0)][string]$Message,
    [Parameter(ParameterSetName = 'File', Mandatory)][string]$MessageFile,
    [string]$ThreadId,
    [string]$Cwd = (Get-Location).Path,
    [switch]$New,
    [int]$TimeoutSec = 1800
)
$ErrorActionPreference = 'Stop'
# Hook-style callers read stdout as UTF-8; the console code page (CP932) would garble Japanese (troubleshooting #24).
try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) } catch {}
if ($MessageFile) { $Message = Get-Content -LiteralPath $MessageFile -Raw -Encoding utf8 }
if ([string]::IsNullOrWhiteSpace($Message)) { throw 'Message is empty.' }

$socket = [Net.WebSockets.ClientWebSocket]::new()
$deadline = [Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds($TimeoutSec))
$script:nextId = 0
$script:pending = [Collections.Generic.Queue[object]]::new()

function Write-Note([string]$Text) {
    $line = ($Text -replace '\s+', ' ').Trim()
    if ($line.Length -gt 160) { $line = $line.Substring(0, 157) + '...' }
    [Console]::Error.WriteLine("  codex> $line")
}
function Send-Json($Payload) {
    $bytes = [Text.Encoding]::UTF8.GetBytes(($Payload | ConvertTo-Json -Depth 10 -Compress))
    $null = $socket.SendAsync([ArraySegment[byte]]::new($bytes), [Net.WebSockets.WebSocketMessageType]::Text, $true, $deadline.Token).GetAwaiter().GetResult()
}
function Receive-Json {
    $buffer = [byte[]]::new(65536)
    while ($true) {
        $stream = [IO.MemoryStream]::new()
        try {
            do {
                $received = $socket.ReceiveAsync([ArraySegment[byte]]::new($buffer), $deadline.Token).GetAwaiter().GetResult()
                if ($received.MessageType -eq [Net.WebSockets.WebSocketMessageType]::Close) { throw 'Codex server closed the connection' }
                $stream.Write($buffer, 0, $received.Count)
            } until ($received.EndOfMessage)
            $text = [Text.Encoding]::UTF8.GetString($stream.ToArray())
        } finally { $stream.Dispose() }
        try { return $text | ConvertFrom-Json } catch { continue }
    }
}
function Invoke-Rpc([string]$Method, $Params) {
    $id = ++$script:nextId
    Send-Json @{ id = $id; method = $Method; params = $Params }
    while ($true) {
        $msg = Receive-Json
        if (-not $msg.PSObject.Properties['method'] -and $msg.id -eq $id) {
            if ($msg.PSObject.Properties['error'] -and $msg.error) { throw "$Method failed: $($msg.error.message)" }
            return $msg.result
        }
        # Notifications that arrive while waiting still matter (the turn may finish fast).
        $script:pending.Enqueue($msg)
    }
}
function Get-NextMessage { if ($script:pending.Count) { $script:pending.Dequeue() } else { Receive-Json } }
function Get-NormalPath([string]$Path) { [IO.Path]::GetFullPath($Path).TrimEnd('\', '/') }

$threadIdInUse = $null
$exitCode = 0
try {
    try {
        $null = $socket.ConnectAsync([uri]'ws://127.0.0.1:14567', $deadline.Token).GetAwaiter().GetResult()
    } catch {
        throw 'Codex shared server (ws://127.0.0.1:14567) is not reachable. Start the scheduled task "Codex Remote Control" (troubleshooting #17).'
    }
    $null = Invoke-Rpc 'initialize' @{ clientInfo = @{ name = 'claude_code_bridge'; version = '1' }; capabilities = @{ experimentalApi = $true } }
    Send-Json @{ method = 'initialized' }

    if ($New) {
        $thread = (Invoke-Rpc 'thread/start' @{ cwd = (Get-NormalPath $Cwd) }).thread
    } else {
        if (-not $ThreadId) {
            # Only threads a live client has loaded; the newest one in this cwd is the CLI the user is looking at.
            $want = Get-NormalPath $Cwd
            $candidates = foreach ($id in @((Invoke-Rpc 'thread/loaded/list' @{}).data)) {
                $t = (Invoke-Rpc 'thread/read' @{ threadId = $id; includeTurns = $false }).thread
                if ($t.ephemeral -or $t.parentThreadId) { continue }
                if ((Get-NormalPath $t.cwd) -ieq $want) { $t }
            }
            $candidates = @($candidates | Sort-Object { [long]$_.updatedAt } -Descending)
            if (-not $candidates.Count) { throw "No live Codex thread in $want. Start 'codex' there, pass -ThreadId, or use -New." }
            if ($candidates.Count -gt 1) { Write-Note "$($candidates.Count) live threads in this cwd; using the newest (others: $(($candidates | Select-Object -Skip 1 | ForEach-Object id) -join ', '))" }
            $ThreadId = $candidates[0].id
        }
        # For a running thread, resume rejoins it (subscribes this connection) without reloading.
        $thread = (Invoke-Rpc 'thread/resume' @{ threadId = $ThreadId; excludeTurns = $true }).thread
    }
    $threadIdInUse = $thread.id
    $label = if ($thread.name) { $thread.name } else { "$($thread.preview)" }
    if ($label.Length -gt 40) { $label = $label.Substring(0, 40) + '...' }
    [Console]::Error.WriteLine("-> Codex thread $($thread.id) [$label] cwd=$($thread.cwd)")
    if ($thread.status.type -ne 'idle') { throw "Codex thread is $($thread.status.type); wait until its current turn finishes." }

    $turnId = (Invoke-Rpc 'turn/start' @{ threadId = $thread.id; input = @(@{ type = 'text'; text = $Message }) }).turn.id
    $reply = $null
    $turn = $null
    while (-not $turn) {
        $msg = Get-NextMessage
        if (-not $msg.PSObject.Properties['method']) { continue }
        if ($msg.PSObject.Properties['id']) { Write-Note "server request $($msg.method) (left to the attached CLI)"; continue }
        if ($msg.method -eq 'item/completed' -and $msg.params.turnId -eq $turnId) {
            $item = $msg.params.item
            switch ($item.type) {
                'agentMessage' { if ($reply) { Write-Note $reply }; $reply = $item.text }
                'commandExecution' { Write-Note "`$ $($item.command)" }
                'fileChange' { Write-Note "edit $(@($item.changes | ForEach-Object path) -join ', ')" }
            }
        } elseif ($msg.method -eq 'turn/completed' -and $msg.params.turn.id -eq $turnId) {
            $turn = $msg.params.turn
        }
    }
    if ($reply) { Write-Output $reply } else { Write-Note '(no agent message)' }
    switch ($turn.status) {
        'completed' { $exitCode = 0 }
        'interrupted' { [Console]::Error.WriteLine('Codex turn was interrupted.'); $exitCode = 2 }
        default { [Console]::Error.WriteLine("Codex turn $($turn.status): $($turn.error.message)"); $exitCode = 1 }
    }
} catch {
    if ($deadline.IsCancellationRequested) {
        [Console]::Error.WriteLine("Timed out after $TimeoutSec s. The turn keeps running in Codex thread $threadIdInUse; read it later with thread/read.")
        $exitCode = 3
    } else {
        [Console]::Error.WriteLine("ask-codex: $($_.Exception.Message)")
        $exitCode = 1
    }
} finally {
    if ($socket.State -eq [Net.WebSockets.WebSocketState]::Open) {
        try {
            if ($threadIdInUse) { $null = Invoke-Rpc 'thread/unsubscribe' @{ threadId = $threadIdInUse } }
            $null = $socket.CloseAsync([Net.WebSockets.WebSocketCloseStatus]::NormalClosure, 'done', [Threading.CancellationToken]::None).GetAwaiter().GetResult()
        } catch {}
    }
    $socket.Dispose()
    $deadline.Dispose()
}
exit $exitCode
