local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

config.automatically_reload_config = true
config.font = wezterm.font_with_fallback({
    "JetBrainsMono Nerd Font",
    "JetBrains Mono",
    "Consolas",
})
config.font_size = 12.0
config.use_ime = true

----------------------------------------------------
-- 背景の透過・ぼかし（Windows用）
----------------------------------------------------
-- 透過率（0〜1、0に近いほど透過）
-- 2026-05-22: 当初 0.85 だったが、nvim 用 0.95 への動的切替が Windows TUI で
-- 安定しないため 0.95 で統一。Acrylic はやや控えめだが nvim/claude 両方読みやすい。
config.window_background_opacity = 0.95
-- Windows 11 のシステムバックドロップ（Mac の macos_window_background_blur 相当）
-- 選択肢: "Acrylic" / "Mica" / "Tabbed" / "Auto"
config.win32_system_backdrop = "Auto"

----------------------------------------------------
-- Tab
----------------------------------------------------
-- タイトルバーを非表示
config.window_decorations = "RESIZE"
-- タブバーの表示
config.show_tabs_in_tab_bar = true
-- 2026-05-19: tab bar を画面下端へ移動し、tab が 1 つの時はタイトルを空にして
-- statusline addon の set_right_status だけが画面下に出るようにする。
-- (WezTerm 仕様上 set_right_status はタブバー領域専用なので、タブバー自体は
-- 残さざるを得ない。format-tab-title で見た目だけ消す。)
-- 2026-05-22: タブ 1 つの時はバー非表示（ペイン領域を最大化）
config.hide_tab_bar_if_only_one_tab = true
-- 2026-05-22: タブバーを画面上部に戻した（コピーモードの MODE 表示も上に出る）
config.tab_bar_at_bottom = false
-- ファンシータブバーを無効化（OS 風クロームだと透過が効かないため、
-- 端末セル領域内に描画されるレトロタブバーを使用してウィンドウと同じ透過率にする）
config.use_fancy_tab_bar = false

-- タブバーの透過
config.window_frame = {
	inactive_titlebar_bg = "none",
	active_titlebar_bg = "none",
}

-- タブの追加ボタンを非表示
config.show_new_tab_button_in_tab_bar = false
-- タブの閉じるボタンを非表示（nightly版で有効化される）
config.show_close_tab_button_in_tabs = false

-- タブバーを透過（Acrylic の効果を活かす）
config.colors = {
	tab_bar = {
		background = "rgba(0, 0, 0, 0)",
		inactive_tab_edge = "none",
	},
}

-- タブの形をカスタマイズ
-- タブの左側の装飾
local SOLID_LEFT_ARROW = wezterm.nerdfonts.ple_lower_right_triangle
-- タブの右側の装飾
local SOLID_RIGHT_ARROW = wezterm.nerdfonts.ple_upper_left_triangle

wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
	-- 2026-05-22: hide_tab_bar_if_only_one_tab=true により 1 タブ時はそもそも fire しない。
	-- 旧 "#tabs <= 1 -> 空文字" の分岐は dead code として削除。
	local background = "#5c6d74"
	local foreground = "#FFFFFF"
	local edge_background = "none"
	if tab.is_active then
		background = "#ae8b2d"
		foreground = "#FFFFFF"
	end
	local edge_foreground = background
	local title = "   " .. wezterm.truncate_right(tab.active_pane.title, max_width - 1) .. "   "
	return {
		{ Background = { Color = edge_background } },
		{ Foreground = { Color = edge_foreground } },
		{ Text = SOLID_LEFT_ARROW },
		{ Background = { Color = background } },
		{ Foreground = { Color = foreground } },
		{ Text = title },
		{ Background = { Color = edge_background } },
		{ Foreground = { Color = edge_foreground } },
		{ Text = SOLID_RIGHT_ARROW },
	}
end)

----------------------------------------------------
-- キーバインド（2026-04-21: WezTerm デフォルトに戻した）
-- 以下 4 行を有効化すると tmux 風カスタムに復帰。設定は keybinds.lua.legacy に退避済
-- （復帰時はまず keybinds.lua に戻す。require("keybinds") は .legacy 拡張子を解決しない）。
----------------------------------------------------
-- config.disable_default_key_bindings = true
-- config.keys = require("keybinds").keys
-- config.key_tables = require("keybinds").key_tables
-- config.leader = { key = "q", mods = "CTRL", timeout_milliseconds = 2000 }

