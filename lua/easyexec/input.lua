local M = {}

---@class easyexec.InputOpts
---@field prompt? string Prompt text
---@field default? string Initial text
---@field style? "cmdline"|"popup" "cmdline" mimics vim.fn.input at the bottom left, "popup" is a bordered box

-- Open a single-line floating buffer to read a command. Uses a real buffer
-- (instead of vim.fn.input) so insert-mode completion can be hooked up via the
-- "easyexec_input" filetype.
-- Resolve a nui-style position ("50%" or a number) within the available space
local function resolve_position(value, available)
	if type(value) == "string" and value:match("^%d+%%$") then
		return math.floor(available * tonumber(value:sub(1, -2)) / 100)
	end
	return tonumber(value) or math.floor(available / 2)
end

-- Look of noice.nvim's input() popup (LazyVim), so the popup matches the
-- rest of the cmdline UI. nil when noice isn't handling the cmdline.
local function noice_style()
	if not package.loaded["noice"] then
		return nil
	end
	local ok, config = pcall(require, "noice.config")
	if not ok or not config.options or not config.options.cmdline.enabled then
		return nil
	end

	local views = config.options.views or {}
	local view = vim.tbl_deep_extend("force", views.cmdline_popup or {}, views.cmdline_input or {})
	local format = config.options.cmdline.format.input or {}

	-- noice creates the "...Input" variants on setup, fall back to the base groups
	local function hl(group)
		return vim.fn.hlexists(group .. "Input") == 1 and group .. "Input" or group
	end

	return {
		position = view.position or {},
		min_width = view.size and view.size.min_width or 60,
		icon = format.icon,
		icon_hl = format.icon_hl_group or hl("NoiceCmdlineIcon"),
		winhighlight = table.concat({
			"Normal:NoiceCmdlinePopup",
			"NormalFloat:NoiceCmdlinePopup",
			"FoldColumn:NoiceCmdlinePopup",
			"FloatBorder:" .. hl("NoiceCmdlinePopupBorder"),
			"FloatTitle:" .. hl("NoiceCmdlinePopupTitle"),
		}, ","),
	}
end

