# Runs a loopback-only Codex app-server with Remote Control enabled.
$ErrorActionPreference = 'Stop'
$logDirectory = Join-Path $env:USERPROFILE '.codex\logs'
$logPath = Join-Path $logDirectory 'remote-control.log'
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null

try {
    $codexExe = Join-Path $env:LOCALAPPDATA 'Programs\OpenAI\Codex\bin\codex.exe'
    if (-not (Test-Path -LiteralPath $codexExe)) {
        throw "Codex executable not found: $codexExe"
    }

    "[$(Get-Date -Format o)] Starting Codex Remote Control" | Set-Content -LiteralPath $logPath

    & $codexExe app-server --remote-control --listen 'ws://127.0.0.1:14567' *>> $logPath
    $exitCode = $LASTEXITCODE
    "[$(Get-Date -Format o)] Codex Remote Control exited with code $exitCode" |
        Add-Content -LiteralPath $logPath
    exit $exitCode
} catch {
    $_ | Out-String | Add-Content -LiteralPath $logPath
    throw
}