----------------------------------------------------
-- 2026-05-22: copy_mode を vim 風 hjkl で確実に動かす
-- Ctrl+Shift+X (WezTerm デフォルト) で起動 → hjkl で移動 → y/Enter でコピー
-- config.key_tables を明示することで、デフォルト table の挙動依存をやめる
----------------------------------------------------
-- 入口を明示バインド（デフォルト依存をやめる保険）
-- ClearPattern は副作用で search overlay を表示することがあるため使わない

-- 2026-06-05: ファイルパスを nvim（新規ウィンドウ）で開く共通関数。
-- Ctrl+Click（hyperlink）と Ctrl+Shift+O（QuickSelect）両方から呼ぶ。
local function open_path_in_nvim(window, pane, path)
    if not path or path == "" then return end
    path = path:gsub("^%s+", ""):gsub("%s+$", "")
    local spawn = { args = { "nvim", path } }
    -- ペイン cwd を nvim の作業ディレクトリへ（相対パス解決のため。OSC 7 必須）
    local cwd_uri = pane:get_current_working_dir()
    if cwd_uri then
        -- 新しめの WezTerm は Url オブジェクト（.file_path）、古いと文字列
        local cwd = cwd_uri.file_path or tostring(cwd_uri)
        cwd = cwd:gsub("^file://[^/]*", ""):gsub("^/([A-Za-z]:)", "%1")
        if cwd ~= "" then spawn.cwd = cwd end
    end
    window:perform_action(act.SpawnCommandInNewWindow(spawn), pane)
end

config.keys = {
    { key = "x", mods = "CTRL|SHIFT", action = act.ActivateCopyMode },
    -- 2026-05-22: nvim を別ウィンドウで起動（上モニターへドラッグ用）
    -- Ctrl+Shift+I → 新規 WezTerm ウィンドウで nvim .
    { key = "I", mods = "CTRL|SHIFT", action = act.SpawnCommandInNewWindow({
        args = { "nvim", "." },
    })},
    -- Ctrl+Shift+N → 新規ウィンドウで claude（下モニターで複数 claude 用）
    { key = "N", mods = "CTRL|SHIFT", action = act.SpawnCommandInNewWindow({
        args = { "claude" },
    })},
    -- 2026-05-29: ペイン入れ替え（分割の向きは変えられないが中身の位置交換は可能）
    -- Ctrl+Shift+S → アクティブペインと選択ペインをスワップ。各ペインにラベルが出るので
    -- 表示された文字を打って相手を指定（3 ペイン以上でも狙って交換できる）。
    { key = "S", mods = "CTRL|SHIFT", action = act.PaneSelect({ mode = "SwapWithActive" }) },
    -- Ctrl+Shift+E → ペイン回転。2 ペインなら押すだけで位置交換（ラベル不要・最速）。
    { key = "E", mods = "CTRL|SHIFT", action = act.RotatePanes("Clockwise") },
    -- 2026-06-05: 画面に出ているファイルパスを QuickSelect で拾って nvim で開く。
    -- Ctrl+Shift+O → 対象拡張子のパスにラベル付与 → 文字を打つと、その 1 ファイルを
    -- 新規 WezTerm ウィンドウの nvim で開く（ペイン cwd 基準で相対パスも解決）。
    -- Ctrl+Shift+O: マウスで選択中のパスがあればそれを nvim で開く（最確実・IME 無関係）。
    -- 選択が無ければ数字ラベル QuickSelect にフォールバック。
    { key = "O", mods = "CTRL|SHIFT", action = wezterm.action_callback(function(window, pane)
        local sel = window:get_selection_text_for_pane(pane)
        if sel and sel:gsub("%s", "") ~= "" then
            open_path_in_nvim(window, pane, sel)
        else
            window:perform_action(act.QuickSelectArgs({
                label = "open in nvim",
                -- 数字ラベル: IME ON でも素通しする（a/s/d… は IME に吸われるため避ける）
                alphabet = "123456789",
                patterns = {
                    "(?:[A-Za-z]:)?[\\w.\\-/\\\\]+\\.(?:md|markdown|lua|py|sql|txt|json|toml|ya?ml|tsx?|jsx?|sh|ps1|conf|ini|cfg|html?|css|rs|go)",
                },
                action = wezterm.action_callback(function(w, p)
                    open_path_in_nvim(w, p, w:get_selection_text_for_pane(p))
                end),
            }), pane)
        end
    end)},
}

