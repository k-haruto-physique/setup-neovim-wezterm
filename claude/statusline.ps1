# Claude Code statusline script
# Mirrors Starship layout: [ dir ][ branch status ] | model | ctx | time
# Reads JSON from stdin, dumps it to statusline_input.json for WezTerm, then
# prints a single-line status string for Claude Code's UI.
# starship.toml reference:
#   left  - [directory][ git_branch ][ git_status ]
#   right - model (Claude-specific) | context (Claude-specific) | time (%R)

# Read stdin (Claude's JSON) as UTF-8 FIRST — before touching any Console encoding.
# Root cause of "N of M panes show blank / ◆ Claude ▸ ?": setting [Console]::InputEncoding while
# stdin is redirected/piped makes the subsequent stdin read return 0 bytes (or, with the old
# unguarded setter, throws and blanks the line). We decode input ourselves here, so we never set
# InputEncoding at all. (Verified: identical read WITHOUT the InputEncoding set returns the full
# payload; WITH it, 0 bytes.)
$raw = ""
try {
    $stdin  = [Console]::OpenStandardInput()
    $reader = New-Object System.IO.StreamReader($stdin, [System.Text.Encoding]::UTF8)
    $raw    = $reader.ReadToEnd()
    $reader.Dispose()
} catch {
    $raw = ""
}
# NOTE: deliberately NO reference to the automatic $input variable anywhere in this script.
# Merely mentioning $input makes PowerShell pre-drain stdin into it at startup, after which
# [Console]::OpenStandardInput() reads 0 bytes -> the "◆ Claude / ▸ ?" fallback on every pane.

