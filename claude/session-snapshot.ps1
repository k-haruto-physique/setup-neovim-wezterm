# 今開いている Claude Code の対話セッションを、2 分おきに控える（ログオンタスク「Claude Session Snapshot」）。
# 2026-10-14・troubleshooting #32。登録は register-session-snapshot-task.ps1。
#
# なぜ要るか: ~/.claude/sessions/<pid>.json は Claude が終わる時に消える。Windows Update で再起動された後には
# 1 つも残っておらず、何が開いていたかを知る手段が無かった（2026-10-14 実測）。restore はこの控えを読んで開き直す。
#
# 書く物（~/.claude/state/。PC の中だけ・git に入れない）:
#   open-sessions.json       今の起動で、最後に見た時に開いていた会話
#   open-sessions.prev.json  前の起動（再起動・シャットダウン・サインアウトの前）で、最後に開いていた会話
#   session-history.json     フォルダごと・呼び名ごとの最後の対話セッション（cc が読む。claude -p の会話を拾わないため）
#   session-snapshot.log     失敗した時と、前の起動の控えを移した時だけ 1 行
#
# 守っていること:
#   - 閉じた会話は、2 回続けて見えなかった時に初めて控えから外す。再起動の途中（Claude が先に閉じられ、
#     この道具がまだ動いている数秒）に写しを取っても、控えが空にならない。
#   - 前の控えを prev へ移すのは、この道具が起動した最初の 1 回だけ。しかも、控えの中のプロセスが 1 つも
#     生きていない時だけ（タスクの再起動では移さない）。空の控えで prev を上書きしない（2 回続けて再起動されても消えない）。
[CmdletBinding()]
param(
    [int]$IntervalSeconds = 120,
    [int]$MaxTicks = 0,  # 0＝ずっと。確かめる時に 1・2 を渡す
    [string]$StateDirectory,
    [string]$SessionsDirectory
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
. (Join-Path $PSScriptRoot 'session-common.ps1')
if (-not $StateDirectory) { $StateDirectory = Get-ClaudeStateDirectory }
if (-not $SessionsDirectory) { $SessionsDirectory = Get-ClaudeSessionsDirectory }
New-Item -ItemType Directory -Path $StateDirectory -Force | Out-Null

$CurrentPath = Join-Path $StateDirectory 'open-sessions.json'
$PrevPath = Join-Path $StateDirectory 'open-sessions.prev.json'
$HistoryPath = Join-Path $StateDirectory 'session-history.json'
$LogPath = Join-Path $StateDirectory 'session-snapshot.log'

# 1 つだけ動かす（ログオンタスクがもう一度起動しても、2 つ目はすぐ終わる）。確かめ用の別フォルダなら別の印。
$sha = [Security.Cryptography.SHA1]::Create()
$tag = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($StateDirectory.ToLowerInvariant()))) -replace '-', '').Substring(0, 12)
$mutex = New-Object Threading.Mutex($false, "Local\ClaudeSessionSnapshot_$tag")
if (-not $mutex.WaitOne(0)) { exit 0 }

function Write-SnapshotLog([string]$Message) {
    try {
        if ((Test-Path -LiteralPath $LogPath) -and (Get-Item -LiteralPath $LogPath).Length -gt 200KB) {
            Remove-Item -LiteralPath $LogPath -Force
        }
        Add-Content -LiteralPath $LogPath -Value ('{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message) -Encoding UTF8
    } catch {}
}

function ConvertTo-SnapshotEntry($s) {
    [ordered]@{
        sessionId = [string]$s.sessionId
        cwd       = [string]$s.cwd
        name      = [string]$s.name
        startedAt = [int64]$s.startedAt
        updatedAt = [int64]$s.updatedAt
        status    = [string]$s.status
        pids      = @(@($s.pids) | ForEach-Object { [ordered]@{ pid = [int]$_.pid; procStart = [string]$_.procStart } })
    }
}

function Copy-ToOrderedMap($obj) {
    $m = [ordered]@{}
    if ($obj) { foreach ($p in $obj.PSObject.Properties) { $m[$p.Name] = $p.Value } }
    return $m
}

# --- 起動して最初の 1 回だけ: 前の起動の控えを prev へ ---
$script:stored = @()
$old = Read-ClaudeJson $CurrentPath
if ($old -and @($old.sessions).Count -gt 0) {
    $anyAlive = $false
    foreach ($s in @($old.sessions)) {
        foreach ($p in @($s.pids)) { if (Test-ClaudeProcessAlive $p.pid $p.procStart) { $anyAlive = $true } }
    }
    if ($anyAlive) {
        $script:stored = @($old.sessions)
    } else {
        Write-ClaudeJson $PrevPath ([ordered]@{
            savedAt   = ConvertTo-ClaudeIso $old.savedAt
            rotatedAt = (Get-Date).ToString('o')
            sessions  = @(@($old.sessions) | ForEach-Object { ConvertTo-SnapshotEntry $_ })
        })
        Write-SnapshotLog ('前の起動の控え {0} 件を open-sessions.prev.json へ移した' -f @($old.sessions).Count)
    }
}

$script:miss = @{}  # sessionId → 続けて見えなかった回数

function Invoke-SnapshotTick {
    $now = (Get-Date).ToString('o')
    $live = @(Get-LiveClaudeSessions -SessionsDirectory $SessionsDirectory)
    $liveIds = @($live | ForEach-Object { $_.sessionId })

    $next = New-Object System.Collections.ArrayList
    foreach ($s in $live) {
        [void]$next.Add((ConvertTo-SnapshotEntry $s))
        $script:miss.Remove($s.sessionId)
    }
    foreach ($s in @($script:stored)) {
        $id = [string]$s.sessionId
        if ($liveIds -contains $id) { continue }
        $n = 1 + [int]$script:miss[$id]
        if ($n -lt 2) {
            $script:miss[$id] = $n
            [void]$next.Add((ConvertTo-SnapshotEntry $s))
        } else {
            $script:miss.Remove($id)
        }
    }
    Write-ClaudeJson $CurrentPath ([ordered]@{ savedAt = $now; sessions = @($next) })
    $script:stored = @($next)

    # フォルダごと・呼び名ごとの「前回」。同じフォルダに会話が 2 つあれば、最後に動いた方を残す。
    $hist = Read-ClaudeJson $HistoryPath
    $byDir = Copy-ToOrderedMap $(if ($hist) { $hist.byDir })
    $byAlias = Copy-ToOrderedMap $(if ($hist) { $hist.byAlias })
    foreach ($s in @($live | Sort-Object updatedAt)) {
        $e = [ordered]@{ sessionId = $s.sessionId; cwd = $s.cwd; name = $s.name; lastSeen = $now }
        $byDir[(Get-ClaudeDirKey $s.cwd)] = $e
        $alias = Get-ClaudeSessionAlias $s.name
        if ($alias) { $byAlias[$alias] = $e }
    }
    if ($live.Count -gt 0 -or -not (Test-Path -LiteralPath $HistoryPath)) {
        Write-ClaudeJson $HistoryPath ([ordered]@{ updatedAt = $now; byDir = $byDir; byAlias = $byAlias })
    }
}

$tick = 0
while ($true) {
    try { Invoke-SnapshotTick } catch { Write-SnapshotLog ('失敗: ' + $_.Exception.Message) }
    $tick++
    if ($MaxTicks -gt 0 -and $tick -ge $MaxTicks) { break }
    Start-Sleep -Seconds $IntervalSeconds
}
