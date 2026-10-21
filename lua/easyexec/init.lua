local M = {}

local snacks_installed, _ = pcall(require, "snacks")
---@class easyexec.Config
---@field window_config table
---@field use_snacks_terminal boolean
---@field input_style? "cmdline"|"popup" nil picks "popup" under LazyVim, else "cmdline"
---@type easyexec.Config
M.config = {
	window_config = {
		split = "below",
		win = 0,
		width = vim.o.columns,
		height = math.floor(vim.o.lines / 5),
	},
	use_snacks_terminal = snacks_installed,
	input_style = nil,
}

-- Following function borrowed from: https://github.com/ViRu-ThE-ViRuS/configs/blob/f2b001b07b0da4c39b3beea00c90f249906d375c/nvim/lua/lib/misc.lua#L27
-- scroll target buffer to end (set cursor to last line)
local function scroll_to_end(bufnr)
	local cur_win = vim.api.nvim_get_current_win()

	-- switch to buf and set cursor
	vim.api.nvim_buf_call(bufnr, function()
		local target_win = vim.api.nvim_get_current_win()
		vim.api.nvim_set_current_win(target_win)

		local target_line = vim.tbl_count(vim.api.nvim_buf_get_lines(0, 0, -1, true))
		vim.api.nvim_win_set_cursor(target_win, { target_line, 0 })
	end)

	-- return to original window
	vim.api.nvim_set_current_win(cur_win)
end

function M.setup(user_config)
	M.config = vim.tbl_deep_extend("force", M.config, user_config or {})
	-- The default window_config is never empty, so remember if the user set one
	M.user_window_config = user_config ~= nil and user_config.window_config ~= nil
end

M.terminal_ready = true
local pending_commands = {}

local function flush_pending()
	local commands = pending_commands
	pending_commands = {}
	if #commands == 0 then
		return
	end

	-- The shell may have exited, e.g. while we waited for its prompt
	local alive = M.current_channel_id ~= nil
		and vim.api.nvim_buf_is_valid(M.current_buffer)
		and pcall(vim.api.nvim_get_chan_info, M.current_channel_id)
		and vim.fn.jobwait({ M.current_channel_id }, 0)[1] == -1
	if not alive then
		vim.notify("easyexec: terminal is closed, command not sent", vim.log.levels.WARN)
		return
	end

	for _, command in ipairs(commands) do
		vim.fn.chansend(M.current_channel_id, command)
	end
	scroll_to_end(M.current_buffer)
end

-- A freshly started shell echoes input that arrives before its prompt is drawn,
-- so hold commands until the terminal has printed something and gone quiet.
-- Returns a function that stops waiting and flushes right away.
local function wait_until_ready(bufnr)
	M.terminal_ready = false
	local timer = vim.uv.new_timer()

	local done = false
	local function ready()
		if done then
			return
		end
		done = true
		timer:stop()
		timer:close()
		-- A newer terminal replaced this one, it runs its own wait
		if bufnr ~= M.current_buffer then
			return
		end
		M.terminal_ready = true
		flush_pending()
	end

	-- Give up waiting on shells that print nothing
	timer:start(5000, 0, vim.schedule_wrap(ready))

	vim.api.nvim_buf_attach(bufnr, false, {
		on_lines = function()
			if done then
				return true -- detach
			end
			local has_output = vim.iter(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)):any(function(line)
				return line:find("%S") ~= nil
			end)
			if has_output then
				timer:stop()
				timer:start(100, 0, vim.schedule_wrap(ready))
			end
		end,
	})

	return ready
end

local ensure_snacks_terminal = function()
	if not vim.api.nvim_buf_is_valid(M.current_buffer) then
		M.current_channel_id = nil
		local existing = require("snacks").terminal.list()[1]
		if existing == nil then
			M.current_buffer = require("snacks").terminal.get().buf
			wait_until_ready(M.current_buffer)
		else
			M.current_buffer = existing.buf
		end
	end

	if M.current_channel_id == nil then
		local all_chans = vim.api.nvim_list_chans()
		for _i, chan in ipairs(all_chans) do
			if chan.buffer == M.current_buffer then
				M.current_channel_id = chan.id
				break
			end
		end
	end
end

local ensure_raw_terminal = function()
	if not vim.api.nvim_buf_is_valid(M.current_buffer) then
		local cur_win = vim.api.nvim_get_current_win()

		local buf = vim.api.nvim_create_buf(false, true)
		M.current_buffer = buf
		vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
		vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

		-- TODO: M.config.window_config can be empty
		local win = vim.api.nvim_open_win(buf, false, M.config.window_config)

		vim.api.nvim_set_current_win(win)

		local stop_waiting
		M.current_channel_id = vim.fn.termopen({ vim.opt.shell:get() }, {
			on_exit = function(_, _, _)
				-- Report commands queued for a shell that died before its prompt
				if stop_waiting then
					stop_waiting()
				end
				if vim.api.nvim_win_is_valid(win) then
					vim.api.nvim_win_close(win, true)
				end
			end,
		})

		stop_waiting = wait_until_ready(buf)
		vim.api.nvim_set_current_win(cur_win)
	end
end

local ensure_terminal = function()
	if M.config.use_snacks_terminal then
		ensure_snacks_terminal()
	else
		ensure_raw_terminal()
	end
end

M.current_channel_id = nil
M.current_buffer = -1
M.last_command = nil

-- Send a command string to the terminal. Prepends Ctrl-U to clear the line,
-- which also acts as a sacrificial byte: if the first byte sent to the
-- terminal is dropped (a Neovim terminal race condition), the Ctrl-U is
-- lost instead of the command's first character.
local function send_to_terminal(command)
	table.insert(pending_commands, "\x15" .. command .. "\n")
	if M.terminal_ready then
		flush_pending()
	end
end

function M.exec()
	-- Checked at call time since LazyVim may finish loading after this module
	local style = M.config.input_style or (_G.LazyVim and "popup" or "cmdline")
	require("easyexec.input").open({ prompt = "Exec", default = M.last_command, style = style }, function(command)
		if command == nil or command == "" then
			return
		end

		ensure_terminal()
		M.last_command = command
		send_to_terminal(command)
	end)
end

function M.reexec()
	if not M.last_command or M.last_command == "" then
		return
	end

	ensure_terminal()
	send_to_terminal(M.last_command)
end

function M.send_visual(lines)
	if not lines then
		-- Called from :EasyexecSendVisual command (visual mode already exited, marks set)
		lines = vim.fn.getregion(vim.fn.getpos("'<"), vim.fn.getpos("'>"), { type = vim.fn.visualmode() })
	end

	if #lines == 0 then
		return
	end

	ensure_terminal()

	M.last_command = table.concat(lines, "\n")
	send_to_terminal(M.last_command)
end

return M
