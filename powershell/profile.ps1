# setup-neovim-wezterm 管理の PowerShell プロファイル（正本）
#
# 配置方式: symlink ではなく **dot-source**。
#   $PROFILE（C:\Users\81809\Documents\PowerShell\Microsoft.PowerShell_profile.ps1）が
#   このファイルを `. <path>` で読み込む薄いローダになっている。
#   → 管理者権限不要・symlink 切れ事故（backlog W1 参照）が起きない。
# 編集はこのリポジトリ側を正本として行えば、次回シェル起動時に即反映される。

# --- リポジトリ移動 ---
function repo { Set-Location 'C:\Users\81809\Documents\Repositories\setup-neovim-wezterm' }
Set-Alias dotfiles repo

# --- nvim ショートカット ---
function v     { nvim . }          # cwd を nvim で開く
function vrepo { repo; nvim . }    # dotfiles を nvim で開く

# --- DB（kanro_db / pgpass 無人接続）---
function kanro { psql -U postgres -d kanro_db }

# Codex CLI の Remote Control 化はここでは行わない。codex.exe 隣の codex.ps1
# （Codex/install-codex-shim.ps1 が配置）が担当し、プロファイル未読込の既存シェルでも効く。

# --- 名前付きで Remote Control 起動（アプリ/web 側で識別しやすい）---
# 自動接続そのものはここではなく `~/.claude/settings.json` の
#   "remoteControlAtStartup": true
# が担当する（2026-07-16 に確定）。設定は起動経路に依存せず全対話セッションに効くため、
# 「既定で Remote Control 化する claude ラッパー」は撤去した（正本を 2 箇所に割らない）。
# この関数は「アプリ/web 側で名前を見て識別したい」時だけ使う:
#   remote           → 20260716-<自動採番>（当日 8 桁日付プレフィックス。既定は hostname）
#   remote fix-bug   → 20260716-fix-bug
# 注意: --remote-control の直後にフラグを置く（直後に文字列を置くと [name] として食われる）。
function remote {
    param([string]$Name)
    $p = Get-Date -Format 'yyyyMMdd'
    if ($Name) { claude --remote-control "$p-$Name" }
    else { claude --remote-control --remote-control-session-name-prefix $p }
}

# --- Claude の会話を開く・開き直す（2026-10-14・troubleshooting #32）---
#   cc  [リポ]          前回の続き（そのリポで最後に使った対話セッションを --resume。控えに無ければ --continue）
#   cn  [リポ] [名前]   新しく始める（--name yyyyMMdd_<名前>。名前を省くと [リポ] に打った字）
#   restore            再起動の前に開いていた会話を、全部その会話のまま開き直す（claude/restore-sessions.ps1）
# [リポ] は Documents\Repositories の下のフォルダ名の一部か、会話の名前の日付を外した部分（20261005_life → life）。
# 省くと今のフォルダ。リポの一覧はここに持たない（公開リポ）。控えは ~/.claude/state/ にだけある。
# 控えを書くのはログオンタスク「Claude Session Snapshot」（claude/register-session-snapshot-task.ps1）。
$ClaudeToolsDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'claude'
$ClaudeReposRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $ClaudeToolsDir 'session-common.ps1')

function cc {
    param([string]$Repo, [switch]$DryRun)
    $t = Find-ClaudeTarget $Repo $ClaudeReposRoot
    if (-not $t) { return }
    $id = $t.SessionId; $label = $t.Name
    if (-not $id) {
        $hist = Read-ClaudeJson (Join-Path (Get-ClaudeStateDirectory) 'session-history.json')
        if ($hist -and $hist.byDir) {
            $e = $hist.byDir.PSObject.Properties[(Get-ClaudeDirKey $t.Dir)]
            if ($e) { $id = [string]$e.Value.sessionId; $label = [string]$e.Value.name }
        }
    }
    $live = @(Get-LiveClaudeSessions)
    if ($id -and (@($live | ForEach-Object { $_.sessionId }) -contains $id)) {
        Write-Host "その会話（$label）は、もう別のペインで開いています。同じ会話を 2 つで開くと履歴が枝分かれするので開きません。新しく始めるなら cn" -ForegroundColor Yellow
        return
    }
    if ($id) {
        $cmd = @('--resume', $id)
    } else {
        $here = @($live | Where-Object { (Get-ClaudeDirKey $_.cwd) -eq (Get-ClaudeDirKey $t.Dir) })
        if ($here.Count -gt 0) {
            Write-Host ('このフォルダでは今 {0} 個開いていて、控えにまだ載っていません（2 分おきに書く）。選んで開くなら claude --resume、新しくなら cn' -f $here.Count) -ForegroundColor Yellow
            return
        }
        Write-Host '（控えに無いフォルダなので claude --continue）' -ForegroundColor DarkGray
        $cmd = @('--continue')
    }
    if ($DryRun) { 'claude {0}   @ {1}' -f ($cmd -join ' '), $t.Dir; return }
    Set-Location -LiteralPath $t.Dir
    claude @cmd
}

