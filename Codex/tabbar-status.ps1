# Codex status writer for the WezTerm tab bar (no pane split).
#
# Why the tab bar: Codex's built-in status line is one row inside the pane, so it is
# truncated as soon as panes get narrow (measured 2026-09-16: 3 items already need
# 63 columns, while the Claude tab was running 47-column panes). The tab bar is
# window-wide (190 columns here), so it does not shrink when panes are split.
#
# One process serves every Codex pane in every window: it discovers sessions from the
# WezTerm pane title (`codex | <thread-uuid> | <model>`), which is the same exact
# binding that troubleshooting #19 settled on, and writes one small JSON file per pane.
# wezterm.lua reads the active pane's file in update-status. Nothing is ever split,
# moved or repaired, so the geometry watchdog in statusline.ps1 is no longer needed.
[CmdletBinding()]
param(
    [int]$IntervalSeconds = 2,
    [string]$StatusDirectory = (Join-Path $env:LOCALAPPDATA 'Temp/codex-status')
)

$ErrorActionPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

# Singleton: update-status relaunches this script whenever the heartbeat goes stale,
# so a duplicate must exit instead of doubling the wezterm cli traffic.
$mutex = [Threading.Mutex]::new($false, 'Local\CodexTabBarStatus')
if (-not $mutex.WaitOne(0)) { exit 0 }

$CodexRoot = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
$SessionsRoot = Join-Path $CodexRoot 'sessions'
New-Item -ItemType Directory -Path $StatusDirectory -Force | Out-Null

# Codex 0.154 truncates the terminal-title UUID to 29 chars; accept both forms.
$TitlePattern = '^codex \| ([0-9a-fA-F-]{29,36})(?:\.\.\.)? \| '
$RolloutCache = @{}   # uuid prefix -> rollout path
$GitCache = @{}       # cwd -> @{ At = <unix>; Text = <string> }

function Format-Directory([string]$Cwd) {
    if (-not $Cwd) { return '' }
    $display = $Cwd
    if ($display.StartsWith($env:USERPROFILE, [StringComparison]::OrdinalIgnoreCase)) {
        $display = '~' + $display.Substring($env:USERPROFILE.Length)
    }
    return $display.Replace('\', '/')
}

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
    # A colliding prefix stays unavailable rather than showing another session's limits.
    if ($candidates.Count -ne 1) { return $null }
    $RolloutCache[$Prefix] = $candidates[0].FullName
    return $candidates[0].FullName
}