---@param opts easyexec.InputOpts
---@param on_confirm fun(input: string|nil) Called with nil when cancelled
function M.open(opts, on_confirm)
	opts = opts or {}

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
	vim.api.nvim_set_option_value("filetype", "easyexec_input", { buf = buf })
	vim.api.nvim_set_option_value("completefunc", "v:lua.require'easyexec.complete'.complete", { buf = buf })
	-- Keep blink.cmp (LazyVim) from auto-completing buffer words over <Tab>
	vim.b[buf].completion = false

	-- Default may be multi-line (e.g. last command came from send_visual)
	local lines = vim.split(opts.default or "", "\n", { plain = true })
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	local prompt = opts.prompt or "Exec"
	local win
	local noice = opts.style == "popup" and noice_style() or nil
	if noice then
		local height = math.min(#lines, 10)
		local icon = noice.icon and noice.icon .. " " or ""

		-- Grow with the text like noice's "auto" width: fold column padding,
		-- icon, text, cursor and right padding
		local function geometry()
			local text_width = 0
			for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
				text_width = math.max(text_width, vim.fn.strdisplaywidth(line))
			end
			local width = math.min(
				-- noice's min_width excludes its one column of padding on each side
				math.max(noice.min_width + 2, 1 + vim.fn.strdisplaywidth(icon) + text_width + 2),
				vim.o.columns - 4
			)
			-- nui positions the text area and draws the border around it, while
			-- nvim_open_win positions the border's corner, hence the - 1
			return {
				relative = "editor",
				row = math.max(0, resolve_position(noice.position.row, vim.o.lines - height) - 1),
				col = math.max(0, resolve_position(noice.position.col, vim.o.columns - width) - 1),
				width = width,
				height = height,
			}
		end

		win = vim.api.nvim_open_win(
			buf,
			true,
			vim.tbl_extend("force", geometry(), {
				style = "minimal",
				border = "rounded",
				title = " " .. prompt .. " ",
				title_pos = "center",
			})
		)
		vim.api.nvim_set_option_value("winhighlight", noice.winhighlight, { win = win })
		vim.api.nvim_set_option_value("foldcolumn", "1", { win = win })
		if icon ~= "" then
			vim.api.nvim_buf_set_extmark(buf, vim.api.nvim_create_namespace("easyexec_input"), 0, 0, {
				virt_text = { { icon, noice.icon_hl } },
				virt_text_pos = "inline",
				right_gravity = false,
			})
		end
		vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
			buffer = buf,
			callback = function()
				if vim.api.nvim_win_is_valid(win) then
					vim.api.nvim_win_set_config(win, geometry())
					-- Text typed while the window was narrower left it scrolled
					vim.api.nvim_win_call(win, function()
						vim.fn.winrestview({ leftcol = 0 })
					end)
				end
			end,
		})
	elseif opts.style == "popup" then
		local width = math.max(40, math.floor(vim.o.columns * 0.6))
		win = vim.api.nvim_open_win(buf, true, {
			relative = "editor",
			-- 80% up the screen rather than centered
			row = math.floor(vim.o.lines * 0.2),
			col = math.floor((vim.o.columns - width) / 2),
			width = width,
			height = math.min(#lines, 10),
			style = "minimal",
			border = "rounded",
			title = " " .. prompt .. " ",
			title_pos = "left",
		})
		-- Empty fold column as left padding inside the border
		vim.api.nvim_set_option_value("foldcolumn", "1", { win = win })
	else
		local height = math.min(#lines, 10)
		win = vim.api.nvim_open_win(buf, true, {
			relative = "editor",
			row = vim.o.lines - height,
			col = 0,
			width = vim.o.columns,
			height = height,
			style = "minimal",
			border = "none",
			zindex = 250,
		})
		-- Look like the command line, not a float
		vim.api.nvim_set_option_value("winhighlight", "NormalFloat:MsgArea", { win = win })
		-- Inline virtual text keeps the prompt out of the buffer contents
		vim.api.nvim_buf_set_extmark(buf, vim.api.nvim_create_namespace("easyexec_input"), 0, 0, {
			virt_text = { { prompt .. ": ", "Normal" } },
			virt_text_pos = "inline",
			right_gravity = false,
		})
	end
	vim.api.nvim_set_option_value("wrap", false, { win = win })
	-- A global sidescrolloff (LazyVim sets 8) scrolls the text before it reaches the edge
	vim.api.nvim_set_option_value("sidescrolloff", 0, { win = win })

	local done = false
	local function finish(value)
		if done then
			return
		end
		done = true
		vim.cmd.stopinsert()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
		-- Defer so the callback runs after the window is gone and insert mode has ended
		vim.schedule(function()
			on_confirm(value)
		end)
	end

	local function confirm()
		finish(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"))
	end

	local function cancel()
		finish(nil)
	end

	local map_opts = { buffer = buf, nowait = true }
	vim.keymap.set("n", "<CR>", confirm, map_opts)
	vim.keymap.set("i", "<CR>", function()
		-- Accept a selected completion instead of running the command
		if vim.fn.pumvisible() == 1 and vim.fn.complete_info({ "selected" }).selected ~= -1 then
			vim.api.nvim_feedkeys(vim.keycode("<C-y>"), "n", false)
		else
			confirm()
		end
	end, map_opts)
	vim.keymap.set({ "i", "n" }, "<C-c>", cancel, map_opts)
	vim.keymap.set("n", "<Esc>", cancel, map_opts)
	vim.keymap.set("n", "q", cancel, map_opts)

	-- Shell completion on <Tab>, cycling through matches while the menu is open
	local expr_opts = { buffer = buf, nowait = true, expr = true }
	vim.keymap.set("i", "<Tab>", function()
		return vim.fn.pumvisible() == 1 and "<C-n>" or "<C-x><C-u>"
	end, expr_opts)
	vim.keymap.set("i", "<S-Tab>", function()
		return vim.fn.pumvisible() == 1 and "<C-p>" or "<S-Tab>"
	end, expr_opts)

	vim.api.nvim_create_autocmd("WinLeave", {
		buffer = buf,
		once = true,
		callback = cancel,
	})

	vim.api.nvim_win_set_cursor(win, { #lines, 0 })
	vim.cmd.startinsert({ bang = true })
end

return M
