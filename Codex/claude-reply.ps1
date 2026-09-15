# Codex -> Claude bridge, Claude side: answer one message received by claude-listen.ps1.
[CmdletBinding(DefaultParameterSetName = 'Text')]
param(
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{32}$')][string]$Id,
    [Parameter(ParameterSetName = 'Text', Mandatory, Position = 0)][string]$Message,
    [Parameter(ParameterSetName = 'File', Mandatory)][string]$MessageFile
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'bridge-common.ps1')
if ($MessageFile) { $Message = Get-Content -LiteralPath $MessageFile -Raw -Encoding utf8 }

$claimed = Get-ChildItem -LiteralPath $BridgeRoot -Directory -ErrorAction SilentlyContinue |
    ForEach-Object { Join-Path $_.FullName "processing\$Id.json" } |
    Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $claimed) { throw "No message $Id is waiting for a reply (already answered, withdrawn by timeout, or never received)." }

$dir = Split-Path (Split-Path $claimed)
Write-AtomicJson (Join-Path $dir "outbox\$Id.json") ([ordered]@{ id = $Id; reply = $Message; repliedAt = [datetime]::UtcNow.ToString('o') })
Move-Item -LiteralPath $claimed -Destination (Join-Path $dir "done\$Id.json") -Force
"Reply for $Id delivered to Codex."
