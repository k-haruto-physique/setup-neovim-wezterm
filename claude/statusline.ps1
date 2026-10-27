# Claude Code statusline script
# Prints a 4-line status string for Claude Code's UI (no time/clock field):
#   line 1: ◆ model │ ◇ eff:段[+ultracode] │ +/- lines  [vim]
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
# 2.1.284 から ultracode は effort の別名（旧: {ultracode:"xhigh"} で xhigh に潰れる一段）ではなく、
# **effort とは別のセッション単位のオンオフ**になった（/effort ultracode [on|off]・/effort の Tab）。
# 段は変わらない（"Ultracode on (this session only): … Effort stays high."）＝**どの段でも ON になりうる**。
# claude.exe 2.1.304 の payload ビルダーは今も ...KS(He)&&{effort:{level:m2(He,be)}} の 1 キーだけで
# ultracode の欄は無い。CLAUDE_EFFORT は段の写し、~/.claude/sessions/<pid>.json にも無い。
# ＝ payload / env からの判定は今も構造的に不可能。
#
# 確実な足跡は **transcript の attachment レコード**（本体の zIr が人のプロンプトの直後に書く）:
#   {"attachment":{"type":"ultra_effort_enter","reminderType":"full"|"sparse"},"type":"attachment",...}
#   {"attachment":{"type":"ultra_effort_exit"},"type":"attachment",...}
# 元の値は vg(ultracode, model)＝「要求していて、実際に効いている」（モデル非対応・workflows 無効なら OFF）。
# ON の間は最後が enter でなければ enter/full・10 発言ごとに enter/sparse、OFF になったら次の
# プロンプトで exit を 1 回。sidechain（subagents/）には出ず、transcript_path の本体ファイルにだけ出る。
# zIr が走るのは普通のプロンプト（と delivered turn）だけで、スキルの起動・! の bash・ローカルの
# スラッシュコマンドでは走らない。
#
# 補助アンカー: /effort の結果（<local-command-stdout>）。切り替えた瞬間から次のプロンプトまで
# enter/exit が書かれない窓を塞ぐ。**状態が一意に決まる文言だけ**を使い、それ以外は読み飛ばす
# （前のアンカーを上書きさせない）。判定は Get-UltracodeFromStdout。人のプロンプト行は、本文が
# <local-command-stdout> で始まっても（貼り付け）stdout として読まない（本物の stdout 行に origin は付かない）。
#
# 圧縮の穴: compaction の後、本体は圧縮前の enter を忘れる。そのあと stdout の残らない経路
# （Remote Control からの effort 変更・/model で非対応モデルへ・workflows 無効化）で OFF になると
# exit が二度と書かれず、ファイル上は圧縮前の enter が最後に残る＝ON と嘘をつく。逆に ON のままなら、
# 圧縮後の最初の人のプロンプトで enter/full が必ず書き直される（実 transcript で圧縮後に人が発言した
# 22 回すべてがこの規則どおり＝21 回は直後に enter/full、1 回は再開で本当に OFF になっていた）。そこで
# compact_boundary の時点で ON なら「保留」にして ON を保ち（長いターンの途中の自動圧縮で消さない）、
# 次の人のプロンプト行（"origin":{"kind":"human"}）で OFF に倒す。ON のままならその直後の enter/full で
# ON に戻る。人のプロンプト行から除く物: attachment の入れ子（途中で送った追加メッセージ＝queued_command
# にも origin が入る）と、zIr が走らないことがある行＝スキルの起動行（"content":"<command-message>…）と
# "/" で始まる入力（コマンド名の形でない "/c/Users/…" などは添付を作らずに送られる）。除いた行では保留が続く
# （本当に OFF なら、次の普通のプロンプトまで ON が残る＝1 ターンの遅れ）。
#
# 誤検出防止（重要）: アンカーは **エスケープされていない生 JSON の部分文字列**。ツール出力に
# 同じ語が出ても JSON 内では \"attachment\" とエスケープされるので絶対に一致しない
# （ultracode を話題にした本セッションの transcript でも off と正しく出る）。
#
# 2 つの AND ゲート（アンカーの行ごと。欠けた行は無かった物として扱う＝**嘘は絶対に出さない**）:
#   1. 行の sessionId が payload の session_id と同じ
#   2. 行の timestamp が **このプロセスの startedAt 以降**
#      （transcript は --continue で追記され続け、ultracode は再開で戻らないので、再起動前の enter を拾わない）
#      startedAt は ~/.claude/sessions/$env:CLAUDE_PID.json から取る（CLAUDE_PID は claude が子プロセスへ
#      注入する。/clear 等で会話が替わると本体がこのファイルの sessionId を書き直す＝En({sessionId:…})）
# 旧ゲート「effort.level が xhigh の時だけ読む」は新仕様では成り立たないので撤去した（2026-10-20）。
#
# 読んだ所までの控え: 段を問わず毎回読むようになったので、プロセスごとに一時ファイル
# （%TEMP%\claude-statusline\uc-<CLAUDE_PID>.json）へ「どのバイトまで読んだか・その時の状態」を控え、
# 次回は追記された分だけ読む。控えた位置の直前 4KB の指紋（SHA-256）も控え、本体が行を消して詰め直した
# （墓標の削除＝performRemoveByUuid）時に、位置だけ合って中身がずれたのを見抜く（直前が改行かだけでは、
# 行末の共通の欄で偶然そろう）。控えが無い・合わない時（初回・/clear・ファイルが縮んだ・詰め直された）は
# 最初から読むが、40MB 超の時は末尾 32MB に切る。初回はプロセスの起動直後なのでゲート 2 を通る行はまだ
# 末尾にしか無く、窓で取りこぼさない。方向は安全側: 窓より前は「無かった」扱い＝始まりは OFF。
#
# 注意（陳腐化リスク）: attachment レコードと /effort の文言は claude 内部実装であり公開仕様ではない。
# 将来変わっても **静かに ultracode 無しの表示へ縮退するだけ**で誤表示にはならない。次回監査時に
# claude.exe 実体で再確認すること。詳細は statusline-spec.md。