# Only NOW make stdout UTF-8 so Nerd Font glyphs survive on Japanese Windows (default CP932 would
# mangle them). Guarded: the setter can throw with piped stdout (no real console); never abort.
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
try { $OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

# --- ANSI 24-bit colors (Catppuccin Frappe palette — Mocha の落ち着き版) ---
# Frappe は Mocha より彩度・明度を抑えた公式バリアントで、長時間見ても疲れにくい
# とされる。色相関係は同じなのでセマンティクスは維持される。
$ESC    = [char]27
$RESET  = "${ESC}[0m"
$DIM    = "${ESC}[38;2;115;121;148m"   # #737994 overlay0 sep/brackets/labels
$GREEN  = "${ESC}[38;2;166;209;137m"   # #a6d189 git / safe
$YELLOW = "${ESC}[38;2;229;200;144m"   # #e5c890 warn 50-80%
$RED    = "${ESC}[38;2;231;130;132m"   # #e78284 danger >=80%
$BLUE   = "${ESC}[38;2;140;170;238m"   # #8caaee dir
$PURPLE = "${ESC}[38;2;202;158;230m"   # #ca9ee6 mauve model
$TEAL   = "${ESC}[38;2;129;200;190m"   # #81c8be ctx label
$ORANGE = "${ESC}[38;2;239;159;118m"   # #ef9f76 peach vim / git status

function Get-StageColor([double]$pct) {
    if ($pct -ge 80) { return $RED }
    if ($pct -ge 50) { return $YELLOW }
    return $GREEN
}

# rate_limits.*.resets_at (Unix epoch seconds) -> remaining time.
#   >=1d : "3d3h"  (7d window reads naturally in days)
#   >=1h : "2h13m"
#   else : "47m"
# Empty string if absent or already past (so it just drops out of the line).
function Format-ResetIn($resetsAt) {
    if ($null -eq $resetsAt) { return "" }
    try {
        $now    = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        $remain = [int64]$resetsAt - [int64]$now
        if ($remain -le 0) { return "" }
        $d = [math]::Floor($remain / 86400)
        $h = [math]::Floor(($remain % 86400) / 3600)
        $m = [math]::Floor(($remain % 3600) / 60)
        if ($d -gt 0) { return "${d}d${h}h" }
        if ($h -gt 0) { return "${h}h${m}m" }
        return "${m}m"
    } catch { return "" }
}

# --- Dump raw stdin so WezTerm-side reader (wezterm.lua) can pick it up ---
# Failure here must never block the statusline output.
if (-not [string]::IsNullOrWhiteSpace($raw)) {
    try {
        Set-Content -Path "C:\Users\81809\.claude\statusline_input.json" `
                    -Value $raw -Encoding utf8 -NoNewline -ErrorAction Stop
    } catch {}
}

# Best-effort invocation log
try {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path "C:\Users\81809\.claude\statusline_debug.log" `
                -Value "[$ts] CALLED stdin_len=$($raw.Length) ps=$($PSVersionTable.PSVersion)" `
                -ErrorAction SilentlyContinue
} catch {}

# Parse JSON; tolerate empty / invalid payloads so we never go silent.
$data = $null
if (-not [string]::IsNullOrWhiteSpace($raw)) {
    try { $data = $raw | ConvertFrom-Json } catch {}
}

# --- 1. Directory (Starship [directory] truncation_length=10, truncate_to_repo=false) ---
$dirStr = ""
try {
    $cwd = $null
    if ($null -ne $data) {
        if ($null -ne $data.workspace) { $cwd = $data.workspace.current_dir }
        if ([string]::IsNullOrWhiteSpace($cwd)) { $cwd = $data.cwd }
    }
    if (-not [string]::IsNullOrWhiteSpace($cwd)) {
        $userHome = $env:USERPROFILE
        if ($cwd.StartsWith($userHome)) {
            $cwd = "~" + $cwd.Substring($userHome.Length)
        }
        $parts = ($cwd -replace '\\', '/') -split '/' | Where-Object { $_ -ne "" }
        if ($parts.Count -gt 10) {
            $parts = $parts | Select-Object -Last 10
            $dirStr = ".../" + ($parts -join "/")
        } else {
            $dirStr = $cwd -replace '\\', '/'
        }
    }
} catch {}
if ([string]::IsNullOrWhiteSpace($dirStr)) { $dirStr = "?" }

# --- 2. Git branch + status (Starship [git_branch] + [git_status] $all_status) ---
$gitBranch = ""
$gitStatus = ""
try {
    $cwd2 = $null
    if ($null -ne $data) {
        if ($null -ne $data.workspace) { $cwd2 = $data.workspace.current_dir }
        if ([string]::IsNullOrWhiteSpace($cwd2)) { $cwd2 = $data.cwd }
    }
    if (-not [string]::IsNullOrWhiteSpace($cwd2) -and (Test-Path $cwd2)) {
        Push-Location $cwd2
        try {
            $branch = git --no-optional-locks rev-parse --abbrev-ref HEAD 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($branch)) {
                $gitBranch = $branch

                $porcelain = git --no-optional-locks status --porcelain 2>$null
                $symbols = ""
                if ($porcelain) {
                    $lines = $porcelain -split "`n" | Where-Object { $_ -ne "" }
                    $hasConflict  = $lines | Where-Object { $_ -match '^(DD|AU|UD|UA|DU|AA|UU)' }
                    $hasStaged    = $lines | Where-Object { $_ -match '^[MADRC][ ?]' -or $_ -match '^[MADRC][MADRC]' }
                    $hasModified  = $lines | Where-Object { $_ -match '^[ MADRC][MD]' }
                    $hasUntracked = $lines | Where-Object { $_ -match '^\?\?' }
                    $hasDeleted   = $lines | Where-Object { $_ -match '^[ MADRC]D' }
                    if ($hasConflict)  { $symbols += "=" }
                    if ($hasStaged)    { $symbols += "+" }
                    if ($hasModified)  { $symbols += "!" }
                    if ($hasUntracked) { $symbols += "?" }
                    if ($hasDeleted)   { $symbols += "x" }
                }

                $aheadBehind = git --no-optional-locks rev-list --left-right --count "@{upstream}...HEAD" 2>$null
                if ($LASTEXITCODE -eq 0 -and $aheadBehind) {
                    $abParts = $aheadBehind -split '\s+'
                    $behind = [int]$abParts[0]
                    $ahead  = [int]$abParts[1]
                    if ($behind -gt 0) { $symbols += "v$behind" }
                    if ($ahead  -gt 0) { $symbols += "^$ahead" }
                }

                if ($symbols -ne "") { $gitStatus = " $symbols" }
            }
        } finally {
            Pop-Location
        }
    }
} catch {}

# --- 3. Model display name ---
$modelName = ""
try {
    if ($null -ne $data -and $null -ne $data.model) {
        $modelName = $data.model.display_name
        if ([string]::IsNullOrWhiteSpace($modelName)) { $modelName = $data.model.id }
    }
} catch {}
if ([string]::IsNullOrWhiteSpace($modelName)) { $modelName = "Claude" }

# --- 3b. Reasoning effort level (absent if the model doesn't support effort) ---
# data.effort.level: low / medium / high / xhigh / max — reflects live /effort changes.
# Colored by "compute intensity" using the same green→yellow→red ramp as ctx.
$effortStr = ""
try {
    if ($null -ne $data -and $null -ne $data.effort -and -not [string]::IsNullOrWhiteSpace($data.effort.level)) {
        $lvl = $data.effort.level
        switch ($lvl) {
            "low"    { $ec = $DIM }
            "medium" { $ec = $GREEN }
            "high"   { $ec = $YELLOW }
            "xhigh"  { $ec = $ORANGE }
            "max"    { $ec = $RED }
            default  { $ec = $DIM }
        }
        $effortStr = "${DIM}◇ eff:${ec}${lvl}${RESET}"
    }
} catch {}

