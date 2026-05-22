$ErrorActionPreference = 'Stop'

try {
    $json = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($json)) { exit 0 }
    $obj = $json | ConvertFrom-Json -ErrorAction Stop
} catch {
    exit 0
}

if (-not $obj.prompt) { exit 0 }
$prompt = ($obj.prompt).ToString().Trim().ToLower()

$greetings = @('hi', 'おはよう', 'こんにちは', 'やあ', 'hello', 'hey')
if ($greetings -notcontains $prompt) { exit 0 }

$reminder = @'
セッション開始プロトコル: 最初の応答前に以下を**全て**読み込むこと。

1. CLAUDE.md（冒頭の「セッション開始プロトコル」を確認）
2. docs/initial-prompt.md
3. docs/nvim-manual.md
4. docs/keybinds.md
5. docs/troubleshooting.md
6. README.md
7. memory/MEMORY.md とそこからリンクされる個別 memory ファイル全て

読み込み完了後、簡潔に「準備できた。何やる?」相当の短い挨拶のみ返すこと。読んだファイル名を列挙する必要はない。
'@

$output = @{
    hookSpecificOutput = @{
        hookEventName     = 'UserPromptSubmit'
        additionalContext = $reminder
    }
}

$output | ConvertTo-Json -Compress -Depth 10
exit 0