# /effort の結果 1 行 → $true（ON）/ $false（OFF）/ $null（状態が決まらない＝読み飛ばす）。
# 2.1.304 の雛形（本体の D / V / k / p6t）:
#   ON : "Ultracode on (this session only): …" / 末尾 " · Ultracode on"（スライダーで段と同時・/effort status）
#   OFF: "Ultracode off. Effort stays …"       / 末尾 " · Ultracode off"
#        "Current effort level: …"・"Effort level: auto …"（/effort status）で " · Ultracode on" が無い
#        （status は「今効いているか」を言うので、接尾辞が無ければ OFF と決まる）
#   null: "Set effort level to …"・"Effort level set to auto"・"Cleared effort …"・"Ultracode isn't available …" ほか。
#        ローカルでは /effort <段> は ultracode を保つ（旧版はこれを OFF として扱っていた＝新仕様では誤り）。
$UC_STDOUT   = '"content":"<local-command-stdout>'
$UC_ON_TAIL  = " $([char]0x00B7) Ultracode on"
$UC_OFF_TAIL = " $([char]0x00B7) Ultracode off"
$UC_ORD      = [System.StringComparison]::Ordinal
function Get-UltracodeFromStdout([string]$line) {
    $i = $line.IndexOf($UC_STDOUT, $UC_ORD)
    if ($i -lt 0) { return $null }
    $msg = $line.Substring($i + $UC_STDOUT.Length)
    $j = $msg.IndexOf('</local-command-stdout>', $UC_ORD)
    if ($j -ge 0) { $msg = $msg.Substring(0, $j) }
    if ($msg.StartsWith("Ultracode on (", $UC_ORD) -or $msg.Contains($UC_ON_TAIL))   { return $true }
    if ($msg.StartsWith("Ultracode off.", $UC_ORD) -or $msg.Contains($UC_OFF_TAIL)) { return $false }
    if ($msg.StartsWith("Current effort level: ", $UC_ORD) -or
        $msg.StartsWith("Effort level: auto", $UC_ORD)) { return $false }
    return $null
}

