# Claude Code のセッションを控える・開き直すための共通部品（2026-10-14・troubleshooting #32）。
# profile.ps1（cc／cn／restore の知らせ）・session-snapshot.ps1・restore-sessions.ps1 が dot-source する。
#
# 読むのは ~/.claude/sessions/<pid>.json の会話の ID・フォルダ・名前・プロセスの開始時刻だけ。
# 隣の <pid>.<hash>.key（セッション間の通信の鍵）には触らない。
# 個人の名前・リポの名前はここに書かない（公開リポ）。控えの中身は ~/.claude/state/ の JSON にだけ入る。
# profile.ps1 から読まれるので、pwsh 7 と Windows PowerShell 5.1 の両方で動く書き方にする（?? や三項演算子を使わない）。

function Get-ClaudeStateDirectory {
    if ($env:CLAUDE_STATE_DIR) { return $env:CLAUDE_STATE_DIR }
    return (Join-Path $env:USERPROFILE '.claude\state')
}

function Get-ClaudeSessionsDirectory {
    if ($env:CLAUDE_SESSIONS_DIR) { return $env:CLAUDE_SESSIONS_DIR }
    return (Join-Path $env:USERPROFILE '.claude\sessions')
}

function Read-ClaudeJson([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try { return (Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { return $null }
}

# 一時ファイルに書いてから置き換える（書いている途中で止まっても、半端なファイルが残らない）。
function Write-ClaudeJson([string]$Path, $Value) {
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $tmp = '{0}.{1}.tmp' -f $Path, $PID
    $json = ConvertTo-Json -InputObject $Value -Depth 6
    [IO.File]::WriteAllText($tmp, $json, (New-Object Text.UTF8Encoding($false)))
    # $null を渡すと PowerShell が空文字に変えて「The path is empty」で落ちる＝NullString で本当の null を渡す
    if (Test-Path -LiteralPath $Path) { [IO.File]::Replace($tmp, $Path, [NullString]::Value) }
    else { [IO.File]::Move($tmp, $Path) }
}

# pwsh 7 の ConvertFrom-Json は ISO の日時を DateTime に変えてしまう。書き戻す時は ISO の文字に戻す。
function ConvertTo-ClaudeIso($Value) {
    if ($Value -is [datetime]) { return $Value.ToString('o') }
    return [string]$Value
}

# 控えの照合用のキー（Windows のフォルダ名は大文字小文字を区別しない）。
function Get-ClaudeDirKey([string]$Dir) {
    if (-not $Dir) { return '' }
    return $Dir.TrimEnd('\', '/').ToLowerInvariant()
}

# 会話の名前から日付を外した部分（20261005_life → life）。cc／cn の短い呼び名に使う。
function Get-ClaudeSessionAlias([string]$Name) {
    if (-not $Name) { return '' }
    return ($Name -replace '^\d{8}[_-]', '').ToLowerInvariant()
}

# PID は使い回されるので、プロセスの開始時刻（procStart＝FILETIME）まで一致した時だけ「生きている」とする。
function Test-ClaudeProcessAlive($ProcessId, $ProcStart) {
    $p = Get-Process -Id ([int]$ProcessId) -ErrorAction SilentlyContinue
    if (-not $p) { return $false }
    if (-not $ProcStart) { return $true }
    try { return ($p.StartTime.ToFileTime() -eq [int64]$ProcStart) } catch { return $true }
}

# 今動いている対話セッション（kind = interactive。claude -p や受け口の起動は数えない）。
# 同じ会話を 2 つのプロセスが開いていても 1 件にまとめ、pids に両方を入れる。
function Get-LiveClaudeSessions {
    param([string]$SessionsDirectory = (Get-ClaudeSessionsDirectory))
    $byId = [ordered]@{}
    foreach ($f in @(Get-ChildItem -LiteralPath $SessionsDirectory -Filter '*.json' -File -ErrorAction SilentlyContinue)) {
        $d = Read-ClaudeJson $f.FullName
        if (-not $d -or -not $d.sessionId -or $d.kind -ne 'interactive') { continue }
        if (-not (Test-ClaudeProcessAlive $d.pid $d.procStart)) { continue }
        $key = [string]$d.sessionId
        if (-not $byId.Contains($key)) {
            $byId[$key] = [pscustomobject]@{
                sessionId = $key
                cwd       = [string]$d.cwd
                name      = [string]$d.name
                startedAt = [int64]$d.startedAt
                updatedAt = [int64]$d.updatedAt
                pids      = @()
            }
        }
        $s = $byId[$key]
        $s.pids += [pscustomobject]@{ pid = [int]$d.pid; procStart = [string]$d.procStart }
        if ([int64]$d.updatedAt -gt $s.updatedAt) { $s.updatedAt = [int64]$d.updatedAt }
    }
    return @($byId.Values)
}

# cc／cn の行き先を決める。順に:
#   何も無し＝今のフォルダ ／ パス ／ フォルダ名と同じ ／ 会話の呼び名（控えの名前から）／ フォルダ名の頭 ／ フォルダ名の一部
# 返り値: @{ Dir = <フォルダ>; SessionId = <呼び名で当たった会話。無ければ $null>; Name = <その会話の名前> }
function Find-ClaudeTarget([string]$Query, [string]$ReposRoot) {
    if (-not $Query) { return @{ Dir = (Get-Location).Path; SessionId = $null; Name = '' } }
    if ($Query -match '[\\/:]' -or $Query -eq '.' -or $Query -eq '..') {
        if (Test-Path -LiteralPath $Query -PathType Container) {
            return @{ Dir = (Resolve-Path -LiteralPath $Query).Path; SessionId = $null; Name = '' }
        }
        Write-Host "フォルダ「$Query」がありません" -ForegroundColor Yellow
        return $null
    }
    $dirs = @(Get-ChildItem -LiteralPath $ReposRoot -Directory -ErrorAction SilentlyContinue)
    $exact = @($dirs | Where-Object { $_.Name -eq $Query })
    if ($exact.Count -ge 1) { return @{ Dir = $exact[0].FullName; SessionId = $null; Name = '' } }

    $hist = Read-ClaudeJson (Join-Path (Get-ClaudeStateDirectory) 'session-history.json')
    if ($hist -and $hist.byAlias) {
        $a = $hist.byAlias.PSObject.Properties[$Query.ToLowerInvariant()]
        if ($a -and $a.Value.cwd -and (Test-Path -LiteralPath $a.Value.cwd -PathType Container)) {
            return @{ Dir = [string]$a.Value.cwd; SessionId = [string]$a.Value.sessionId; Name = [string]$a.Value.name }
        }
    }

    $q = [WildcardPattern]::Escape($Query)
    $hits = @($dirs | Where-Object { $_.Name -like "$q*" })
    if ($hits.Count -eq 0) { $hits = @($dirs | Where-Object { $_.Name -like "*$q*" }) }
    if ($hits.Count -eq 1) { return @{ Dir = $hits[0].FullName; SessionId = $null; Name = '' } }
    if ($hits.Count -eq 0) {
        Write-Host "「$Query」に当たるリポがありません（$ReposRoot の下）" -ForegroundColor Yellow
    } else {
        Write-Host ("「{0}」に当たるリポが {1} 個あります。もう少し長く打ってください: {2}" -f $Query, $hits.Count, (($hits | ForEach-Object { $_.Name }) -join ' / ')) -ForegroundColor Yellow
    }
    return $null
}

# 再起動の前の控えのうち、まだ開き直していない会話（profile.ps1 の知らせ用）。3 日より古い控えは数えない。
function Get-ClaudeRestorePending {
    $prev = Read-ClaudeJson (Join-Path (Get-ClaudeStateDirectory) 'open-sessions.prev.json')
    if (-not $prev -or $prev.restoredAt -or $prev.skippedAt -or -not $prev.sessions) { return @() }
    try { if (((Get-Date) - [datetime]$prev.savedAt).TotalDays -gt 3) { return @() } } catch {}
    $live = @(Get-LiveClaudeSessions | ForEach-Object { $_.sessionId })
    return @(@($prev.sessions) | Where-Object { $live -notcontains $_.sessionId })
}
