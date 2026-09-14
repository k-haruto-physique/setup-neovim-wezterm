# Installed as codex.ps1 next to codex.exe by install-codex-shim.ps1.
# PowerShell resolves codex.ps1 before codex.exe in the same PATH directory,
# so every pwsh (including shells opened before a profile change) goes through
# start-codex.ps1 and joins the shared Remote Control backend.
$launcher = 'C:\Users\81809\Documents\Repositories\setup-neovim-wezterm\Codex\start-codex.ps1'
$codexExe = Join-Path $PSScriptRoot 'codex.exe'
if ($MyInvocation.ExpectingInput -or -not (Test-Path -LiteralPath $launcher)) {
    # Piped stdin (e.g. `"..." | codex exec -`) is not forwarded through a nested script.
    $input | & $codexExe @args
    exit $LASTEXITCODE
}
& $launcher @args
exit $LASTEXITCODE
