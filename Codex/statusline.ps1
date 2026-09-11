# Codex statusline monitor for a dedicated WezTerm pane.
# Codex does not expose Claude's statusLine.command callback, so this renderer
# reads the active Codex rollout JSONL and renders the same four information rows.
[CmdletBinding()]
param(
    [string]$Path = (Get-Location).Path,
    [switch]$Watch,
    [int]$IntervalSeconds = 2
)

$ErrorActionPreference = 'SilentlyContinue'
$Esc = [char]27
$Reset = "$Esc[0m"
$Dim = "$Esc[38;2;115;121;148m"
$Green = "$Esc[38;2;166;209;137m"
$Teal = "$Esc[38;2;129;200;190m"
$Mauve = "$Esc[38;2;202;158;230m"
$Peach = "$Esc[38;2;239;159;118m"
$Yellow = "$Esc[38;2;229;200;144m"
$Red = "$Esc[38;2;231;130;132m"

function Format-Reset([object]$Epoch) {
    if (-not $Epoch) { return '' }
    $seconds = [int64]$Epoch - [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    if ($seconds -le 0) { return '' }
    $span = [TimeSpan]::FromSeconds($seconds)
    if ($span.TotalDays -ge 1) { return ('↺{0}d{1}h' -f [int]$span.TotalDays, $span.Hours) }
    if ($span.TotalHours -ge 1) { return ('↺{0}h{1}m' -f [int]$span.TotalHours, $span.Minutes) }
    return ('↺{0}m' -f [Math]::Max(1, [int]$span.TotalMinutes))
}

function Join-Segments([string[]]$Segments) {
    return (($Segments | Where-Object { $_ }) -join " $Dim│$Reset ")
}

function Find-Rollout([string]$Cwd) {
    $root = Join-Path $env:USERPROFILE '.codex\sessions'
    $normalized = [IO.Path]::GetFullPath($Cwd).TrimEnd('\').ToLowerInvariant()
    foreach ($file in (Get-ChildItem -LiteralPath $root -Recurse -File -Filter 'rollout-*.jsonl' | Sort-Object LastWriteTime -Descending | Select-Object -First 30)) {
        $first = Get-Content -LiteralPath $file.FullName -TotalCount 1
        if (-not $first) { continue }
        try { $meta = $first | ConvertFrom-Json } catch { continue }
        if ($meta.payload.cwd -and ([IO.Path]::GetFullPath($meta.payload.cwd).TrimEnd('\').ToLowerInvariant() -eq $normalized)) { return $file }
    }
    return $null
}

function Render-Status {
    param([string]$Cwd)
    $file = Find-Rollout $Cwd
    $model = 'Codex'
    $effort = ''
    $used = $null
    $window = $null
    $primary = $null
    $secondary = $null
    $primaryReset = ''
    $secondaryReset = ''

    if ($file) {
        $lines = Get-Content -LiteralPath $file.FullName -Tail 40 | Where-Object {
            $_ -match '"type":"token_count"' -or $_ -match '"type":"turn_context"' -or $_ -match '"type":"session_meta"'
        }
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

    $line1 = Join-Segments @("$Mauve◆ $model$Reset", $(if ($effort) { "$Peach◇ eff:$effort$Reset" }))
    if ($used -ne $null -and $window) {
        $pct = [Math]::Round(([double]$used / [double]$window) * 100)
        $ctxColor = if ($pct -ge 80) { $Red } elseif ($pct -ge 50) { $Yellow } else { $Green }
        $line2 = Join-Segments @("$Teal◈ ctx:$ctxColor${pct}%$Reset", $(if ($primary -ne $null) { "$Dim◐ 5h:$primary% $primaryReset$Reset" }), $(if ($secondary -ne $null) { "$Dim◑ 7d:$secondary% $secondaryReset$Reset" }))
    } else { $line2 = "$Teal◈ ctx:$Dim unavailable$Reset" }
    $line3 = "$Dim▸ $Cwd$Reset"
    $branch = git -C $Cwd --no-optional-locks rev-parse --abbrev-ref HEAD 2>$null
    $dirty = git -C $Cwd --no-optional-locks status --porcelain 2>$null
    $git = if ($branch) { "$branch $(if ($dirty) { '!?'} else { '' })" } else { 'not a git repository' }
    $line4 = "$Dim⎇ $git$Reset"
    [Console]::WriteLine("$line1`n$line2`n$line3`n$line4")
}

do {
    if ($Watch) { [Console]::Write("$Esc[2J$Esc[H") }
    Render-Status $Path
    if ($Watch) { Start-Sleep -Seconds ([Math]::Max(1, $IntervalSeconds)) }
} while ($Watch)