# 控えた位置の直前 4KB の指紋（SHA-256・Base64）。位置 0 なら空文字。
function Get-UcTail($fs, [int64]$offset) {
    $n = [int][Math]::Min(4096, $offset)
    if ($n -le 0) { return "" }
    $b = New-Object byte[] $n
    [void]$fs.Seek($offset - $n, [System.IO.SeekOrigin]::Begin)
    $got = 0
    while ($got -lt $n) {
        $r = $fs.Read($b, $got, $n - $got)
        if ($r -le 0) { break }
        $got += $r
    }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return [Convert]::ToBase64String($sha.ComputeHash($b, 0, $got)) } finally { $sha.Dispose() }
}

# アンカーの行がこのセッション・このプロセスの物か（gate 1・2）
function Test-OwnLine([string]$line, [string]$sid, [double]$startedAt) {
    if ($line -notmatch '"sessionId":"([^"]+)"') { return $false }
    if ($Matches[1] -ne $sid) { return $false }
    if ($line -notmatch '"timestamp":"([^"]+)"') { return $false }
    try { $ts = [DateTimeOffset]::Parse($Matches[1]).ToUnixTimeMilliseconds() } catch { return $false }
    return ($ts -ge $startedAt)
}

function Test-Ultracode($payload) {
    $tp  = $payload.transcript_path
    $sid = $payload.session_id
    if ([string]::IsNullOrWhiteSpace($tp) -or [string]::IsNullOrWhiteSpace($sid)) { return $false }
    if ([string]::IsNullOrWhiteSpace($env:CLAUDE_PID)) { return $false }
    if (-not (Test-Path -LiteralPath $tp -PathType Leaf)) { return $false }

    # --- 読んだ所までの控え（無い・壊れていれば $null）---
    # 値の形まで確かめる（壊れた値のまま進むと外側の catch に落ち、控えを書き直せずに OFF が続く）
    $cacheDir  = Join-Path ([System.IO.Path]::GetTempPath()) "claude-statusline"
    $cachePath = Join-Path $cacheDir "uc-$($env:CLAUDE_PID).json"
    $cache = $null
    try {
        if (Test-Path -LiteralPath $cachePath) {
            $c = Get-Content -LiteralPath $cachePath -Raw -ErrorAction Stop | ConvertFrom-Json
            if ($null -ne $c -and $c.path -is [string] -and $c.sid -is [string] -and $c.tail -is [string] -and
                $c.on -is [bool] -and $c.pending -is [bool]) {
                $cache = [pscustomobject]@{ path = $c.path; sid = $c.sid; tail = $c.tail;
                                            startedAt = [double]$c.startedAt; offset = [int64]$c.offset;
                                            on = $c.on; pending = $c.pending }
                if ($cache.offset -lt 0 -or $cache.startedAt -le 0) { $cache = $null }
            }
        }
    } catch { $cache = $null }

    # --- gate 2 の材料: このプロセスの起動時刻（取れなければ判定しない）---
    # 本体は busy/idle のたびに pid ファイルを切り詰めてから書き直す（fs/promises の writeFile）ので、
    # 書きかけ（空・途中で切れた JSON）を読んだ時だけ同じ会話の控えの値を使う（会話が違う・控えが無いなら判定しない）。
    $startedAt = 0
    $sf = Join-Path $env:USERPROFILE ".claude\sessions\$($env:CLAUDE_PID).json"
    try {
        if (Test-Path -LiteralPath $sf) {
            $pidJson = Get-Content -LiteralPath $sf -Raw -ErrorAction Stop
            if ([string]::IsNullOrWhiteSpace($pidJson)) { throw "torn pid file" }
            $sj = $pidJson | ConvertFrom-Json
            if ($null -eq $sj) { throw "torn pid file" }
            if ($sj.sessionId -eq $sid) { $startedAt = [double]$sj.startedAt }
        }
    } catch {
        if ($null -ne $cache -and $cache.sid -eq $sid) { $startedAt = [double]$cache.startedAt }
    }
    if ($startedAt -le 0) { return $false }

    $on      = $false   # ここまでで分かっている状態（アンカーが無ければ OFF）
    $pending = $false   # 圧縮の後で、次の人のプロンプトを待っている（圧縮前は ON）
    try {
        # claude が追記中でも開けるよう ReadWrite 共有
        $fs = [System.IO.File]::Open($tp, [System.IO.FileMode]::Open,
                                     [System.IO.FileAccess]::Read,
                                     [System.IO.FileShare]::ReadWrite)
        try {
            $len = $fs.Length
            # 控えが使えるか: 同じファイル・同じ会話・同じ起動で、控えた位置の直前 4KB が同じ（＝詰め直されていない）
            $start = -1
            if ($null -ne $cache -and $cache.path -eq $tp -and $cache.sid -eq $sid -and
                $cache.startedAt -eq $startedAt -and $cache.offset -le $len -and
                ($len - $cache.offset) -le 40MB -and (Get-UcTail $fs $cache.offset) -ceq $cache.tail) {
                $start   = $cache.offset
                $on      = $cache.on
                $pending = $cache.pending
            }
            # 控えが使えない時は最初から（40MB 超は末尾 32MB だけ・途中から読んだ 1 行目は捨てる）
            $dropFirst = $false
            if ($start -lt 0) {
                $start = 0
                if ($len -gt 40MB) { $start = $len - 32MB; $dropFirst = $true }
            }

            # 最後の改行までを読む（書きかけの最後の 1 行は次回に回す）
            $count = [int]($len - $start)
            $buf = New-Object byte[] $count
            [void]$fs.Seek($start, [System.IO.SeekOrigin]::Begin)
            $got = 0
            while ($got -lt $count) {
                $n = $fs.Read($buf, $got, $count - $got)
                if ($n -le 0) { break }
                $got += $n
            }
            $lastNl = [Array]::LastIndexOf($buf, [byte]10, [Math]::Max($got - 1, 0))
            if ($got -eq 0) { $lastNl = -1 }
            $done = $start
            if ($lastNl -ge 0) {
                $done = $start + $lastNl + 1
                $ms = New-Object System.IO.MemoryStream($buf, 0, $lastNl + 1)
                $sr = New-Object System.IO.StreamReader($ms, [System.Text.Encoding]::UTF8)
                if ($dropFirst) { [void]$sr.ReadLine() }
                while ($null -ne ($line = $sr.ReadLine())) {
                    # 候補の 4 種以外は Contains だけで捨てる（大半の行はここで終わる）
                    if     ($line.Contains('"attachment":{"type":"ultra_effort_')) { $kind = 1 }
                    elseif ($line.Contains('"origin":{"kind":"human"}') -and
                            -not $line.Contains('"attachment":{')) {
                        # スキルの起動・"/" で始まる入力（パスの貼り付け等）は zIr が走らないことがある＝保留を解かない
                        if ($line.Contains('"content":"<command-message>') -or
                            $line.Contains('"content":"/')) { continue }
                        $kind = 4
                    }
                    elseif ($line.Contains($UC_STDOUT))                         { $kind = 2 }
                    elseif ($line.Contains('"subtype":"compact_boundary"'))      { $kind = 3 }
                    else { continue }
                    if (-not (Test-OwnLine $line $sid $startedAt)) { continue }
                    if ($kind -eq 1) {
                        $on = $line.Contains('"attachment":{"type":"ultra_effort_enter"')
                        $pending = $false
                    } elseif ($kind -eq 2) {
                        $s = Get-UltracodeFromStdout $line
                        if ($null -ne $s) { $on = $s; $pending = $false }
                    } elseif ($kind -eq 3) {
                        if ($on) { $pending = $true }
                    } elseif ($pending) {
                        # 圧縮後の最初の人のプロンプト: ON のままならこの直後に enter/full が来る
                        $on = $false
                        $pending = $false
                    }
                }
            }
            $doneTail = Get-UcTail $fs $done
        } finally { $fs.Dispose() }
    } catch { return $false }

    # --- 控えを書く（失敗しても表示は変えない。書きかけを読まれないよう別名に書いてから置き換える）---
    try {
        if (-not (Test-Path -LiteralPath $cacheDir)) {
            [void](New-Item -ItemType Directory -Path $cacheDir -Force -ErrorAction Stop)
        }
        $json = [ordered]@{ path = $tp; sid = $sid; startedAt = $startedAt; offset = $done; tail = $doneTail;
                            on = $on; pending = $pending } | ConvertTo-Json -Compress
        $tmp = "$cachePath.$PID.tmp"
        try {
            [System.IO.File]::WriteAllText($tmp, $json)
            # 別の statusline が控えを開いている間は置き換えに失敗する（その回は控えを更新しないだけ）
            [System.IO.File]::Move($tmp, $cachePath, $true)
        } finally {
            if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
        }
        # 終わったプロセスの控え（と取り残された .tmp）は 7 日で消す（控えが無かった時だけ見る＝ふだんは一覧も取らない）
        if ($null -eq $cache) {
            Get-ChildItem -LiteralPath $cacheDir -Filter "uc-*" -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } |
                Remove-Item -Force -ErrorAction SilentlyContinue
        }
    } catch {}
    return $on
}

