local M = {}

function M.check()
	vim.health.start("easyexec report")

	local ok, easyexec = pcall(require, "easyexec")
	if not ok then
		vim.health.error("Failed to load easyexec plugin")
		return
	end

	if not easyexec.config then
		vim.health.error("Configuration not found in easyexec module")
		return
	end

	if easyexec.config.use_snacks_terminal then
		local ok, snacks = pcall(require, "snacks")
		if not ok then
			vim.health.error("use_snacks_terminal is true but snacks plugin not installed")
		else
			vim.health.ok("'snacks' is installed")
		end
	end
end

return M
