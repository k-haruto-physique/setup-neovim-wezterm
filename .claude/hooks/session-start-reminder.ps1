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
セッション開始プロトコル: 最初の応答前に以下を**全て**読み込むこと（正本は CLAUDE.md 冒頭の「セッション開始プロトコル」。本リマインダーと差異があれば CLAUDE.md が勝つ）。

1. CLAUDE.md（冒頭の「セッション開始プロトコル」を確認）
2. memory/MEMORY.md とそこからリンクされる個別 memory ファイル全て
3. docs/initial-prompt.md
4. docs/nvim-manual.md
5. docs/keybinds.md
6. docs/troubleshooting.md
7. README.md
8. docs/backlog.md（未完タスクの単一台帳＝GO ゲート回収）

読み込み完了後、短い挨拶を返す。読んだファイル名の列挙は不要だが、**docs/backlog.md の OPEN 件数と上位 2-3 項目を挨拶に必ず含める**こと（例:「準備できた。OPEN 1 件（〜）。何をやる?」）。
'@

$output = @{
    hookSpecificOutput = @{
        hookEventName     = 'UserPromptSubmit'
        additionalContext = $reminder
    }
}

# Hook stdout is decoded as UTF-8, but a hook-spawned pwsh writes with the console
# code page (CP932), which garbled the Japanese reminder. \uXXXX escapes keep the
# JSON pure ASCII, so it survives any code page.
$output | ConvertTo-Json -Compress -Depth 10 -EscapeHandling EscapeNonAscii
exit 0