# xhigh に対応しないモデルでは ultracode は効かない（本体 $M＝mm() && Zgt(model)）。Zgt は設定や
# モデルの能力で上書きできるが、既定の固定表は次のとおり（2.1.304）。この表のモデルでは transcript を
# 読まずに OFF にする（本体と同じ向き＝安全側）。`/effort ultracode on` の直後にプロンプトを送らず
# /model でここへ替えると enter が一度も書かれず exit も永久に書かれない＝アンカーだけでは ON のまま残る穴を塞ぐ。
# payload の model.id は生の ID（日付・[1m]・us./global. の接頭辞・Vertex の @ が付く）。本体の正規化 CU は
# claude-opus-4 / claude-sonnet-4（後ろに -<1 桁> が続かない物＝日付つき・@ つき・単独）を 4-0 として扱う。
$UC_NO_XHIGH = 'claude-3-|claude-(opus-4-[0156]|sonnet-4-[056]|haiku-4-5)(?![0-9])|claude-(opus|sonnet)-4(?!-[0-9](?![0-9]))'

# --- 3b. Reasoning effort level (absent if the model doesn't support effort) ---
# data.effort.level: low / medium / high / xhigh / max — reflects live /effort changes.
# Colored by "compute intensity" using the same green→yellow→red ramp as ctx.
# ultracode は段とは別のオンオフ（2.1.284〜）。効いている時だけ段の後ろに "+ultracode"（赤）を付ける。
# 段の文字と色は ultracode の有無で変えない。effort に対応しないモデルは ultracode にも対応しない
# （本体の $M は xhigh 対応が条件）ので、effort が無い時は判定もしない（ファイルを読まない）。
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
        $ucStr = ""
        $mid = ""
        if ($null -ne $data.model) { $mid = "$($data.model.id)".ToLowerInvariant() }
        if ($mid -notmatch $UC_NO_XHIGH -and (Test-Ultracode $data)) { $ucStr = "${DIM}+${RED}ultracode" }
        $effortStr = "${DIM}◇ eff:${ec}${lvl}${ucStr}${RESET}"
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
            # context_guard.py（PostToolUse のフック）が読む＝フックには使用率が渡らないため
            try {
                if ($data.session_id) {
                    $ctxDir = Join-Path $env:USERPROFILE ".claude/state/ctx"
                    if (-not (Test-Path $ctxDir)) { New-Item -ItemType Directory -Path $ctxDir -Force | Out-Null }
                    $ctxObj = @{ used = $usedRounded; size = $winSize; ts = (Get-Date).ToString("s") } | ConvertTo-Json -Compress
                    Set-Content -LiteralPath (Join-Path $ctxDir "$($data.session_id).json") -Value $ctxObj -Encoding utf8 -ErrorAction SilentlyContinue
                }
            } catch {}
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
