local M = {}

M.current_channel_id = nil
M.current_buffer = -1
M.last_command = nil

function M.exec()
	local command = vim.fn.input({ prompt = "Exec: ", default = M.last_command })

	-- Create window if not already there
	if vim.fn.bufnr(M.current_buffer) == -1 then
		local buf = vim.api.nvim_create_buf(false, true)
		M.current_buffer = buf
		vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
		vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

		local win = vim.api.nvim_open_win(buf, false, {
			split = "right",
		})

		vim.api.nvim_set_current_win(win)

		M.current_channel_id = vim.fn.termopen({ "bash" }, {
			on_exit = function(_, _, _)
				if vim.api.nvim_win_is_valid(win) then
					vim.api.nvim_win_close(win, true)
				end
			end,
		})
	end

	vim.fn.chansend(M.current_channel_id, { command, "" })
	M.last_command = command
end

return M
