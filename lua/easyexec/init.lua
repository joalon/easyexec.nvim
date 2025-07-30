local M = {}

local snacks_installed, _ = pcall(require, "snacks")
---@class easyexec.Config
---@field window_config table
---@field use_snacks_terminal boolean
---@type easyexec.Config
M.config = {
	window_config = {
		split = "below",
		win = 0,
		width = vim.o.columns,
		height = math.floor(vim.o.lines / 5),
	},
	use_snacks_terminal = snacks_installed,
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
end

local exec_snacks = function(command)
	if not vim.api.nvim_buf_is_valid(M.current_buffer) then
		local existing = require("snacks").terminal.list()[1]
		if existing == nil then
			M.current_buffer = require("snacks").terminal.get().buf
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

	vim.fn.chansend(M.current_channel_id, { command, "" })
	M.last_command = command
	scroll_to_end(M.current_buffer)
end

local exec_raw = function(command)
	-- Create window if not already there
	if not vim.api.nvim_buf_is_valid(M.current_buffer) then
		local cur_win = vim.api.nvim_get_current_win()

		local buf = vim.api.nvim_create_buf(false, true)
		M.current_buffer = buf
		vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
		vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

		-- TODO: M.config.window_config can be empty
		local win = vim.api.nvim_open_win(buf, false, M.config.window_config)

		vim.api.nvim_set_current_win(win)

		M.current_channel_id = vim.fn.termopen({ vim.opt.shell:get() }, {
			on_exit = function(_, _, _)
				if vim.api.nvim_win_is_valid(win) then
					vim.api.nvim_win_close(win, true)
				end
			end,
		})

		vim.api.nvim_set_current_win(cur_win)
	end

	vim.fn.chansend(M.current_channel_id, { command, "" })
	M.last_command = command
	scroll_to_end(M.current_buffer)
end

M.current_channel_id = nil
M.current_buffer = -1
M.last_command = nil

function M.exec()
	local command = vim.fn.input({ prompt = "Exec: ", default = M.last_command })

	if command == nil or command == "" then
		return
	end

	if M.config.use_snacks_terminal then
		exec_snacks(command)
		return
	end

	exec_raw(command)
end

function M.reexec()
	if not M.last_command or M.last_command == "" then
		return
	end

	if M.config.use_snacks_terminal then
		exec_snacks(M.last_command)
		return
	end

	exec_raw(M.last_command)
end

return M
