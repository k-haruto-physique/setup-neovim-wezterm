# Codex statusline monitor for a dedicated WezTerm pane.
# Codex does not expose Claude's statusLine.command callback, so this renderer
# reads the active Codex rollout JSONL and renders the same four information rows.
[CmdletBinding()]
param(
    [string]$Path = (Get-Location).Path,
    [string]$SessionId,
    [string]$BindingPath,
    [Nullable[int]]$OwnerPaneId,
    [Nullable[int]]$OwnerProcessId,
    [string]$SessionPrefix,
    [string]$InitialModel,
    [switch]$Watch,
    [int]$IntervalSeconds = 2
)

$ErrorActionPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
$Esc = [char]27
$Reset = "$Esc[0m"
$Dim = "$Esc[38;2;115;121;148m"
$Green = "$Esc[38;2;166;209;137m"
$Blue = "$Esc[38;2;140;170;238m"
$Teal = "$Esc[38;2;129;200;190m"
$Mauve = "$Esc[38;2;202;158;230m"
$Peach = "$Esc[38;2;239;159;118m"
$Yellow = "$Esc[38;2;229;200;144m"
$Red = "$Esc[38;2;231;130;132m"

$CodexRoot = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }

if ($null -ne $OwnerProcessId -and $null -ne $OwnerPaneId) {
    $registry = Join-Path $CodexRoot 'status-panes'
    New-Item -ItemType Directory -Path $registry -Force | Out-Null
    $BindingPath = Join-Path $registry "$OwnerProcessId-$OwnerPaneId.json"
    $owner = Get-Process -Id $OwnerProcessId -ErrorAction SilentlyContinue
    if (-not $owner) { exit 0 }
    [Console]::Write("$Esc]2;Codex status:${OwnerProcessId}:$OwnerPaneId$([char]7)")
    $initMutex = [Threading.Mutex]::new($false, "Local\CodexStatus-$OwnerProcessId-$OwnerPaneId")
    $initLocked = $false
    try {
    $initLocked = $initMutex.WaitOne(1500)
    if (-not $initLocked) { exit 0 }
    $saved = if (Test-Path -LiteralPath $BindingPath) { Get-Content -LiteralPath $BindingPath -Raw | ConvertFrom-Json } else { $null }
    if (-not $saved -or $saved.ended -or (([datetime]$saved.ownerStartedAt) - $owner.StartTime.ToUniversalTime()).Duration().TotalMilliseconds -gt 2) {
        $pendingBinding = @{ sessionId = $SessionPrefix; transcriptPath = $null; cwd = $Path; model = $InitialModel
            ownerPaneId = $OwnerPaneId; ownerPid = $OwnerProcessId; ownerStartedAt = $owner.StartTime.ToUniversalTime().ToString('o')
            statusPaneId = [int]$env:WEZTERM_PANE; ended = $false }
        $temp = "$BindingPath.$PID.tmp"
        [IO.File]::WriteAllText($temp, ($pendingBinding | ConvertTo-Json -Depth 5))
        [IO.File]::Move($temp, $BindingPath, $true)
    }
    } finally { if ($initLocked) { $initMutex.ReleaseMutex() }; $initMutex.Dispose() }
}

function Get-StageColor([double]$Percent) {
    if ($Percent -ge 80) { return $Red }
    if ($Percent -ge 50) { return $Yellow }
    return $Green
}

function Format-WindowSize([object]$Tokens) {
    if ($null -eq $Tokens) { return '' }
    $size = [double]$Tokens
    if ($size -ge 1000000) { return ('/{0:0.#}M' -f ($size / 1000000)) }
    if ($size -ge 1000) { return ('/{0:0}K' -f ($size / 1000)) }
    return "/$size"
}