config.key_tables = {
    copy_mode = {
        -- カーソル移動（矢印キーを優位に: hjkl が他層に取られても確実）
        { key = "LeftArrow",  mods = "NONE", action = act.CopyMode("MoveLeft") },
        { key = "DownArrow",  mods = "NONE", action = act.CopyMode("MoveDown") },
        { key = "UpArrow",    mods = "NONE", action = act.CopyMode("MoveUp") },
        { key = "RightArrow", mods = "NONE", action = act.CopyMode("MoveRight") },
        -- カーソル移動（vim 風 hjkl も併設）
        { key = "h", mods = "NONE", action = act.CopyMode("MoveLeft") },
        { key = "j", mods = "NONE", action = act.CopyMode("MoveDown") },
        { key = "k", mods = "NONE", action = act.CopyMode("MoveUp") },
        { key = "l", mods = "NONE", action = act.CopyMode("MoveRight") },
        -- 単語移動
        { key = "w", mods = "NONE", action = act.CopyMode("MoveForwardWord") },
        { key = "b", mods = "NONE", action = act.CopyMode("MoveBackwardWord") },
        { key = "e", mods = "NONE", action = act.CopyMode("MoveForwardWordEnd") },
        -- 行頭/行末
        { key = "0", mods = "NONE", action = act.CopyMode("MoveToStartOfLine") },
        { key = "^", mods = "NONE", action = act.CopyMode("MoveToStartOfLineContent") },
        { key = "$", mods = "NONE", action = act.CopyMode("MoveToEndOfLineContent") },
        -- ファイル先頭/末尾
        { key = "g", mods = "NONE", action = act.CopyMode("MoveToScrollbackTop") },
        { key = "G", mods = "NONE", action = act.CopyMode("MoveToScrollbackBottom") },
        -- viewport (画面内) 上/中/下
        { key = "H", mods = "NONE", action = act.CopyMode("MoveToViewportTop") },
        { key = "M", mods = "NONE", action = act.CopyMode("MoveToViewportMiddle") },
        { key = "L", mods = "NONE", action = act.CopyMode("MoveToViewportBottom") },
        -- ページスクロール
        { key = "u", mods = "CTRL", action = act.CopyMode({ MoveByPage = -0.5 }) },
        { key = "d", mods = "CTRL", action = act.CopyMode({ MoveByPage = 0.5 }) },
        { key = "b", mods = "CTRL", action = act.CopyMode("PageUp") },
        { key = "f", mods = "CTRL", action = act.CopyMode("PageDown") },
        -- 専用キーでも同じ動作（IME に取られない・押しやすい）
        { key = "PageUp",   mods = "NONE", action = act.CopyMode("PageUp") },
        { key = "PageDown", mods = "NONE", action = act.CopyMode("PageDown") },
        { key = "Home",     mods = "NONE", action = act.CopyMode("MoveToScrollbackTop") },
        { key = "End",      mods = "NONE", action = act.CopyMode("MoveToScrollbackBottom") },
        -- 検索マッチ間ジャンプ（検索自体は Ctrl+Shift+F から明示的に開始する）
        { key = "n", mods = "NONE", action = act.CopyMode("NextMatch") },
        { key = "N", mods = "NONE", action = act.CopyMode("PriorMatch") },
        -- 意図しない検索バー誤発火の防止: コピーモード内で / ? を無効化（押しても何も起きない）。
        -- 検索したい時は Ctrl+Shift+F で明示的に入る。
        { key = "/", mods = "NONE", action = act.Nop },
        { key = "?", mods = "NONE", action = act.Nop },
        -- 選択モード
        { key = "v", mods = "NONE", action = act.CopyMode({ SetSelectionMode = "Cell" }) },
        { key = "V", mods = "NONE", action = act.CopyMode({ SetSelectionMode = "Line" }) },
        { key = "v", mods = "CTRL", action = act.CopyMode({ SetSelectionMode = "Block" }) },
        -- コピーして抜ける
        { key = "y", mods = "NONE", action = act.Multiple({
            { CopyTo = "ClipboardAndPrimarySelection" },
            { CopyMode = "Close" },
        })},
        { key = "Enter", mods = "NONE", action = act.Multiple({
            { CopyTo = "ClipboardAndPrimarySelection" },
            { CopyMode = "Close" },
        })},
        -- 抜ける（何もコピーせず）
        { key = "Escape", mods = "NONE", action = act.CopyMode("Close") },
        { key = "q",      mods = "NONE", action = act.CopyMode("Close") },
        { key = "c",      mods = "CTRL", action = act.CopyMode("Close") },
    },
}