function Read-Rollout([string]$FilePath) {
    $contextLine = $null
    $tokenLine = $null
    $stream = [IO.FileStream]::new($FilePath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    $reader = $null
    try {
        $offset = [Math]::Max(0, $stream.Length - 256KB)
        [void]$stream.Seek($offset, [IO.SeekOrigin]::Begin)
        $reader = [IO.StreamReader]::new($stream, [Text.Encoding]::UTF8)
        if ($offset -gt 0) { [void]$reader.ReadLine() }
        while ($null -ne ($line = $reader.ReadLine())) {
            if ($line.Contains('"type":"turn_context"')) { $contextLine = $line }
            if ($line.Contains('"type":"event_msg"') -and $line.Contains('"type":"token_count"')) { $tokenLine = $line }
        }
    } finally {
        if ($reader) { $reader.Dispose() } else { $stream.Dispose() }
    }
    $result = @{ Cwd = $null; Primary = $null; Secondary = $null; PrimaryReset = ''; SecondaryReset = '' }
    if ($contextLine) {
        try {
            $context = $contextLine | ConvertFrom-Json
            if ($context.payload.cwd) { $result.Cwd = $context.payload.cwd }
        } catch {}
    }
    if (-not $result.Cwd) {
        try {
            $meta = Get-Content -LiteralPath $FilePath -TotalCount 1 | ConvertFrom-Json
            if ($meta.payload.cwd) { $result.Cwd = $meta.payload.cwd }
        } catch {}
    }
    if ($tokenLine) {
        try {
            $token = $tokenLine | ConvertFrom-Json
            $result.Primary = $token.payload.rate_limits.primary.used_percent
            $result.Secondary = $token.payload.rate_limits.secondary.used_percent
            $result.PrimaryReset = Format-Reset $token.payload.rate_limits.primary.resets_at
            $result.SecondaryReset = Format-Reset $token.payload.rate_limits.secondary.resets_at
        } catch {}
    }
    return $result
}

function Get-GitSummary([string]$Cwd) {
    if (-not $Cwd -or -not (Test-Path -LiteralPath $Cwd)) { return '' }
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $cached = $GitCache[$Cwd]
    # git status on a large repo is the only expensive call here; 10s is fresh enough
    # for a branch name and dirty markers.
    if ($cached -and ($now - $cached.At) -lt 10) { return $cached.Text }
    $branch = git -C $Cwd --no-optional-locks rev-parse --abbrev-ref HEAD 2>$null
    $text = ''
    if ($branch) {
        $symbols = ''
        $porcelain = @(git -C $Cwd --no-optional-locks status --porcelain 2>$null)
        if ($porcelain) {
            if ($porcelain | Where-Object { $_ -match '^(DD|AU|UD|UA|DU|AA|UU)' }) { $symbols += '=' }
            if ($porcelain | Where-Object { $_ -match '^[MADRC][ ?]' -or $_ -match '^[MADRC][MADRC]' }) { $symbols += '+' }
            if ($porcelain | Where-Object { $_ -match '^[ MADRC][MD]' }) { $symbols += '!' }
            if ($porcelain | Where-Object { $_ -match '^\?\?' }) { $symbols += '?' }
        }
        $aheadBehind = git -C $Cwd --no-optional-locks rev-list --left-right --count '@{upstream}...HEAD' 2>$null
        if ($LASTEXITCODE -eq 0 -and $aheadBehind) {
            $counts = $aheadBehind -split '\s+'
            if ([int]$counts[0] -gt 0) { $symbols += "v$($counts[0])" }
            if ([int]$counts[1] -gt 0) { $symbols += "^$($counts[1])" }
        }
        $text = "$branch$(if ($symbols) { " $symbols" })"
    }
    $GitCache[$Cwd] = @{ At = $now; Text = $text }
    return $text
}

function Write-StatusFile([int]$PaneId, [hashtable]$Payload) {
    $path = Join-Path $StatusDirectory "$PaneId.json"
    $temp = "$path.$PID.tmp"
    [IO.File]::WriteAllText($temp, ($Payload | ConvertTo-Json -Compress -Depth 4), [Text.UTF8Encoding]::new($false))
    [IO.File]::Move($temp, $path, $true)
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
            # Back off instead so an idle machine is not polled twice a second.
            $missedListings++
            Start-Sleep -Seconds ([Math]::Min(10, $IntervalSeconds * [Math]::Min(5, $missedListings)))
            continue
        }
        $missedListings = 0
        $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        $live = @{}
        foreach ($pane in $panes) {
            if ("$($pane.title)" -notmatch $TitlePattern) { continue }
            $live["$($pane.pane_id)"] = $true
            $rollout = Resolve-Rollout $Matches[1]
            $payload = [ordered]@{ updated = $now; primary = $null; secondary = $null
                primary_reset = ''; secondary_reset = ''; dir = ''; git = '' }
            if ($rollout) {
                $data = Read-Rollout $rollout
                $payload.primary = $data.Primary
                $payload.secondary = $data.Secondary
                $payload.primary_reset = $data.PrimaryReset
                $payload.secondary_reset = $data.SecondaryReset
                $payload.dir = Format-Directory $data.Cwd
                $payload.git = Get-GitSummary $data.Cwd
            }
            Write-StatusFile ([int]$pane.pane_id) $payload
        }
        # Drop files for panes that are gone so a recycled pane id never shows stale limits.
        foreach ($stale in (Get-ChildItem -LiteralPath $StatusDirectory -File -Filter '*.json')) {
            if (-not $live.ContainsKey($stale.BaseName)) { Remove-Item -LiteralPath $stale.FullName -Force }
        }
        [IO.File]::WriteAllText((Join-Path $StatusDirectory 'heartbeat'), "$now")
        Start-Sleep -Seconds ([Math]::Max(1, $IntervalSeconds))
    }
} finally {
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}