function cn {
    param([string]$Repo, [string]$Name, [switch]$DryRun)
    $t = Find-ClaudeTarget $Repo $ClaudeReposRoot
    if (-not $t) { return }
    if (-not $Name) {
        if ($Repo -and $Repo -notmatch '[\\/:]' -and $Repo -ne '.' -and $Repo -ne '..') { $Name = $Repo }
        else { $Name = Split-Path $t.Dir -Leaf }
    }
    $full = '{0}_{1}' -f (Get-Date -Format 'yyyyMMdd'), $Name
    if ($DryRun) { 'claude --name {0}   @ {1}' -f $full, $t.Dir; return }
    Set-Location -LiteralPath $t.Dir
    claude --name $full
}

function restore { & (Join-Path $ClaudeToolsDir 'restore-sessions.ps1') @args }

# 再起動の後に開いた PowerShell に 1 行だけ知らせる（restore か restore -Skip で消える・3 日で消える）
if ($Host.Name -eq 'ConsoleHost' -and -not ([Environment]::GetCommandLineArgs() -contains '-NonInteractive')) {
    try {
        $pendingRestore = @(Get-ClaudeRestorePending)
        if ($pendingRestore.Count -gt 0) {
            Write-Host ('↺ 再起動の前に開いていた Claude の会話が {0} 個あります → restore で開き直す（要らなければ restore -Skip）' -f $pendingRestore.Count) -ForegroundColor Yellow
        }
        Remove-Variable pendingRestore -ErrorAction SilentlyContinue
    } catch {}
}

# --- Claude Code 使用量を「API 従量課金だった場合」の額で表示（USD + 円換算）---
#   usage          月別（既定）
#   usage daily    日別
#   usage session  セッション別
# 実額は Max 20x の月 $200 固定。下に出るのは「もし従量だったら」の理論値。
# 円レートは frankfurter.app から取得（オフライン時は概算 155 にフォールバック）。
function usage {
    param([string]$Period = 'monthly')
    # NO_COLOR は ccusage 呼び出しの間だけ立てる（$env: はプロセス全体に効くため、
    # 放置すると以後の git/gh/claude 等のカラー出力がセッション全体で消える）
    $oldNoColor = $env:NO_COLOR
    $env:NO_COLOR = '1'
    try {
        $data = ccusage $Period --json 2>$null | ConvertFrom-Json
    } finally {
        if ($null -eq $oldNoColor) { Remove-Item Env:NO_COLOR -ErrorAction SilentlyContinue }
        else { $env:NO_COLOR = $oldNoColor }
    }
    if (-not $data) { Write-Host 'ccusage の出力を取得できませんでした（ccusage 導入を確認）'; return }

    $rate = try {
        [double](Invoke-RestMethod 'https://api.frankfurter.app/latest?base=USD&symbols=JPY' -TimeoutSec 6).rates.JPY
    } catch { 155.0 }

    # monthly/daily/sessions いずれの配列でも拾えるよう、最初の配列プロパティを使う
    $rows = ($data.PSObject.Properties | Where-Object { $_.Value -is [array] } | Select-Object -First 1).Value
    "{0,-12} {1,13} {2,15}" -f 'Period', 'USD(従量換算)', 'JPY(円)'
    foreach ($r in $rows) {
        $p = if ($r.period) { $r.period } elseif ($r.date) { $r.date } else { '-' }
        "{0,-12} {1,13} {2,15}" -f $p, ('$' + ('{0:N2}' -f [double]$r.totalCost)), ('¥' + ('{0:N0}' -f ([double]$r.totalCost * $rate)))
    }
    $tc = [double]$data.totals.totalCost
    "{0,-12} {1,13} {2,15}" -f '------', '------', '------'
    "{0,-12} {1,13} {2,15}" -f 'TOTAL', ('$' + ('{0:N2}' -f $tc)), ('¥' + ('{0:N0}' -f ($tc * $rate)))
    "  USD/JPY=$rate ・ 実額は Max20x 月 `$200 固定（上は従量だった場合の理論値）"
}
