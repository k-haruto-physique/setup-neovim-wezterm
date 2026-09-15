# One shared backend makes CLI sessions available through Remote Control.
# Keep non-interactive commands and explicit --remote invocations unchanged.
$ErrorActionPreference = 'Stop'
$cliArguments = @($args)
$codexExe = Join-Path $env:LOCALAPPDATA 'Programs/OpenAI/Codex/bin/codex.exe'
if (-not (Test-Path -LiteralPath $codexExe)) { throw "Codex executable not found: $codexExe" }
$commands = @('exec', 'e', 'review', 'login', 'logout', 'mcp', 'plugin', 'app-server', 'remote-control', 'app', 'completion', 'update', 'doctor', 'sandbox', 'debug', 'apply', 'queue', 'archive', 'delete', 'migrate-rollouts', 'unarchive', 'cloud', 'exec-server', 'features', 'help')
$firstPositional = $null
$takesValue = @('-c', '--config', '-i', '--image', '-m', '--model', '--local-provider', '-p', '--profile', '-s', '--sandbox', '-C', '--cd', '--add-dir', '-a', '--ask-for-approval', '--enable', '--disable', '--remote-auth-token-env')
for ($index = 0; $index -lt $cliArguments.Count; $index++) {
    $argument = [string]$cliArguments[$index]
    if ($takesValue -contains $argument) { $index++; continue }
    if ($argument -eq '--') { if ($index + 1 -lt $cliArguments.Count) { $firstPositional = $cliArguments[$index + 1] }; break }
    if (-not $argument.StartsWith('-')) { $firstPositional = $argument; break }
}
$explicitRemote = @($cliArguments | Where-Object { $_ -eq '--remote' -or $_ -like '--remote=*' }).Count -gt 0
if ($explicitRemote -or $commands -contains $firstPositional -or @($cliArguments | Where-Object { $_ -in @('-h', '--help', '-V', '--version') }).Count -gt 0) {
    & $codexExe @cliArguments
    exit $LASTEXITCODE
}
. (Join-Path $PSScriptRoot 'remote-client.ps1')
try { $status = Invoke-CodexRemoteRequest } catch {
    Start-ScheduledTask -TaskName 'Codex Remote Control'
    $status = $null
}
$started = [datetime]::UtcNow
while (-not $status -or $status.status -ne 'connected') {
    $waited = ([datetime]::UtcNow - $started).TotalSeconds
    # 'errored' usually means a 409 from another server holding the registration;
    # it retries on its own every 30s, so don't hold the CLI hostage waiting for it.
    if ($status -and ($waited -ge 30 -or ($status.status -eq 'errored' -and $waited -ge 3))) { break }
    if (-not $status -and $waited -ge 30) {
        throw 'Codex Remote Control server is not running. Check the scheduled task "Codex Remote Control" and ~/.codex/logs/remote-control.log.'
    }
    Start-Sleep -Seconds 1
    try { $status = Invoke-CodexRemoteRequest } catch { $status = $null }
}
if ($status.status -ne 'connected') {
    # Still join the shared server (never silently fall back to a local-only CLI):
    # once Remote Control reconnects, this session becomes visible from the phone.
    Write-Warning "Remote Control is $($status.status): the phone cannot reach this CLI session. Usually the Codex desktop app took the registration back (409). Turn off Desktop > Settings > Connections > 'Control this Mac or PC'; the shared server reconnects within 30s. Until then, do not type into this conversation from the phone or desktop app: they only hold a copy and the conversation would split (troubleshooting #26)."
}
# The WebSocket backend does not inherit this terminal's cwd or environment.
# Pass cwd explicitly; status panes discover the TUI PID and exact thread title.
& $codexExe --remote 'ws://127.0.0.1:14567' -C (Get-Location).Path @cliArguments
exit $LASTEXITCODE
