local M = {}

-- Command line typed up to the cursor, saved by the findstart call
local pending = ""

-- Text after the last |, ;, & so each command in a pipeline or chain completes
-- like a command line of its own
local function current_segment(text)
	local last = 0
	for pos in text:gmatch("()[|;&]") do
		last = pos
	end
	return (text:sub(last + 1):gsub("^%s+", ""))
end

local function candidates(segment)
	local ok, items = pcall(vim.fn.getcompletion, segment, "shellcmdline")
	if ok then
		return items
	end

	-- "shellcmdline" needs Neovim 0.11, fall back to commands or files
	local word = segment:match("%S*$")
	local type = segment:find("%s") and "file" or "shellcmd"
	return vim.fn.getcompletion(word, type)
end

-- 'completefunc' for the input buffer: commands for the first word, files for
-- arguments and environment variables after $
function M.complete(findstart, base)
	if findstart == 1 then
		local col = vim.api.nvim_win_get_cursor(0)[2]
		local before = vim.api.nvim_get_current_line():sub(1, col)
		pending = current_segment(before)

		local start = before:find("[^%s|;&]*$")
		-- Variable names are completed without the $
		if before:sub(start, start) == "$" then
			start = start + 1
		end
		return start - 1
	end

	return candidates(pending)
end

return M
