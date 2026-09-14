# Installed Excel skill references an icon outside the plugin's allowed assets.
# Keep the icon under plugin/assets, matching the other runtime plugins.
$ErrorActionPreference = 'Stop'
$root = Join-Path $env:USERPROFILE '.codex/plugins/cache/openai-primary-runtime/spreadsheets'
foreach ($version in (Get-ChildItem -LiteralPath $root -Directory)) {
    $yaml = Join-Path $version.FullName 'skills/excel-live-control/agents/openai.yaml'
    $source = Join-Path $version.FullName 'skills/spreadsheets/assets/file-spreadsheet.png'
    if (-not (Test-Path -LiteralPath $yaml) -or -not (Test-Path -LiteralPath $source)) { continue }
    $content = [IO.File]::ReadAllText($yaml)
    if ($content.Contains('../spreadsheets/assets/file-spreadsheet.png')) {
        New-Item -ItemType Directory -Path (Join-Path $version.FullName 'assets') -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination (Join-Path $version.FullName 'assets/file-spreadsheet.png') -Force
        [IO.File]::WriteAllText($yaml, $content.Replace('../spreadsheets/assets/file-spreadsheet.png', '../../assets/file-spreadsheet.png'))
        Write-Output "Repaired Excel skill icon paths: $($version.Name)"
    }
}
