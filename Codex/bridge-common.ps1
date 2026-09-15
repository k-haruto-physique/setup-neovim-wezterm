# Shared helpers for the Codex -> Claude file bridge (ask-claude / claude-listen / claude-reply).
# One folder per Claude process: listener.json marks it armed; inbox -> processing -> done, replies in outbox.
# Under Temp on purpose: Codex's Windows sandbox (CodexSandboxUsers) may only write there and in its workspace.
# Directly under LOCALAPPDATA it gets "Access denied" with sandbox_mode = "workspace-write".
$BridgeRoot = Join-Path $env:LOCALAPPDATA 'Temp\codex-claude-bridge'

function Get-NormalPath([string]$Path) { [IO.Path]::GetFullPath($Path).TrimEnd('\', '/') }

# Writers rename a finished temp file so readers never see half a message.
function Write-AtomicJson([string]$Path, $Object) {
    $temp = "$Path.tmp"
    [IO.File]::WriteAllText($temp, ($Object | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temp -Destination $Path -Force
}

function Read-Json([string]$Path) { Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json }

function Get-StartMs($StartTime) { [DateTimeOffset]::new($StartTime).ToUnixTimeMilliseconds() }
