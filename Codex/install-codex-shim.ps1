# Copies codex-shim.ps1 to codex.ps1 beside the installed codex.exe.
# Codex updates may replace the bin directory, so remote-control.ps1 reruns this at logon.
$ErrorActionPreference = 'Stop'
$binDir = Join-Path $env:LOCALAPPDATA 'Programs/OpenAI/Codex/bin'
$source = Join-Path $PSScriptRoot 'codex-shim.ps1'
$target = Join-Path $binDir 'codex.ps1'
if (-not (Test-Path -LiteralPath (Join-Path $binDir 'codex.exe'))) { throw "codex.exe not found in $binDir" }
$current = if (Test-Path -LiteralPath $target) { Get-FileHash -LiteralPath $target } else { $null }
if ($current -and $current.Hash -eq (Get-FileHash -LiteralPath $source).Hash) {
    Write-Output "Codex shim already up to date: $target"
    exit 0
}
Copy-Item -LiteralPath $source -Destination $target -Force
Write-Output "Installed Codex shim: $target"