# --- 4. Context window USED % ---
$ctxStr = ""
try {
    if ($null -ne $data -and $null -ne $data.context_window) {
        $used    = $data.context_window.used_percentage
        $winSize = $data.context_window.context_window_size

        if ($null -ne $used) {
            $usedRounded = [math]::Round($used)
            $stageColor  = Get-StageColor $usedRounded
            $sizeLabel = ""
            if ($null -ne $winSize) {
                if ($winSize -ge 1000000) {
                    $sizeLabel = "/{0:0.#}M" -f ($winSize / 1000000)
                } elseif ($winSize -ge 1000) {
                    $sizeLabel = "/{0:0}K" -f ($winSize / 1000)
                }
            }
            $ctxStr = "${TEAL}◈ ctx:${stageColor}${usedRounded}%${DIM}${sizeLabel}${RESET}"
        } elseif ($null -ne $winSize) {
            $sizeOnly = ""
            if ($winSize -ge 1000000) {
                $sizeOnly = "{0:0.#}M" -f ($winSize / 1000000)
            } elseif ($winSize -ge 1000) {
                $sizeOnly = "{0:0}K" -f ($winSize / 1000)
            } else {
                $sizeOnly = "$winSize"
            }
            $ctxStr = "${TEAL}◈ ctx:${RESET}${sizeOnly}"
        }
    }
} catch {}

# --- 5. Rate limits (show USED %, value colored by used level) ---
$rateLimitStr = ""
try {
    if ($null -ne $data -and $null -ne $data.rate_limits) {
        $parts5h = @()
        $fiveHour = $data.rate_limits.five_hour
        $sevenDay = $data.rate_limits.seven_day
        # NOTE: do NOT name a local var $reset — PowerShell vars are case-insensitive
        # so it would clobber the ANSI $RESET constant and leak into every line.
        if ($null -ne $fiveHour -and $null -ne $fiveHour.used_percentage) {
            $u = [math]::Round($fiveHour.used_percentage)
            $c = Get-StageColor $u
            $r = Format-ResetIn $fiveHour.resets_at
            $resetIn = if ($r -ne "") { "${DIM}↺${r}" } else { "" }
            $parts5h += ("${DIM}◐ 5h:${c}${u}% ${resetIn}").TrimEnd() + $RESET
        }
        if ($null -ne $sevenDay -and $null -ne $sevenDay.used_percentage) {
            $u = [math]::Round($sevenDay.used_percentage)
            $c = Get-StageColor $u
            $r = Format-ResetIn $sevenDay.resets_at
            $resetIn = if ($r -ne "") { "${DIM}↺${r}" } else { "" }
            $parts5h += ("${DIM}◑ 7d:${c}${u}% ${resetIn}").TrimEnd() + $RESET
        }
        if ($parts5h.Count -gt 0) {
            $rateLimitStr = $parts5h -join " "
        }
    }
} catch {}

# --- 5b. Lines edited this session (cost.total_lines_added / removed) ---
$linesStr = ""
try {
    if ($null -ne $data -and $null -ne $data.cost) {
        $lp = @()
        $add = $data.cost.total_lines_added
        $del = $data.cost.total_lines_removed
        if ($null -ne $add -and [int]$add -gt 0) { $lp += "${GREEN}+$([int]$add)${RESET}" }
        if ($null -ne $del -and [int]$del -gt 0) { $lp += "${RED}-$([int]$del)${RESET}" }
        if ($lp.Count -gt 0) { $linesStr = $lp -join " " }
    }
} catch {}

# --- 6. Vim mode ---
$vimStr = ""
try {
    if ($null -ne $data -and $null -ne $data.vim -and -not [string]::IsNullOrWhiteSpace($data.vim.mode)) {
        $vimStr = " ${ORANGE}[$($data.vim.mode)]${RESET}"
    }
} catch {}

# --- Assemble (2-line layout, colored text only) ---
# Line 1: model │ eff │ ctx │ 5h │ 7d │ +/-lines  [vim]
# Line 2: [ dir ][  branch status ]
$sep = "${DIM} │ ${RESET}"

$line1 = "${PURPLE}◆ ${modelName}${RESET}"
if ($effortStr -ne "")    { $line1 += "${sep}${effortStr}" }
if ($ctxStr -ne "")       { $line1 += "${sep}${ctxStr}" }
if ($rateLimitStr -ne "") { $line1 += "${sep}${rateLimitStr}" }
if ($linesStr -ne "")     { $line1 += "${sep}${linesStr}" }
$line1 += $vimStr

$line2 = "▸ $dirStr"
if ($gitBranch -ne "") {
    $line2 += "  ⎇ $gitBranch$gitStatus"
}

Write-Output ($line1 + $RESET)
Write-Output ($line2 + $RESET)