function Format-Directory([string]$Cwd) {
    $display = $Cwd
    if ($display.StartsWith($env:USERPROFILE, [StringComparison]::OrdinalIgnoreCase)) {
        $display = '~' + $display.Substring($env:USERPROFILE.Length)
    }
    $parts = @($display.Replace('\', '/') -split '/' | Where-Object { $_ })
    if ($parts.Count -gt 10) { return '.../' + (($parts | Select-Object -Last 10) -join '/') }
    return $display.Replace('\', '/')
}

function Format-Reset([object]$Epoch) {
    if (-not $Epoch) { return '' }
    $seconds = [int64]$Epoch - [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    if ($seconds -le 0) { return '' }
    $span = [TimeSpan]::FromSeconds($seconds)
    if ($span.TotalDays -ge 1) { return ('↺{0}d{1}h' -f [Math]::Floor($span.TotalDays), $span.Hours) }
    if ($span.TotalHours -ge 1) { return ('↺{0}h{1}m' -f [Math]::Floor($span.TotalHours), $span.Minutes) }
    return ('↺{0}m' -f [Math]::Max(1, [Math]::Floor($span.TotalMinutes)))
}

function Join-Segments([string[]]$Segments) {
    return (($Segments | Where-Object { $_ }) -join " $Dim│$Reset ")
}

function Test-StatusPlacement($OwnerPane, $StatusPane) {
    return ($OwnerPane.tab_id -eq $StatusPane.tab_id -and
        $OwnerPane.left_col -eq $StatusPane.left_col -and
        $OwnerPane.size.cols -eq $StatusPane.size.cols -and
        $StatusPane.top_row -eq ($OwnerPane.top_row + $OwnerPane.size.rows + 1) -and
        $StatusPane.size.rows -eq 5)
}

function Find-Rollout([string]$Cwd) {
    $root = Join-Path $CodexRoot 'sessions'
    if ($SessionId) {
        if ($SessionId -notmatch '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{5}(?:[0-9a-fA-F]{7})?$') { return $null }
        $candidates = @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter "rollout-*-$SessionId*.jsonl")
        # Codex 0.154 truncates terminal-title UUIDs to 29 chars. Resolve only a
        # unique prefix; a collision stays unavailable rather than selecting a log.
        if ($candidates.Count -ne 1) { return $null }
        return $candidates[0]
    }
    # A bound renderer may wait for its transcript, but may never show another session.
    if ($BindingPath) { return $null }
    $normalized = [IO.Path]::GetFullPath($Cwd).TrimEnd('\').ToLowerInvariant()
    foreach ($file in (Get-ChildItem -LiteralPath $root -Recurse -File -Filter 'rollout-*.jsonl' | Sort-Object LastWriteTime -Descending | Select-Object -First 30)) {
        $first = Get-Content -LiteralPath $file.FullName -TotalCount 1
        if (-not $first) { continue }
        try { $meta = $first | ConvertFrom-Json } catch { continue }
        if ($meta.payload.cwd -and ([IO.Path]::GetFullPath($meta.payload.cwd).TrimEnd('\').ToLowerInvariant() -eq $normalized)) { return $file }
    }
    return $null
}

function Read-StatusEvents([string]$FilePath, [int64]$MaximumBytes) {
    $contextLine = $null
    $tokenLine = $null
    $stream = [IO.FileStream]::new($FilePath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    $reader = $null
    try {
        $offset = [Math]::Max(0, $stream.Length - $MaximumBytes)
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
    return @($contextLine, $tokenLine) | Where-Object { $_ }
}

$State = @{
    FilePath = ''
    Model = 'Codex'
    Effort = ''
    Used = $null
    Window = $null
    Primary = $null
    Secondary = $null
    PrimaryReset = ''
    SecondaryReset = ''
    PreviousLines = @()
}
$configPath = Join-Path $CodexRoot 'config.toml'
if (Test-Path -LiteralPath $configPath) {
    foreach ($configLine in (Get-Content -LiteralPath $configPath -TotalCount 20)) {
        if ($configLine -match '^model\s*=\s*"([^"]+)"') { $State.Model = $Matches[1] }
        if ($configLine -match '^model_reasoning_effort\s*=\s*"([^"]+)"') { $State.Effort = $Matches[1] }
    }
}

function Render-Status {
    param([string]$Cwd)
    $file = Find-Rollout $Cwd
    $model = $State.Model
    $effort = $State.Effort
    $used = $State.Used
    $window = $State.Window
    $primary = $State.Primary
    $secondary = $State.Secondary
    $primaryReset = $State.PrimaryReset
    $secondaryReset = $State.SecondaryReset

    if ($file) {
        $maximumBytes = 256KB
        if ($State.FilePath -ne $file.FullName) {
            $State.FilePath = $file.FullName
            $maximumBytes = 16MB
            try { $meta = Get-Content -LiteralPath $file.FullName -TotalCount 1 | ConvertFrom-Json; if ($meta.payload.cwd) { $Cwd = $meta.payload.cwd } } catch {}
            $used = $null
            $window = $null
        }
        $lines = Read-StatusEvents $file.FullName $maximumBytes
        foreach ($line in $lines) {
            try { $event = $line | ConvertFrom-Json } catch { continue }
            if ($event.type -eq 'session_meta' -and $event.payload.model_provider) { $model = if ($event.payload.model) { $event.payload.model } else { $model } }
            if ($event.type -eq 'turn_context') {
                if ($event.payload.cwd) { $Cwd = $event.payload.cwd }
                if ($event.payload.model) { $model = $event.payload.model }
                if ($event.payload.effort) { $effort = $event.payload.effort }
            }
            if ($event.type -eq 'event_msg' -and $event.payload.type -eq 'token_count') {
                $used = if ($null -ne $event.payload.info.last_token_usage.total_tokens) {
                    [double]$event.payload.info.last_token_usage.total_tokens
                } else { $null }
                $window = $event.payload.info.model_context_window
                $primary = $event.payload.rate_limits.primary.used_percent
                $secondary = $event.payload.rate_limits.secondary.used_percent
                $primaryReset = $event.payload.rate_limits.primary.resets_at
                $secondaryReset = $event.payload.rate_limits.secondary.resets_at
            }
        }
    }

    if ($State.LiveModel) { $model = $State.LiveModel; $effort = $State.LiveEffort }
    $State.Model = $model
    $State.Effort = $effort
    $State.Used = $used
    $State.Window = $window
    $State.Primary = $primary
    $State.Secondary = $secondary
    $State.PrimaryReset = $primaryReset
    $State.SecondaryReset = $secondaryReset
    $State.Cwd = $Cwd

    $primaryReset = Format-Reset $primaryReset
    $secondaryReset = Format-Reset $secondaryReset
    $effortColor = switch ($effort) {
        'low' { $Dim }
        'medium' { $Green }
        'high' { $Yellow }
        'xhigh' { $Peach }
        'max' { $Red }
        default { $Dim }
    }
    $line1 = Join-Segments @("$Mauve◆ $model$Reset", $(if ($effort) { "$Dim◇ eff:$effortColor$effort$Reset" }))
    if ($used -ne $null -and $window) {
        $pct = [Math]::Round(([double]$used / [double]$window) * 100)
        $ctxColor = Get-StageColor $pct
        $sizeLabel = Format-WindowSize $window
        $line2 = Join-Segments @(
            "$Teal◈ ctx:$ctxColor${pct}%$Dim$sizeLabel$Reset",
            $(if ($primary -ne $null) { "$Dim◐ 5h:$(Get-StageColor $primary)$primary% $Dim$primaryReset$Reset" }),
            $(if ($secondary -ne $null) { "$Dim◑ 7d:$(Get-StageColor $secondary)$secondary% $Dim$secondaryReset$Reset" })
        )
    } else { $line2 = "$Teal◈ ctx:$Dim unavailable$Reset" }
    $line3 = "$Blue▸ $(Format-Directory $Cwd)$Reset"
    $branch = git -C $Cwd --no-optional-locks rev-parse --abbrev-ref HEAD 2>$null
    $symbols = ''
    if ($branch) {
        $porcelain = @(git -C $Cwd --no-optional-locks status --porcelain 2>$null)
        if ($porcelain) {
            if ($porcelain | Where-Object { $_ -match '^(DD|AU|UD|UA|DU|AA|UU)' }) { $symbols += '=' }
            if ($porcelain | Where-Object { $_ -match '^[MADRC][ ?]' -or $_ -match '^[MADRC][MADRC]' }) { $symbols += '+' }
            if ($porcelain | Where-Object { $_ -match '^[ MADRC][MD]' }) { $symbols += '!' }
            if ($porcelain | Where-Object { $_ -match '^\?\?' }) { $symbols += '?' }
            if ($porcelain | Where-Object { $_ -match '^[ MADRC]D' }) { $symbols += 'x' }
        }
        $aheadBehind = git -C $Cwd --no-optional-locks rev-list --left-right --count '@{upstream}...HEAD' 2>$null
        if ($LASTEXITCODE -eq 0 -and $aheadBehind) {
            $counts = $aheadBehind -split '\s+'
            if ([int]$counts[0] -gt 0) { $symbols += "v$($counts[0])" }
            if ([int]$counts[1] -gt 0) { $symbols += "^$($counts[1])" }
        }
    }
    $git = if ($branch) { "$branch$(if ($symbols) { " $symbols" })" } else { 'not a git repository' }
    $line4 = "$Green⎇ $git$Reset"
    $renderedLines = @($line1, $line2, $line3, $line4)
    if (-not $Watch) {
        [Console]::WriteLine($renderedLines -join "`n")
        return
    }
    $frame = [Text.StringBuilder]::new()
    for ($index = 0; $index -lt $renderedLines.Count; $index++) {
        if ($State.PreviousLines.Count -le $index -or $State.PreviousLines[$index] -ne $renderedLines[$index]) {
            [void]$frame.Append("$Esc[$($index + 1);1H$($renderedLines[$index])$Reset$Esc[K")
        }
    }
    if ($frame.Length -gt 0) {
        # Batch changed rows in one write; never blank the whole pane between frames.
        [Console]::Write("$Esc[?2026h$frame$Esc[?2026l")
    }
    $State.PreviousLines = $renderedLines
}

if ($Watch) { [Console]::Write("$Esc[?25l") }
try {
    do {
        if ($BindingPath) {
            try { $binding = Get-Content -LiteralPath $BindingPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop }
            catch { break }
            if ($binding.ended) { break }
            $owner = Get-Process -Id $binding.ownerPid -ErrorAction SilentlyContinue
            if (-not $owner -or (([datetime]$binding.ownerStartedAt) - $owner.StartTime.ToUniversalTime()).Duration().TotalMilliseconds -gt 2) { break }
            [Console]::Write("$Esc]2;Codex status:$($binding.ownerPid):$($binding.ownerPaneId)$([char]7)")
            $State.LiveModel = $null
            $State.LiveEffort = ''
            $panes = @(& wezterm cli list --format json | ConvertFrom-Json)
            if ($LASTEXITCODE -eq 0) {
                $mainPane = $panes | Where-Object pane_id -eq $binding.ownerPaneId | Select-Object -First 1
                if (-not $mainPane) { break }
                $selfPane = $panes | Where-Object pane_id -eq ([int]$env:WEZTERM_PANE) | Select-Object -First 1
                $zoomed = $panes | Where-Object { $_.tab_id -eq $mainPane.tab_id -and $_.is_zoomed }
                if ($selfPane -and $mainPane.size.rows -gt 6 -and -not $zoomed -and -not (Test-StatusPlacement $mainPane $selfPane)) {
                    # Move this existing renderer; never move or restart a user's shell.
                    $client = @(& wezterm cli list-clients --format json | ConvertFrom-Json) | Where-Object { $null -ne $_.focused_pane_id } | Select-Object -First 1
                    & wezterm cli split-pane --pane-id $binding.ownerPaneId --bottom --cells 5 --move-pane-id $selfPane.pane_id | Out-Null
                    if ($LASTEXITCODE -eq 0 -and $client) {
                        $focus = if ($client.focused_pane_id -eq $selfPane.pane_id) { $binding.ownerPaneId } else { $client.focused_pane_id }
                        & wezterm cli activate-pane --pane-id $focus | Out-Null
                    }
                }
                # If startup hooks and title discovery raced, retain one renderer.
                $matching = @($panes | Where-Object title -eq "Codex status:$($binding.ownerPid):$($binding.ownerPaneId)" | Sort-Object pane_id)
                if ($env:WEZTERM_PANE -match '^\d+$' -and $matching.Count -gt 1 -and [int]$env:WEZTERM_PANE -ne $matching[0].pane_id) { break }
                if ($mainPane.title -match '^codex \| ([0-9a-f-]{29,36})(?:\.\.\.)? \| (.+)$') {
                    $titlePrefix = $Matches[1]
                    $titleModel = $Matches[2]
                    if (-not $binding.sessionId.StartsWith($titlePrefix)) {
                        $binding.sessionId = $titlePrefix
                        $binding.model = $titleModel
                        $binding.cwd = $Path
                    }
                    # Reflect /model and /effort immediately, before another rollout event.
                    if ($titleModel -match '^(.*?)\s+(low|medium|high|xhigh|max)(?:\s|$)') {
                        $State.LiveModel = $Matches[1]
                        $State.LiveEffort = $Matches[2]
                    }
                }
            }
            if ($SessionId -ne $binding.sessionId) {
                $SessionId = $binding.sessionId
                $State.FilePath = ''
                $State.Used = $null
                $State.Window = $null
                $State.Primary = $null
                $State.Secondary = $null
                $State.PrimaryReset = $null
                $State.SecondaryReset = $null
                $State.Model = if ($binding.model) { $binding.model } else { 'Codex' }
                if ($binding.model -match '^(.*?)\s+(low|medium|high|xhigh|max)(?:\s|$)') {
                    $State.Model = $Matches[1]; $State.Effort = $Matches[2]
                } else { $State.Effort = '' }
                $State.Cwd = $binding.cwd
            }
            $Path = if ($State.Cwd) { $State.Cwd } else { $binding.cwd }
        }
        Render-Status $Path
        if ($Watch) { Start-Sleep -Seconds ([Math]::Max(1, $IntervalSeconds)) }
    } while ($Watch)
} finally {
    if ($Watch) { [Console]::Write("$Esc[?25h") }
}
