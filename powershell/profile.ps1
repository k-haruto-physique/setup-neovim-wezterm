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
