# Codex rate-limit writer for the WezTerm tab bar (no pane split).
#
# 置き場所の原則（2026-09-16）:
#   セッション固有の値（モデル / context / cwd / branch）は **そのペインの中** に出す。
#   タブバーはウィンドウに 1 本しかないので、ペインごとに違う値を出すと
#   「今どのセッションの cwd を見ているのか」が分からなくなる。
#   アカウント共通の値（5h / 7d の使用制限）だけをタブバーへ逃がす。
#   ＝「切れると困るが 1 つで足りるもの」だけを、分割に不感な場所へ置く。
#
# Codex の内蔵 status line はペイン幅で切れる（実測: 3 項目で 63 桁、
# クロコ側のペインは 47 桁まで狭くなる）。切れて困るのは使用制限だけなので、
# それをタブバーへ出し、残りは内蔵行に任せて末尾から切れてよい、という分担にする。
#
# このスクリプトは 1 プロセスで全 Codex ペインを見て、**最も新しい** rollout の
# 使用制限を 1 つだけ書き出す。セッション固有の情報は一切書かない。
[CmdletBinding()]
param(
    [int]$IntervalSeconds = 2,
    [string]$StatusDirectory = (Join-Path $env:LOCALAPPDATA 'Temp/codex-status')
)

$ErrorActionPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

# Singleton: the logon task may be started again while a copy is already running.
$mutex = [Threading.Mutex]::new($false, 'Local\CodexTabBarStatus')
if (-not $mutex.WaitOne(0)) { exit 0 }

$CodexRoot = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
$SessionsRoot = Join-Path $CodexRoot 'sessions'
New-Item -ItemType Directory -Path $StatusDirectory -Force | Out-Null

# Codex 0.154 truncates the terminal-title UUID to 29 chars; accept both forms.
$TitlePattern = '^codex \| ([0-9a-fA-F-]{29,36})(?:\.\.\.)? \| '
$RolloutCache = @{}   # uuid prefix -> rollout path

function Format-Reset([object]$Epoch) {
    if (-not $Epoch) { return '' }
    $seconds = [int64]$Epoch - [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    if ($seconds -le 0) { return '' }
    $span = [TimeSpan]::FromSeconds($seconds)
    if ($span.TotalDays -ge 1) { return ('{0}d{1}h' -f [Math]::Floor($span.TotalDays), $span.Hours) }
    if ($span.TotalHours -ge 1) { return ('{0}h{1}m' -f [Math]::Floor($span.TotalHours), $span.Minutes) }
    return ('{0}m' -f [Math]::Max(1, [Math]::Floor($span.TotalMinutes)))
}

function Resolve-Rollout([string]$Prefix) {
    if ($RolloutCache.ContainsKey($Prefix)) {
        $cached = $RolloutCache[$Prefix]
        if ($cached -and (Test-Path -LiteralPath $cached)) { return $cached }
        $RolloutCache.Remove($Prefix)
    }
    if ($Prefix -notmatch '^[0-9a-fA-F-]{29,36}$') { return $null }
    $candidates = @(Get-ChildItem -LiteralPath $SessionsRoot -Recurse -File -Filter "rollout-*-$Prefix*.jsonl")
    # A colliding prefix stays unavailable rather than showing another account's limits.
    if ($candidates.Count -ne 1) { return $null }
    $RolloutCache[$Prefix] = $candidates[0].FullName
    return $candidates[0].FullName
}

function Read-RateLimits([string]$FilePath) {
    $tokenLine = $null
    $stream = [IO.FileStream]::new($FilePath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    $reader = $null
    try {
        $offset = [Math]::Max(0, $stream.Length - 256KB)
        [void]$stream.Seek($offset, [IO.SeekOrigin]::Begin)
        $reader = [IO.StreamReader]::new($stream, [Text.Encoding]::UTF8)
        if ($offset -gt 0) { [void]$reader.ReadLine() }
        while ($null -ne ($line = $reader.ReadLine())) {
            if ($line.Contains('"type":"event_msg"') -and $line.Contains('"type":"token_count"')) { $tokenLine = $line }
        }
    } finally {
        if ($reader) { $reader.Dispose() } else { $stream.Dispose() }
    }
    if (-not $tokenLine) { return $null }
    try { $token = $tokenLine | ConvertFrom-Json } catch { return $null }
    $limits = $token.payload.rate_limits
    if ($null -eq $limits.primary.used_percent -and $null -eq $limits.secondary.used_percent) { return $null }
    return @{
        Primary = $limits.primary.used_percent
        Secondary = $limits.secondary.used_percent
        PrimaryReset = Format-Reset $limits.primary.resets_at
        SecondaryReset = Format-Reset $limits.secondary.resets_at
    }
}

$missedListings = 0
try {
    while ($true) {
        $panes = @(& wezterm cli list --format json 2>$null | ConvertFrom-Json)
        if ($LASTEXITCODE -ne 0 -or $panes.Count -eq 0) {
            # WezTerm is closed, or the mux is briefly wedged (troubleshooting #13).
            # Never exit: this is a logon-scoped daemon and WezTerm gets restarted often
            # (troubleshooting #2 makes a full restart routine here). wezterm.lua must not
            # relaunch it — spawning from the GUI process raises 0xc0000142 dialogs (#29).
            $missedListings++
            Start-Sleep -Seconds ([Math]::Min(10, $IntervalSeconds * [Math]::Min(5, $missedListings)))
            continue
        }
        $missedListings = 0
        $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

        # Rate limits belong to the account, so every live session reports the same
        # window; they differ only by how stale each session's last reading is.
        # Take the most recently written rollout = the newest server-reported value.
        $newestAt = [datetime]::MinValue
        $newest = $null
        foreach ($pane in $panes) {
            if ("$($pane.title)" -notmatch $TitlePattern) { continue }
            $rollout = Resolve-Rollout $Matches[1]
            if (-not $rollout) { continue }
            $writtenAt = (Get-Item -LiteralPath $rollout).LastWriteTimeUtc
            if ($writtenAt -le $newestAt) { continue }
            $limits = Read-RateLimits $rollout
            if (-not $limits) { continue }
            $newestAt = $writtenAt
            $newest = $limits
        }

        $payload = [ordered]@{ updated = $now; primary = $null; secondary = $null
            primary_reset = ''; secondary_reset = '' }
        if ($newest) {
            $payload.primary = $newest.Primary
            $payload.secondary = $newest.Secondary
            $payload.primary_reset = $newest.PrimaryReset
            $payload.secondary_reset = $newest.SecondaryReset
        }
        $path = Join-Path $StatusDirectory 'account.json'
        $temp = "$path.$PID.tmp"
        [IO.File]::WriteAllText($temp, ($payload | ConvertTo-Json -Compress -Depth 3), [Text.UTF8Encoding]::new($false))
        [IO.File]::Move($temp, $path, $true)

        # Per-pane files from the first draft (2026-09-16) are obsolete: cwd and branch
        # are session-specific and now live in Codex's own status line.
        foreach ($stale in (Get-ChildItem -LiteralPath $StatusDirectory -File -Filter '*.json')) {
            if ($stale.Name -ne 'account.json') { Remove-Item -LiteralPath $stale.FullName -Force }
        }
        [IO.File]::WriteAllText((Join-Path $StatusDirectory 'heartbeat'), "$now")
        Start-Sleep -Seconds ([Math]::Max(1, $IntervalSeconds))
    }
} finally {
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}
