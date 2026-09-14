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

# Codex CLI: interactive sessions share the Remote Control backend.
function codex {
    & 'C:\Users\81809\Documents\Repositories\setup-neovim-wezterm\Codex\start-codex.ps1' @args
}

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