----------------------------------------------------
-- ステータス: コピーモード突入時はカーソルを黄色化（カーソルそのものが標識になる）。
-- UI 要素を追加しない、リサイズもしない、透過変化もしない。
-- set_right_status は旧 addon 残骸対策で空文字を上書き。
----------------------------------------------------
wezterm.on("update-status", function(window, pane)
    window:set_right_status("")
    window:set_left_status("")

    -- 過去ハンドラ残骸が opacity を 0.85 等に書き換えるのを抑止するため、
    -- 毎フレーム明示的に 0.95 を override する。
    local overrides = {
        window_background_opacity = 0.95,
    }

    -- コピーモード等のキーテーブルアクティブ時: カーソル黄色化
    if window:active_key_table() then
        overrides.colors = {
            cursor_bg = "#FFEB3B",
            cursor_fg = "#000000",
            cursor_border = "#FFEB3B",
            tab_bar = {
                background = "rgba(0, 0, 0, 0)",
                inactive_tab_edge = "none",
            },
        }
    end

    window:set_config_overrides(overrides)
end)

----------------------------------------------------
-- 2026-06-05: Ctrl+Click でファイルパスを nvim で開く
-- ターミナルに出ているパスを hyperlink 化し、Ctrl+Click で nvim（新規ウィンドウ）起動。
-- ラベル入力が不要なので IME の影響を一切受けない（クリックするだけ）。
----------------------------------------------------
-- 2026-07-02: Ctrl+Click でだけリンク(=nvimopen パス)を開く。
-- 既定はプレーンクリックの CompleteSelectionOrOpenLinkAtMouseCursor がリンクを開いてしまい、
-- パス文字列を軽くクリックしただけで nvim が新規ウィンドウで開く事故が起きる。
-- そこでプレーンクリックは選択完了のみに戻し、Ctrl+Click に OpenLink を明示バインドする
-- （このバージョンには Ctrl+Click の既定 OpenLink バインドが無いため Ctrl+Click が無反応だった）。
config.mouse_bindings = {
    -- プレーンクリック = 選択完了のみ（リンクは開かない → 誤爆防止）
    {
        event = { Up = { streak = 1, button = "Left" } },
        mods = "NONE",
        action = act.CompleteSelection("ClipboardAndPrimarySelection"),
    },
    -- Ctrl+Click = リンク(nvimopen パス)を開く（意図的操作でだけ nvim を起動）
    {
        event = { Up = { streak = 1, button = "Left" } },
        mods = "CTRL",
        action = act.OpenLinkAtMouseCursor,
    },
    -- Ctrl+Down は Nop（Ctrl 押下で選択が始まって Up の OpenLink を邪魔しないように）
    {
        event = { Down = { streak = 1, button = "Left" } },
        mods = "CTRL",
        action = act.Nop,
    },
}

config.hyperlink_rules = wezterm.default_hyperlink_rules()
table.insert(config.hyperlink_rules, {
    -- 相対/絶対パス + 主要拡張子。マッチ文字列を nvimopen: スキームに載せて open-uri へ渡す。
    regex = [[(?:[A-Za-z]:)?[\w.\-/\\]+\.(?:md|markdown|lua|py|sql|txt|json|toml|ya?ml|tsx?|jsx?|sh|ps1|conf|ini|cfg|html?|css|rs|go)]],
    format = "nvimopen:$0",
})

wezterm.on("open-uri", function(window, pane, uri)
    local prefix = "nvimopen:"
    if uri:sub(1, #prefix) == prefix then
        open_path_in_nvim(window, pane, uri:sub(#prefix + 1))
        return false -- デフォルトの URL オープンを抑止
    end
    -- それ以外（http 等）はデフォルト動作に任せる
end)

return config
