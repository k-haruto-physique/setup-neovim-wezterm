# Install and record trust for these exact, repository-reviewed lifecycle commands.
$ErrorActionPreference = 'Stop'
$codexHomePath = Join-Path $env:USERPROFILE '.codex'
$destination = Join-Path $codexHomePath 'hooks.json'
$ours = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'hooks.json') -Raw | ConvertFrom-Json
if (Test-Path -LiteralPath $destination) {
    $existing = Get-Content -LiteralPath $destination -Raw | ConvertFrom-Json
    foreach ($eventName in @('SessionStart', 'SessionEnd')) {
        $otherGroups = @(foreach ($group in $existing.hooks.$eventName) {
            $remaining = @($group.hooks | Where-Object command -ne $ours.hooks.$eventName[0].hooks[0].command)
            if ($remaining.Count) { $group.hooks = $remaining; $group }
        })
        $ours.hooks.$eventName = @($otherGroups) + @($ours.hooks.$eventName)
    }
    foreach ($property in $existing.hooks.PSObject.Properties) {
        if ($property.Name -notin @('SessionStart', 'SessionEnd')) {
            $ours.hooks | Add-Member -NotePropertyName $property.Name -NotePropertyValue $property.Value
        }
    }
}
[IO.File]::WriteAllText($destination, ($ours | ConvertTo-Json -Depth 20))
$processInfo = [Diagnostics.ProcessStartInfo]::new((Get-Command codex.exe).Source, 'app-server --stdio')
$processInfo.UseShellExecute = $false
$processInfo.CreateNoWindow = $true
$processInfo.RedirectStandardInput = $true
$processInfo.RedirectStandardOutput = $true
$processInfo.RedirectStandardError = $true
$server = [Diagnostics.Process]::Start($processInfo)
$server.BeginErrorReadLine()
function Invoke-StatusRpc($Method, $Params, $RequestId) {
    $server.StandardInput.WriteLine((@{ id = $RequestId; method = $Method; params = $Params } | ConvertTo-Json -Depth 20 -Compress))
    $server.StandardInput.Flush()
    for ($count = 0; $count -lt 100; $count++) {
        $pending = $server.StandardOutput.ReadLineAsync()
        if (-not $pending.Wait(15000)) { throw "Timeout in $Method" }
        if ($null -eq $pending.Result) { throw 'App server exited' }
        $reply = $pending.Result | ConvertFrom-Json
        if ($reply.id -eq $RequestId) {
            if ($reply.error) { throw ($reply.error | ConvertTo-Json -Compress) }
            return $reply.result
        }
    }
    throw "No response for $Method"
}
try {
    Invoke-StatusRpc initialize @{ clientInfo = @{ name = 'dotfiles-status-install'; version = '1' }; capabilities = @{ experimentalApi = $true } } 1 | Out-Null
    $server.StandardInput.WriteLine('{"method":"initialized"}')
    $server.StandardInput.Flush()
    $listing = Invoke-StatusRpc 'hooks/list' @{ cwds = @((Get-Location).Path) } 2
    $hookState = @{}
    foreach ($hook in $listing.data[0].hooks) {
        if ($hook.sourcePath -eq $destination -and $hook.command -eq $ours.hooks.SessionStart[-1].hooks[0].command) {
            $hookState[$hook.key] = @{ trusted_hash = $hook.currentHash; enabled = $true }
        }
    }
    if ($hookState.Count -ne 2) { throw 'Expected exactly the two status lifecycle hooks' }
    Invoke-StatusRpc 'config/batchWrite' @{ edits = @(@{ keyPath = 'hooks.state'; value = $hookState; mergeStrategy = 'upsert' }, @{ keyPath = 'tui.terminal_title'; value = @('app-name', 'session-id', 'model-with-reasoning'); mergeStrategy = 'replace' }, @{ keyPath = 'tui.keymap.composer.toggle_shortcuts'; value = @(); mergeStrategy = 'replace' }, @{ keyPath = 'tui.status_line'; value = @(); mergeStrategy = 'replace' }); reloadUserConfig = $true } 3 | Out-Null
    $verified = Invoke-StatusRpc 'hooks/list' @{ cwds = @((Get-Location).Path) } 4
    $verified.data[0].hooks | Where-Object { $hookState.ContainsKey($_.key) } | Select-Object eventName, trustStatus, enabled
} finally {
    if (-not $server.HasExited) { $server.Kill() }
    $server.Dispose()
}
