# Codex statusline monitor for a dedicated WezTerm pane.
# Codex does not expose Claude's statusLine.command callback, so this renderer
# reads the active Codex rollout JSONL and renders the same four information rows.
[CmdletBinding()]
param(
    [string]$Path = (Get-Location).Path,
    [string]$SessionId,
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

function Find-Rollout([string]$Cwd) {
    $root = Join-Path $env:USERPROFILE '.codex\sessions'
    if ($SessionId) {
        if ($SessionId -notmatch '^[0-9a-fA-F-]{36}$') { return $null }
        return Get-ChildItem -LiteralPath $root -Recurse -File -Filter "rollout-*-$SessionId.jsonl" | Select-Object -First 1
    }
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
$configPath = Join-Path $env:USERPROFILE '.codex\config.toml'
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
            $used = $null
            $window = $null
        }
        $lines = Read-StatusEvents $file.FullName $maximumBytes
        foreach ($line in $lines) {
            try { $event = $line | ConvertFrom-Json } catch { continue }
            if ($event.type -eq 'session_meta' -and $event.payload.model_provider) { $model = if ($event.payload.model) { $event.payload.model } else { $model } }
            if ($event.type -eq 'turn_context') {
                if ($event.payload.model) { $model = $event.payload.model }
                if ($event.payload.effort) { $effort = $event.payload.effort }
            }
            if ($event.type -eq 'event_msg' -and $event.payload.type -eq 'token_count') {
                $used = if ($event.payload.info.last_token_usage.input_tokens) {
                    [double]$event.payload.info.last_token_usage.input_tokens + [double]$event.payload.info.last_token_usage.output_tokens
                } else { $event.payload.info.total_token_usage.total_tokens }
                $window = $event.payload.info.model_context_window
                $primary = $event.payload.rate_limits.primary.used_percent
                $secondary = $event.payload.rate_limits.secondary.used_percent
                $primaryReset = Format-Reset $event.payload.rate_limits.primary.resets_at
                $secondaryReset = Format-Reset $event.payload.rate_limits.secondary.resets_at
            }
        }
    }

    $State.Model = $model
    $State.Effort = $effort
    $State.Used = $used
    $State.Window = $window
    $State.Primary = $primary
    $State.Secondary = $secondary
    $State.PrimaryReset = $primaryReset
    $State.SecondaryReset = $secondaryReset

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
        Render-Status $Path
        if ($Watch) { Start-Sleep -Seconds ([Math]::Max(1, $IntervalSeconds)) }
    } while ($Watch)
} finally {
    if ($Watch) { [Console]::Write("$Esc[?25h") }
}
