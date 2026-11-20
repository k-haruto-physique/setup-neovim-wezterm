# agy (Antigravity CLI) statusLine adapter
# agy は statusLine の command に JSON を stdin で渡す（形は Claude Code に近いが同じではない）。
# この変換役が agy の JSON を Claude の形に直し、同じフォルダの statusline.ps1（Claude 用の正本）に
# そのまま渡して、出てきた表示を agy に返す＝表示の中身は Claude と同じ・コードは二重にならない。
#
# 変換（agy -> Claude の形）:
#   model.display_name / model.id          -> model.display_name / id（そのまま）
#   model.effort                           -> effort.level
#   context_window.*                       -> そのまま（used_percentage / context_window_size は同名）
#   workspace.current_dir / cwd            -> そのまま
#   vim.mode                               -> そのまま
#   quota.<bucket>.remaining_fraction      -> rate_limits.five_hour / seven_day の used_percentage（=1-残り）
#   quota.<bucket>.reset_in_seconds        -> resets_at（今 + 秒）
#     bucket の振り分け: id に week/7d を含む or 残り時間が 2 日超 -> seven_day・それ以外の最初 -> five_hour
#     （agy の bucket の実名は公式資料に例（gemini-weekly）しか無い＝実物を見て直す・最後の payload は
#       %TEMP%\claude-statusline\agy-last.json に残す）
#   session_id / transcript_path は渡さない（statusline.ps1 の ultracode 判定と ctx の控え書きは Claude 専用）
# agy には編集行数（+12 -3）の欄が無い＝1 段目の末尾は出ない。
# 失敗しても何か出す（変換に失敗したら元の JSON をそのまま渡す）。

$raw = ""
try {
    $stdin  = [Console]::OpenStandardInput()
    $reader = New-Object System.IO.StreamReader($stdin, [System.Text.Encoding]::UTF8)
    $raw    = $reader.ReadToEnd()
    $reader.Dispose()
} catch { $raw = "" }
# NOTE: 自動変数 $input には触れない（statusline.ps1 と同じ理由＝stdin が空になる）。

$utf8 = New-Object System.Text.UTF8Encoding($false)
try { [Console]::OutputEncoding = $utf8 } catch {}

# 最後に受け取った payload を残す（形の確かめ用・失敗は無視）
try {
    $dumpDir = Join-Path ([System.IO.Path]::GetTempPath()) "claude-statusline"
    if (-not (Test-Path -LiteralPath $dumpDir)) { New-Item -ItemType Directory -Path $dumpDir -Force | Out-Null }
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
        [System.IO.File]::WriteAllText((Join-Path $dumpDir "agy-last.json"), $raw, $utf8)
    }
} catch {}

$out = $raw
try {
    $a = $raw | ConvertFrom-Json
    $c = [ordered]@{}
    foreach ($k in 'cwd', 'workspace', 'model', 'context_window', 'vim', 'version') {
        if ($null -ne $a.$k) { $c[$k] = $a.$k }
    }
    if ($null -ne $a.model -and -not [string]::IsNullOrWhiteSpace($a.model.effort)) {
        $c['effort'] = @{ level = "$($a.model.effort)" }
    }
    # quota -> rate_limits
    if ($null -ne $a.quota) {
        $rl = [ordered]@{}
        $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        foreach ($p in $a.quota.PSObject.Properties) {
            $q = $p.Value
            if ($null -eq $q -or $q.disabled -eq $true) { continue }
            if ($null -eq $q.remaining_fraction) { continue }   # remaining_amount だけの bucket は割合にできない
            $used = [math]::Round((1.0 - [double]$q.remaining_fraction) * 100, 1)
            $secs = 0
            if ($null -ne $q.reset_in_seconds) { $secs = [int64]$q.reset_in_seconds }
            $entry = @{ used_percentage = $used; resets_at = ($now + $secs) }
            $long = ($p.Name -match 'week|7d') -or ($secs -gt 172800)
            $slot = if ($long) { 'seven_day' } else { 'five_hour' }
            if (-not $rl.Contains($slot)) { $rl[$slot] = $entry }
        }
        if ($rl.Count -gt 0) { $c['rate_limits'] = $rl }
    }
    $out = $c | ConvertTo-Json -Depth 8 -Compress
} catch { $out = $raw }

# Claude 用の statusline.ps1 へ渡す（Claude のセッションから起動されても ultracode 判定に入らないよう CLAUDE_PID を空に）
$script = Join-Path $PSScriptRoot "statusline.ps1"
try {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = (Get-Process -Id $PID).Path
    $psi.Arguments = "-NoProfile -NonInteractive -File `"$script`""
    $psi.RedirectStandardInput  = $true
    $psi.RedirectStandardOutput = $true
    $psi.StandardInputEncoding  = $utf8
    $psi.StandardOutputEncoding = $utf8
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow  = $true
    $psi.EnvironmentVariables.Remove("CLAUDE_PID")
    $proc = [System.Diagnostics.Process]::Start($psi)
    $proc.StandardInput.Write($out)
    $proc.StandardInput.Close()
    $text = $proc.StandardOutput.ReadToEnd()
    $proc.WaitForExit(4000) | Out-Null
    [Console]::Out.Write($text)
} catch {
    Write-Output "◆ agy"
}
