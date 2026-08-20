# Claude Code statusline script
# Prints a 4-line status string for Claude Code's UI (no time/clock field):
#   line 1: ◆ model │ ◇ eff (ultracode 検出あり) │ +/- lines  [vim]
#   line 2: ◈ ctx │ ◐ 5h ↺reset  ◑ 7d ↺reset  ◒ F5 ↺reset
#   line 3: ▸ dir
#   line 4: ⎇ branch status
# Stacked vertically (was 2 lines until 2026-08-20) so heavily split WezTerm panes
# never cut off the right-hand segments. Rows with no content are dropped entirely.
# Reads JSON from stdin (UTF-8). Also writes a legacy statusline_input.json dump
# (no live reader since the WezTerm display layer was retired — see statusline-spec.md).

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
$ORANGE = "${ESC}[38;2;239;159;118m"   # #ef9f76 peach vim mode / xhigh effort

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

# --- Legacy dump: kept for backward-compat only; no live reader since the
#     WezTerm display layer was retired (see statusline-spec.md 技術的負債) ---
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

# --- 3a. ultracode 判定（statusLine payload には載らないので transcript から読む）---
# claude.exe 2.1.236 の payload ビルダーを直接確認した結果:
#   ...FD(_)&&{effort:{level:NK(_,m)}}   / 値は low|medium|high|xhigh|max のみ
# ultracode は内部エイリアス表 {ultracode:"xhigh"} で **xhigh に潰されてから** payload に載る。
# 環境変数 CLAUDE_EFFORT も同じ潰れた値（実測 "high"）で、*ULTRACODE* 系の env は binary に皆無。
# ＝ payload / env からの判定は構造的に不可能。
#
# 唯一の確実な足跡は **transcript の attachment レコード**:
#   {"attachment":{"type":"ultra_effort_enter","reminderType":"full"},"type":"attachment",...}
#   {"attachment":{"type":"ultra_effort_exit"},"type":"attachment",...}
# claude 本体が毎プロンプト送信時に真の述語 Sse(model,effort,ultracode) から書き出す。
# **ファイル内で最後に現れた方が現在状態**（enter=ON / exit=OFF / 無し=OFF）。
# ユーザーの transcript 2808 本に実レコード 258 件を確認（2.1.220+）。sidechain には出ない。
#
# 補助アンカー: /effort の実行結果（<local-command-stdout>）。`/effort xhigh` で ultracode が
# 切れた瞬間は次のプロンプトまで exit レコードが書かれないので、その窓を塞ぐ。
#
# 誤検出防止（重要）: アンカーは **エスケープされていない生 JSON の部分文字列**。ツール出力に
# 同じ語が出ても JSON 内では \"attachment\" とエスケープされるので絶対に一致しない
# （本セッションの transcript には "Ultracode is on:" 等が実在するが off と正しく出る）。
#
# 3 つの AND ゲート。1 つでも欠けたら素の effort 表示に落とす（**嘘は絶対に出さない**）:
#   1. payload の effort.level が "xhigh"
#   2. 一致行の sessionId が payload の session_id と同じ
#   3. 一致行の timestamp が **このプロセスの startedAt 以降**
#      （transcript は --continue で追記され続けるため、再起動前の enter を拾わない）
#      startedAt は ~/.claude/sessions/$env:CLAUDE_PID.json から取る（CLAUDE_PID は
#      claude が子プロセスへ注入する。実測 CLAUDE_PID=38304 → sessions/38304.json）
#
# 注意（陳腐化リスク）: attachment レコードの形は claude 内部実装であり公開仕様ではない。
# 将来変わっても **静かに xhigh 表示へ縮退するだけ**で誤表示にはならない。次回監査時に
# claude.exe 実体で再確認すること。詳細は statusline-spec.md。
function Test-Ultracode($payload) {
    # --- gate 1: xhigh 以外なら ultracode ではありえない（＝ファイルを 1 バイトも読まない）---
    try {
        if ($payload.effort.level -ne "xhigh") { return $false }
    } catch { return $false }

    $tp  = $payload.transcript_path
    $sid = $payload.session_id
    if ([string]::IsNullOrWhiteSpace($tp) -or [string]::IsNullOrWhiteSpace($sid)) { return $false }
    if (-not (Test-Path -LiteralPath $tp)) { return $false }

    # --- gate 3 の材料: このプロセスの起動時刻（取れなければ判定しない）---
    $startedAt = 0
    try {
        if (-not [string]::IsNullOrWhiteSpace($env:CLAUDE_PID)) {
            $sf = Join-Path $env:USERPROFILE ".claude\sessions\$($env:CLAUDE_PID).json"
            if (Test-Path -LiteralPath $sf) {
                $sj = Get-Content -LiteralPath $sf -Raw -ErrorAction Stop | ConvertFrom-Json
                if ($sj.sessionId -eq $sid) { $startedAt = [double]$sj.startedAt }
            }
        }
    } catch {}
    if ($startedAt -le 0) { return $false }

    # --- 1 パス走査して「最後に一致した行」を残す ---
    # 実測: 約 2.9ms/MB（典型的な 0.6MB なら 数 ms、本環境最大の 126MB フルスキャンで 365ms）。
    # 末尾ウィンドウ読みは古い enter を取り逃す（=xhigh に縮退）ので原則フルスキャン。
    # 40MB 超の異常サイズの時だけ末尾 32MB に切って ~120ms 以内に押さえる。
    # 方向は安全側: ウィンドウは常に EOF 側なので、見逃すのは古いレコードだけ。
    # （新しい exit を見逃して ON と誤報することは構造上起きない）
    $last = $null
    try {
        $fi   = Get-Item -LiteralPath $tp -ErrorAction Stop
        $skip = 0
        if ($fi.Length -gt 40MB) { $skip = $fi.Length - 32MB }
        # claude が追記中でも開けるよう ReadWrite 共有
        $fs = [System.IO.File]::Open($tp, [System.IO.FileMode]::Open,
                                     [System.IO.FileAccess]::Read,
                                     [System.IO.FileShare]::ReadWrite)
        try {
            if ($skip -gt 0) { [void]$fs.Seek($skip, [System.IO.SeekOrigin]::Begin) }
            $sr = New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::UTF8)
            if ($skip -gt 0) { [void]$sr.ReadLine() }   # 途中から読んだ 1 行目は捨てる
            while ($null -ne ($line = $sr.ReadLine())) {
                if ($line.Contains('"attachment":{"type":"ultra_effort_') -or
                    $line.Contains('"content":"<local-command-stdout>Set effort level to ') -or
                    $line.Contains('"content":"<local-command-stdout>Effort level set to auto') -or
                    $line.Contains('"content":"<local-command-stdout>Cleared effort from settings') -or
                    $line.Contains('"content":"<local-command-stdout>Current effort level: ')) {
                    $last = $line
                }
            }
        } finally { $fs.Dispose() }
    } catch { return $false }
    if ($null -eq $last) { return $false }

    # --- gate 2 / gate 3 の検証 ---
    if ($last -notmatch '"sessionId":"([^"]+)"') { return $false }
    if ($Matches[1] -ne $sid) { return $false }
    if ($last -notmatch '"timestamp":"([^"]+)"') { return $false }
    try { $ts = [DateTimeOffset]::Parse($Matches[1]).ToUnixTimeMilliseconds() } catch { return $false }
    if ($ts -lt $startedAt) { return $false }

    # --- 判定 ---
    if ($last -match '"attachment":\{"type":"ultra_effort_(enter|exit)"') {
        return ($Matches[1] -eq "enter")
    }
    if ($last -match '"content":"<local-command-stdout>([^<"]*)') {
        $msg = $Matches[1]
        return ($msg.StartsWith("Set effort level to ultracode") -or
                $msg.StartsWith("Current effort level: ultracode"))
    }
    return $false
}

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
        # ultracode は payload 上 "xhigh" としてしか見えないので、
        # xhigh の時だけ追加判定を走らせる（他のレベルではファイルを一切読まない）。
        if ($lvl -eq "xhigh" -and (Test-Ultracode $data)) {
            $lvl = "ultracode"
            $ec  = $RED
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
        # --- Premium-model weekly limit (Fable 5 / Opus / Sonnet) — forward-compatible ---
        # NOT emitted by the statusLine payload as of Claude Code 2.1.216 (only five_hour /
        # seven_day are; verified against the claude.exe rate_limits builder). The value DOES
        # exist inside Claude from the `anthropic-ratelimit-unified-7d_oi-*` response headers
        # and is labeled "Fable 5 limit" internally (key seven_day_overage_included; siblings
        # seven_day_opus="Opus limit" / seven_day_sonnet="Sonnet limit"). This block reads it
        # defensively: dormant today (field absent → nothing renders), it lights up the moment
        # a future Claude Code version starts including a premium-weekly key in the payload.
        # First present key wins (priority order). See statusline-spec.md.
        $premiumKeys = @(
            @{ key = "seven_day_overage_included"; label = "F5" },  # current plan = "Fable 5 limit"
            @{ key = "seven_day_opus";             label = "Op" },
            @{ key = "seven_day_sonnet";           label = "So" }
        )
        foreach ($pk in $premiumKeys) {
            $node = $data.rate_limits.($pk.key)
            if ($null -ne $node -and $null -ne $node.used_percentage) {
                $u = [math]::Round($node.used_percentage)
                $c = Get-StageColor $u
                $r = Format-ResetIn $node.resets_at
                $resetIn = if ($r -ne "") { "${DIM}↺${r}" } else { "" }
                $parts5h += ("${DIM}◒ $($pk.label):${c}${u}% ${resetIn}").TrimEnd() + $RESET
                break
            }
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

# --- Assemble (4-line layout, colored text only) ---
# WezTerm を細かくペイン分割しても右端が切れないよう、1 行を短く保つ縦積み構成:
#   1: ◆ model │ ◇ eff │ +/- lines   (ランタイムの「今の設定」系)
#   2: ◈ ctx │ ◐ 5h ◑ 7d ◒ F5        (残量メーター系を一行に集約)
#   3: ▸ dir
#   4: ⎇ branch status
# 中身が空の行は出力しない（無駄な空行でペインの縦幅を食わない）ので、
# 実際の行数はペイロード次第で 4 行以下になる。dir / branch は従来通り無着色。
$sep = "${DIM} │ ${RESET}"

# 空でないセグメントだけを " │ " で繋ぐ（先頭・末尾の孤立したセパレータを作らない）
function Join-Segments([string[]]$segments) {
    $kept = @($segments | Where-Object { -not [string]::IsNullOrEmpty($_) })
    if ($kept.Count -eq 0) { return "" }
    return ($kept -join $sep)
}

$rows = New-Object System.Collections.Generic.List[string]

# 1) model │ effort │ 編集行数（+ vim モードは末尾に直付け）
$rows.Add((Join-Segments @("${PURPLE}◆ ${modelName}${RESET}", $effortStr, $linesStr)) + $vimStr + $RESET)

# 2) ctx │ 使用制限（5h / 7d / premium 週間）
$row = Join-Segments @($ctxStr, $rateLimitStr)
if ($row -ne "") { $rows.Add($row + $RESET) }

# 3) directory
$rows.Add("▸ $dirStr" + $RESET)

# 4) git branch + status
if ($gitBranch -ne "") { $rows.Add("⎇ $gitBranch$gitStatus" + $RESET) }

foreach ($row in $rows) { Write-Output $row }
