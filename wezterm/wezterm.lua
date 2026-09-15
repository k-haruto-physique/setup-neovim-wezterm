local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

----------------------------------------------------
-- 定数（複数箇所から参照する値はここに集約する）
-- 2026-08-20 リファクタ: 同じ値・同じ正規表現が 2 箇所以上に散っていて
-- 片方だけ直す事故が起きうる状態だったため単一定義へ集約した。
----------------------------------------------------

-- 透過率。config 本体と update-status の override（旧 addon 残骸対策）の両方で使う。
-- 2026-05-22: 当初 0.85 だったが、nvim 用 0.95 への動的切替が Windows TUI で
-- 安定しないため 0.95 で統一。Acrylic はやや控えめだが nvim/claude 両方読みやすい。
local WINDOW_OPACITY = 0.95

-- タブバーの透過設定。update-status で colors を override する際、
-- ここを一緒に渡さないとタブバーの透過が外れる（override は colors を丸ごと置換するため）。
local TAB_BAR_COLORS = {
	background = "rgba(0, 0, 0, 0)",
	inactive_tab_edge = "none",
}

-- コピーモード等の key_table アクティブ時のカーソル色（黄色 = 標識）。
local COPY_MODE_CURSOR_COLORS = {
	cursor_bg = "#FFEB3B",
	cursor_fg = "#000000",
	cursor_border = "#FFEB3B",
}

-- 「nvim で開く対象」とみなすパスの正規表現（相対/絶対 + 主要拡張子）。
-- Ctrl+Shift+O の QuickSelect と hyperlink_rules の**両方**が同じ定義を使う。
-- ここが 2 重定義だと「クリックでは開くがラベルでは拾えない」等の非対称バグになる。
local PATH_PATTERN =
	[[(?:[A-Za-z]:)?[\w.\-/\\]+\.(?:md|markdown|lua|py|sql|txt|json|toml|ya?ml|tsx?|jsx?|sh|ps1|conf|ini|cfg|html?|css|rs|go)]]

-- Codex 本体は custom/multiline status line を持たないため、下端の専用ペインで4段表示する。
local CODEX_SESSION_STATUS_SCRIPT =
	"C:/Users/81809/Documents/Repositories/setup-neovim-wezterm/Codex/session-status.ps1"

----------------------------------------------------
-- フォント・基本
----------------------------------------------------
config.automatically_reload_config = true
wezterm.add_to_config_reload_watch_list("C:/Users/81809/Documents/Repositories/setup-neovim-wezterm/wezterm/wezterm.lua")
config.font = wezterm.font_with_fallback({
	"JetBrainsMono Nerd Font",
	"JetBrains Mono",
	"Consolas",
})
config.font_size = 12.0
config.use_ime = true

----------------------------------------------------
-- 既定シェル
----------------------------------------------------
-- 2026-07-16: default_prog 未指定だと WezTerm は Windows 既定の **cmd.exe** を起動する。
-- そのため `powershell/profile.ps1`（repo/v/vrepo/kanro/remote/usage）が一度も読まれず、
-- 「PowerShell 主体・cmd.exe は使用しない」方針（docs/initial-prompt.md）と実態が乖離していた。
-- 実プロセスツリーで確認: wezterm-gui → cmd.exe → claude（pwsh は皆無）。pwsh 7 を明示する。
-- -NoLogo は起動バナーの抑止のみ。profile.ps1 は $PROFILE からの dot-source で読まれる
-- （-NoProfile を付けると独自コマンドが全滅するので付けないこと）。
config.default_prog = { "pwsh.exe", "-NoLogo" }

----------------------------------------------------
-- 背景の透過・ぼかし（Windows用）
----------------------------------------------------
config.window_background_opacity = WINDOW_OPACITY
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
config.show_close_tab_button_in_tabs = true

