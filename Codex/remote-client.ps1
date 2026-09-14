# Read the actual Remote Control state; /readyz only proves local readiness.
function Invoke-CodexRemoteRequest {
    param([string]$Method = 'remoteControl/status/read', $Params = $null)
    $socket = [Net.WebSockets.ClientWebSocket]::new()
    $deadline = [Threading.CancellationTokenSource]::new(12000)
    try {
        $null = $socket.ConnectAsync([uri]'ws://127.0.0.1:14567', $deadline.Token).GetAwaiter().GetResult()
        function Send-Message($Message) {
            $bytes = [Text.Encoding]::UTF8.GetBytes(($Message | ConvertTo-Json -Depth 8 -Compress))
            $null = $socket.SendAsync([ArraySegment[byte]]::new($bytes), [Net.WebSockets.WebSocketMessageType]::Text, $true, $deadline.Token).GetAwaiter().GetResult()
        }
        function Receive-Result([int]$Id) {
            do {
                $buffer = [byte[]]::new(65536)
                $stream = [IO.MemoryStream]::new()
                try {
                    do {
                        $received = $socket.ReceiveAsync([ArraySegment[byte]]::new($buffer), $deadline.Token).GetAwaiter().GetResult()
                        if ($received.MessageType -eq [Net.WebSockets.WebSocketMessageType]::Close) { throw 'Codex server closed the connection' }
                        $stream.Write($buffer, 0, $received.Count)
                        if ($stream.Length -gt 1048576) { throw 'Unexpectedly large Codex response' }
                    } until ($received.EndOfMessage)
                    $response = [Text.Encoding]::UTF8.GetString($stream.ToArray()) | ConvertFrom-Json
                } finally { $stream.Dispose() }
            } until ($response.id -eq $Id)
            if ($response.error) { throw $response.error.message }
            return $response.result
        }
        Send-Message @{ id = 1; method = 'initialize'; params = @{ clientInfo = @{ name = 'codex_cli_launcher'; version = '1' }; capabilities = @{ experimentalApi = $true } } }
        $null = Receive-Result 1
        Send-Message @{ method = 'initialized' }
        Send-Message @{ id = 2; method = $Method; params = $Params }
        Receive-Result 2
    } finally {
        $socket.Dispose()
        $deadline.Dispose()
    }
}
