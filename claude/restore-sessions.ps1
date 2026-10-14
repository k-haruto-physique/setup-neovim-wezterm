# 再起動（Windows Update など）の前に開いていた Claude の会話を、WezTerm の新しいタブに開き直す。
# 2026-10-14・troubleshooting #32。profile.ps1 の `restore` から呼ぶ。控えは session-snapshot.ps1 が書く。
#
#   restore            一覧を出す → Enter で全部（外したい番号を打ってから Enter・q でやめる）
#   restore -Tabs      1 つの会話に 1 タブ（既定は 1 タブを 2×2 に割って 4 つずつ）
#   restore -PerTab 2  1 タブに 2 つずつ（左右）。1〜4
#   restore -Skip      開き直さずに、PowerShell を開くたびに出る知らせだけ消す
#   restore -Again     一度使った控えを、もう一度使う
#   restore -DryRun    開かずに、打つはずの wezterm のコマンドを出す（確かめ用）
#   restore -Yes       聞かずに全部（確かめ用）
#
# 開き直すのは claude --resume <会話の ID>。もう開いている会話は飛ばす（同じ会話を 2 つで開くと履歴が枝分かれする）。
[CmdletBinding()]
param(
    [switch]$Tabs,
    [ValidateRange(1, 4)][int]$PerTab = 4,
    [switch]$Skip,
    [switch]$Again,
    [switch]$DryRun,
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'session-common.ps1')
$PrevPath = Join-Path (Get-ClaudeStateDirectory) 'open-sessions.prev.json'

$prev = Read-ClaudeJson $PrevPath
if (-not $prev -or @($prev.sessions).Count -eq 0) {
    Write-Host '戻す物はありません（再起動の前の控えが無いか、空です）'
    return
}
$used = if ($prev.restoredAt) { $prev.restoredAt } elseif ($prev.skippedAt) { $prev.skippedAt } else { $null }
if ($used -and -not $Again) {
    Write-Host ('この控えはもう使いました（{0}）。もう一度使うなら restore -Again' -f ([datetime]$used).ToString('M/d HH:mm'))
    return
}

function Set-PrevMark([string]$Field) {
    if ($DryRun) { return }
    $h = [ordered]@{}
    foreach ($p in $prev.PSObject.Properties) {
        $h[$p.Name] = if ($p.Value -is [datetime]) { ConvertTo-ClaudeIso $p.Value } else { $p.Value }
    }
    $h[$Field] = (Get-Date).ToString('o')
    Write-ClaudeJson $PrevPath $h
}

if ($Skip) {
    Set-PrevMark 'skippedAt'
    Write-Host '知らせを消しました（控えは残っています。開き直すなら restore -Again）'
    return
}

$liveIds = @(Get-LiveClaudeSessions | ForEach-Object { $_.sessionId })
$all = @($prev.sessions)
$alreadyOpen = @($all | Where-Object { $liveIds -contains $_.sessionId })
$noDir = @($all | Where-Object { $liveIds -notcontains $_.sessionId -and -not (Test-Path -LiteralPath $_.cwd -PathType Container) })
$items = @($all | Where-Object { $liveIds -notcontains $_.sessionId -and (Test-Path -LiteralPath $_.cwd -PathType Container) })

$when = try { ([datetime]$prev.savedAt).ToString('M/d HH:mm') } catch { '?' }
if ($items.Count -eq 0) {
    Write-Host ('{0} の控えの {1} 個は、全部もう開いています' -f $when, $all.Count)
    Set-PrevMark 'restoredAt'
    return
}

Write-Host ('再起動の前（{0} の控え）に開いていた Claude の会話:' -f $when)
for ($i = 0; $i -lt $items.Count; $i++) {
    $s = $items[$i]
    $label = if ($s.name) { $s.name } else { '（名前なし）' }
    Write-Host ('  {0,2}  {1,-34} {2}' -f ($i + 1), $label, (Split-Path $s.cwd -Leaf))
}
if ($alreadyOpen.Count -gt 0) { Write-Host ('  （ほかの {0} 個は、もう開いているので飛ばします）' -f $alreadyOpen.Count) -ForegroundColor DarkGray }
foreach ($s in $noDir) { Write-Host ('  （{0} はフォルダ {1} が無いので飛ばします）' -f $s.name, $s.cwd) -ForegroundColor DarkGray }

