local M = {}

M.current_channel_id = nil
M.current_buffer = -1
M.last_command = nil

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

function M.exec()
	local command = vim.fn.input({ prompt = "Exec: ", default = M.last_command })

	if command == nil or command == "" then
		return
	end

	-- Create window if not already there
	if vim.fn.bufnr(M.current_buffer) == -1 then
		local cur_win = vim.api.nvim_get_current_win()

		local buf = vim.api.nvim_create_buf(false, true)
		M.current_buffer = buf
		vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
		vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

		local win = vim.api.nvim_open_win(buf, false, {
			split = "right",
		})

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

return M