-- タブバーを透過（Acrylic の効果を活かす）
config.colors = {
	tab_bar = TAB_BAR_COLORS,
	-- 2026-09-15: 黄 (#FFD54F) は複数行選択で眩しいとの声で水色系へ。
	-- カーソルの黄色（COPY_MODE_CURSOR_COLORS）はモード標識なので据え置き。
	selection_bg = "#5DADE2",
	selection_fg = "#0B1A26",
	copy_mode_active_highlight_bg = { Color = "#5DADE2" },
	copy_mode_active_highlight_fg = { Color = "#0B1A26" },
	copy_mode_inactive_highlight_bg = { Color = "#2E6A8A" },
	copy_mode_inactive_highlight_fg = { Color = "#FFFFFF" },
}

-- タブの形をカスタマイズ
-- タブの左側の装飾
local SOLID_LEFT_ARROW = wezterm.nerdfonts.ple_lower_right_triangle
-- タブの右側の装飾
local SOLID_RIGHT_ARROW = wezterm.nerdfonts.ple_upper_left_triangle

-- 引数 4 番目は WezTerm 側の config オブジェクト。名前を `config` にすると
-- このファイル冒頭の `config` を**シャドウ**して事故るので `_` 付きで受ける。
wezterm.on("format-tab-title", function(tab, _tabs, _panes, _config, _hover, max_width)
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
-- ヘルパー
----------------------------------------------------
local function pane_cwd(pane)
	local cwd_uri = pane:get_current_working_dir()
	if not cwd_uri then
		return nil
	end
	-- 新しめの WezTerm は Url オブジェクト（.file_path）、古いと文字列。
	local cwd = cwd_uri.file_path or tostring(cwd_uri)
	cwd = cwd:gsub("^file://[^/]*", ""):gsub("^/([A-Za-z]:)", "%1")
	if cwd == "" then
		return nil
	end
	return cwd
end

local codex_process
local function repair_codex_status(pane)
	local pid = codex_process(pane:get_foreground_process_info())
	if not pid then return end
	wezterm.run_child_process({ "pwsh.exe", "-NoLogo", "-NoProfile", "-File",
		CODEX_SESSION_STATUS_SCRIPT, "-RepairPaneId", tostring(pane:pane_id()), "-OwnerProcessId", tostring(pid) })
end

codex_process = function(info)
	-- Windows reports the newest descendant (often an MCP node process).
	-- Walk its ancestry to the CLI; don't mistake the foreground child for Codex.
	for _ = 1, 16 do
		if not info then return nil end
		if info.executable and info.executable:lower():match("codex%.exe$") then return info.pid end
		if not info.ppid or info.ppid == 0 then return nil end
		info = wezterm.procinfo.get_info_for_pid(info.ppid)
	end
	return nil
end

local function ensure_codex_status(window)
	local focused = window:active_pane()
	-- Scan all tabs: inactive parallel sessions need their own renderer as well.
	local requests = wezterm.GLOBAL.codex_status_requests or {}
	local now = os.time()
	local existing = {}
	for _, tab in ipairs(window:mux_window():tabs()) do
		for _, pane in ipairs(tab:panes()) do
			local key = pane:get_title():match("^Codex status:(%d+:%d+)$")
			if key then existing[key] = true end
		end
	end
	for _, tab in ipairs(window:mux_window():tabs()) do
		for _, pane in ipairs(tab:panes()) do
			local prefix, model = pane:get_title():match("^codex | ([%x%-]+)%.%.%. | (.+)$")
			if not prefix then prefix, model = pane:get_title():match("^codex | ([%x%-]+) | (.+)$") end
			if prefix and #prefix >= 29 then
				local owner = tostring(pane:pane_id())
				if not requests[owner] or now - requests[owner] >= 10 then
					local pid = codex_process(pane:get_foreground_process_info())
					if pid and not existing[tostring(pid) .. ":" .. owner] then
						requests[owner] = now
						pane:split({ direction = "Bottom", size = 4, cwd = pane_cwd(pane), args = {
							"pwsh.exe", "-NoLogo", "-NoProfile", "-File",
							CODEX_SESSION_STATUS_SCRIPT:gsub("session%-status%.ps1$", "statusline.ps1"),
							"-Watch", "-OwnerPaneId", owner, "-OwnerProcessId", tostring(pid),
							"-SessionPrefix", prefix, "-InitialModel", model } })
						if focused then focused:activate() end
					end
				end
			end
		end
	end
	wezterm.GLOBAL.codex_status_requests = requests
end

-- Splitting the status renderer must target its Codex owner instead.
local function split_session(direction)
	return wezterm.action_callback(function(window, pane)
		local owner = pane:get_title():match("^Codex status:%d+:(%d+)$")
		if owner then
			for _, tab in ipairs(window:mux_window():tabs()) do
				for _, candidate in ipairs(tab:panes()) do
					if candidate:pane_id() == tonumber(owner) then pane = candidate end
				end
			end
		end
		local created = pane:split({ direction = direction, cwd = pane_cwd(pane) })
		created:activate()
	end)
end

-- 2026-06-05: ファイルパスを nvim（新規ウィンドウ）で開く共通関数。
-- Ctrl+Click（hyperlink → open-uri）と Ctrl+Shift+O（選択 / QuickSelect）の
-- 3 経路すべてがここに集約される。
local function open_path_in_nvim(window, pane, path)
	if not path or path == "" then
		return
	end
	path = path:gsub("^%s+", ""):gsub("%s+$", "")
	local spawn = { args = { "nvim", path } }
	-- ペイン cwd を nvim の作業ディレクトリへ（相対パス解決のため。OSC 7 必須）
	local cwd = pane_cwd(pane)
	if cwd then
		spawn.cwd = cwd
	end
	window:perform_action(act.SpawnCommandInNewWindow(spawn), pane)
end

-- コピーして copy_mode を抜ける（y と Enter が同一挙動なので 1 箇所に定義）。
-- 注意: ClearPattern は副作用で search overlay を表示することがあるため**使わない**
-- （troubleshooting 第 3 項）。
local function copy_and_close()
	return act.Multiple({
		{ CopyTo = "ClipboardAndPrimarySelection" },
		{ CopyMode = "Close" },
	})
end

----------------------------------------------------
-- キーバインド（2026-04-21: WezTerm デフォルトに戻した）
-- 以下 4 行を有効化すると tmux 風カスタムに復帰。設定は keybinds.lua.legacy に退避済
-- （復帰時はまず keybinds.lua に戻す。require("keybinds") は .legacy 拡張子を解決しない）。
----------------------------------------------------
-- config.disable_default_key_bindings = true
-- config.keys = require("keybinds").keys
-- config.key_tables = require("keybinds").key_tables
-- config.leader = { key = "q", mods = "CTRL", timeout_milliseconds = 2000 }

config.keys = {
	{ key = '"', mods = "CTRL|ALT", action = split_session("Bottom") },
	{ key = '"', mods = "CTRL|ALT|SHIFT", action = split_session("Bottom") },
	{ key = "'", mods = "CTRL|ALT|SHIFT", action = split_session("Bottom") },
	{ key = "%", mods = "CTRL|ALT", action = split_session("Right") },
	{ key = "%", mods = "CTRL|ALT|SHIFT", action = split_session("Right") },
	{ key = "5", mods = "CTRL|ALT|SHIFT", action = split_session("Right") },

	-- タブ全体とペイン単体の終了を明示的に分ける。
	{ key = "w", mods = "CTRL|SHIFT", action = act.CloseCurrentTab({ confirm = true }) },
	{ key = "w", mods = "CTRL|SHIFT|ALT", action = act.CloseCurrentPane({ confirm = true }) },
	-- 2026-05-22: copy_mode の入口を明示バインド（デフォルト table への依存をやめる保険）
	{ key = "x", mods = "CTRL|SHIFT", action = act.ActivateCopyMode },
	-- 2026-05-22: nvim を別ウィンドウで起動（上モニターへドラッグ用）
	{ key = "I", mods = "CTRL|SHIFT", action = act.SpawnCommandInNewWindow({ args = { "nvim", "." } }) },
	-- Ctrl+Shift+Y → 現在のペイン下端へ Codex の4段ステータスを追加。
	-- 稼働中の Codex セッションへ後付けする用途。
	{
		key = "Y",
		mods = "CTRL|SHIFT",
		action = wezterm.action_callback(function(_window, pane)
			repair_codex_status(pane)
		end),
	},
	-- Ctrl+Shift+N → Codex 本体 + 下端5セルの4段ステータスを新規ウィンドウで起動。
	{
		key = "N",
		mods = "CTRL|SHIFT",
		action = wezterm.action_callback(function(_window, pane)
			local cwd = pane_cwd(pane)
			wezterm.mux.spawn_window({ args = { "pwsh.exe", "-NoLogo", "-NoProfile", "-File",
				CODEX_SESSION_STATUS_SCRIPT:gsub("session%-status%.ps1$", "start-codex.ps1") }, cwd = cwd })
		end),
	},
	-- 2026-05-29: ペイン入れ替え（分割の向きは変えられないが中身の位置交換は可能）
	-- Ctrl+Shift+S → アクティブペインと選択ペインをスワップ。各ペインにラベルが出るので
	-- 表示された文字を打って相手を指定（3 ペイン以上でも狙って交換できる）。
	{ key = "S", mods = "CTRL|SHIFT", action = act.PaneSelect({ mode = "SwapWithActive" }) },
	-- Ctrl+Shift+E → ペイン回転。2 ペインなら押すだけで位置交換（ラベル不要・最速）。
	{ key = "E", mods = "CTRL|SHIFT", action = act.RotatePanes("Clockwise") },
	-- 2026-06-05: 画面に出ているファイルパスを nvim で開く。
	-- マウスで選択中のパスがあればそれを開く（最確実・IME 無関係）。
	-- 選択が無ければ数字ラベル QuickSelect にフォールバック。
	{
		key = "O",
		mods = "CTRL|SHIFT",
		action = wezterm.action_callback(function(window, pane)
			local sel = window:get_selection_text_for_pane(pane)
			if sel and sel:gsub("%s", "") ~= "" then
				open_path_in_nvim(window, pane, sel)
				return
			end
			window:perform_action(
				act.QuickSelectArgs({
					label = "open in nvim",
					-- 数字ラベル: IME ON でも素通しする（a/s/d… は IME に吸われるため避ける）
					alphabet = "123456789",
					patterns = { PATH_PATTERN },
					action = wezterm.action_callback(function(w, p)
						open_path_in_nvim(w, p, w:get_selection_text_for_pane(p))
					end),
				}),
				pane
			)
		end),
	},
}

----------------------------------------------------
-- copy_mode（2026-05-22）
-- Ctrl+Shift+X で起動 → 矢印 or hjkl で移動 → y/Enter でコピー。
-- 注意: config.key_tables.copy_mode は WezTerm デフォルトを**完全置換**する
-- （fall through しない）ので、必要なキーは全部ここに書くこと。
----------------------------------------------------
config.key_tables = {
	copy_mode = {
		-- カーソル移動（矢印キーを優位に: hjkl が他層に取られても確実）
		{ key = "LeftArrow", mods = "NONE", action = act.CopyMode("MoveLeft") },
		{ key = "DownArrow", mods = "NONE", action = act.CopyMode("MoveDown") },
		{ key = "UpArrow", mods = "NONE", action = act.CopyMode("MoveUp") },
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
		{ key = "PageUp", mods = "NONE", action = act.CopyMode("PageUp") },
		{ key = "PageDown", mods = "NONE", action = act.CopyMode("PageDown") },
		{ key = "Home", mods = "NONE", action = act.CopyMode("MoveToScrollbackTop") },
		{ key = "End", mods = "NONE", action = act.CopyMode("MoveToScrollbackBottom") },
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
		{ key = "V", mods = "SHIFT", action = act.CopyMode({ SetSelectionMode = "Line" }) },
		{ key = "Space", mods = "NONE", action = act.CopyMode({ SetSelectionMode = "Cell" }) },
		{ key = "v", mods = "CTRL", action = act.CopyMode({ SetSelectionMode = "Block" }) },
		-- コピーして抜ける
		{ key = "y", mods = "NONE", action = copy_and_close() },
		{ key = "Enter", mods = "NONE", action = copy_and_close() },
		-- 抜ける（何もコピーせず）
		{ key = "Escape", mods = "NONE", action = act.CopyMode("Close") },
		{ key = "q", mods = "NONE", action = act.CopyMode("Close") },
		{ key = "c", mods = "CTRL", action = act.CopyMode("Close") },
	},
}

----------------------------------------------------
-- マウス
-- 2026-06-05: Ctrl+Click でファイルパスを nvim（新規ウィンドウ）で開く。
-- ラベル入力が不要なので IME の影響を一切受けない（クリックするだけ）。
-- 2026-07-02: 既定のプレーンクリック CompleteSelectionOrOpenLinkAtMouseCursor は
-- パス文字列を軽くクリックしただけで nvim を開く事故を起こすので選択完了のみに戻し、
-- OpenLink は Ctrl+Click に明示バインドする。
-- 注意: config.mouse_bindings は key_tables と違い**既定とマージ**される。
-- ＝消したい既定バインドは「明示的に別アクションで上書き」しないと生き残る。
----------------------------------------------------
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
	-- 2026-07-06: Shift+Click / Shift+Alt+Click にも既定の
	-- CompleteSelectionOrOpenLinkAtMouseCursor が残っており誤爆経路になるため選択完了のみに封鎖。
	-- 修飾キー stuck（troubleshooting #12）の復旧クリック時に Shift が残っていても安全。
	{
		event = { Up = { streak = 1, button = "Left" } },
		mods = "SHIFT",
		action = act.CompleteSelection("ClipboardAndPrimarySelection"),
	},
	{
		event = { Up = { streak = 1, button = "Left" } },
		mods = "SHIFT|ALT",
		action = act.CompleteSelection("PrimarySelection"),
	},
}

----------------------------------------------------
-- hyperlink: パスを nvimopen: スキームに載せて open-uri へ渡す
----------------------------------------------------
config.hyperlink_rules = wezterm.default_hyperlink_rules()
table.insert(config.hyperlink_rules, {
	regex = PATH_PATTERN,
	format = "nvimopen:$0",
})

----------------------------------------------------
-- イベントハンドラ
-- 注意: wezterm.on() の登録は config reload では**解除されない**（troubleshooting 第 2 項）。
-- ハンドラを消した/変えた時は WezTerm の完全再起動が要る。
----------------------------------------------------

-- `wezterm start --always-new-process -- codex` もキー起動と同じ4段構成にする。
wezterm.on("gui-startup", function(command)
	wezterm.mux.spawn_window(command or {})
end)

-- ステータス: コピーモード突入時はカーソルを黄色化（カーソルそのものが標識になる）。
-- UI 要素を追加しない、リサイズもしない、透過変化もしない。
-- set_right_status / set_left_status は旧 addon 残骸対策で空文字を上書き。
wezterm.on("update-status", function(window, _pane)
	local copying = window:active_key_table() == "copy_mode"
	-- CopyMode must keep the viewport and focus intact while selecting text.
	if not copying then ensure_codex_status(window) end
	window:set_right_status("")
	window:set_left_status("")

	-- 過去ハンドラ残骸が opacity を 0.85 等に書き換えるのを抑止するため、
	-- 毎フレーム明示的に WINDOW_OPACITY を override する。
	local overrides = {
		window_background_opacity = WINDOW_OPACITY,
	}

	-- コピーモード等のキーテーブルアクティブ時: カーソル黄色化。
	-- colors は丸ごと置換なので tab_bar も一緒に渡す（渡さないと透過が外れる）。
	if copying then
		overrides.default_cursor_style = "SteadyBlock"
		overrides.colors = {
			cursor_bg = COPY_MODE_CURSOR_COLORS.cursor_bg,
			cursor_fg = COPY_MODE_CURSOR_COLORS.cursor_fg,
			cursor_border = COPY_MODE_CURSOR_COLORS.cursor_border,
			tab_bar = TAB_BAR_COLORS,
			selection_bg = config.colors.selection_bg,
			selection_fg = config.colors.selection_fg,
			copy_mode_active_highlight_bg = config.colors.copy_mode_active_highlight_bg,
			copy_mode_active_highlight_fg = config.colors.copy_mode_active_highlight_fg,
			copy_mode_inactive_highlight_bg = config.colors.copy_mode_inactive_highlight_bg,
			copy_mode_inactive_highlight_fg = config.colors.copy_mode_inactive_highlight_fg,
		}
	end

	-- 2026-09-15: 以前は json_encode 同士の比較で「同じなら呼ばない」としていたが、
	-- Lua テーブルのキー順は不定で、入れ子の colors があるコピーモード中は毎回不一致になる。
	-- 結果、Claude の TUI 再描画ごとに set_config_overrides → 背景（backdrop/透過）が
	-- 点滅して消えていた。モードが切り替わった時だけ適用する（GLOBAL は reload を跨いで残る）。
	-- GLOBAL は入れ子テーブルへの書き込みが反映されない可能性があるので、フラットなキーで持つ。
	local key = "override_mode_" .. tostring(window:window_id())
	local mode = copying and "copy" or "normal"
	if wezterm.GLOBAL[key] ~= mode then
		wezterm.GLOBAL[key] = mode
		window:set_config_overrides(overrides)
	end
end)

-- nvimopen: スキームを横取りして nvim を起動（それ以外の http 等は既定動作に任せる）
wezterm.on("open-uri", function(window, pane, uri)
	local prefix = "nvimopen:"
	if uri:sub(1, #prefix) == prefix then
		open_path_in_nvim(window, pane, uri:sub(#prefix + 1))
		return false -- デフォルトの URL オープンを抑止
	end
end)

return config