$chosen = $items
if (-not $Yes) {
    $ans = (Read-Host 'Enter＝全部開く ／ 外す番号を空白で区切って打つ（例: 2 5）→ Enter ／ q＝やめる').Trim()
    if ($ans -eq 'q') { Write-Host 'やめました（知らせは残します）'; return }
    if ($ans) {
        $drop = @()
        foreach ($tok in ($ans -split '[\s,、]+')) {
            if (-not $tok) { continue }
            $n = 0
            if (-not [int]::TryParse($tok, [ref]$n) -or $n -lt 1 -or $n -gt $items.Count) {
                Write-Host "「$tok」は一覧の番号ではありません。もう一度 restore から" -ForegroundColor Yellow
                return
            }
            $drop += ($n - 1)
        }
        $chosen = @(for ($i = 0; $i -lt $items.Count; $i++) { if ($drop -notcontains $i) { $items[$i] } })
    }
}
if ($chosen.Count -eq 0) { Write-Host '開く物がありません'; Set-PrevMark 'restoredAt'; return }

$wez = (Get-Command wezterm -ErrorAction SilentlyContinue).Source
if (-not $wez) { $wez = Join-Path $env:ProgramFiles 'WezTerm\wezterm.exe' }
if (-not $DryRun -and -not $env:WEZTERM_PANE) {
    throw 'WezTerm の中の PowerShell で打ってください（wezterm cli が今の窓を探せないため）'
}
$pwshExe = Join-Path $PSHOME 'pwsh.exe'
if (-not (Test-Path -LiteralPath $pwshExe)) { $pwshExe = 'pwsh' }

$script:fakePane = 1000
function Invoke-Wez([string[]]$WezArgs) {
    if ($DryRun) {
        $shown = $WezArgs | ForEach-Object { if ($_ -match '\s') { '"{0}"' -f $_ } else { $_ } }
        Write-Host ('wezterm ' + ($shown -join ' '))
        $script:fakePane++
        return [string]$script:fakePane
    }
    $out = & $wez @WezArgs
    if ($LASTEXITCODE -ne 0) { throw ('wezterm {0} が失敗しました（exit {1}）' -f $WezArgs[1], $LASTEXITCODE) }
    return ([string]$out).Trim()
}

function Get-PaneProgram($s) {
    @('--cwd', [string]$s.cwd, '--', $pwshExe, '-NoLogo', '-NoExit', '-Command', ('claude --resume {0}' -f $s.sessionId))
}

# 開く前に「使った」と書く（開いたペインの PowerShell に、また知らせが出ないように）
Set-PrevMark 'restoredAt'

# 1 タブに 4 つ: 左上 → 右上 → 左下 → 右下（2 つなら左右、3 つなら右は縦に 1 つ）
$per = if ($Tabs) { 1 } else { $PerTab }
for ($g = 0; $g -lt $chosen.Count; $g += $per) {
    $last = [Math]::Min($g + $per, $chosen.Count) - 1
    $group = @($chosen[$g..$last])
    $p1 = Invoke-Wez (@('cli', 'spawn') + (Get-PaneProgram $group[0]))
    if ($group.Count -ge 2) { $p2 = Invoke-Wez (@('cli', 'split-pane', '--pane-id', $p1, '--right', '--percent', '50') + (Get-PaneProgram $group[1])) }
    if ($group.Count -ge 3) { [void](Invoke-Wez (@('cli', 'split-pane', '--pane-id', $p1, '--bottom', '--percent', '50') + (Get-PaneProgram $group[2]))) }
    if ($group.Count -ge 4) { [void](Invoke-Wez (@('cli', 'split-pane', '--pane-id', $p2, '--bottom', '--percent', '50') + (Get-PaneProgram $group[3]))) }
}
$tabsMade = [Math]::Ceiling($chosen.Count / $per)
Write-Host ('{0} 個を {1} タブに開き直しました（会話の中身はそのまま。途中だった作業は「続けて」と頼む）' -f $chosen.Count, $tabsMade)
