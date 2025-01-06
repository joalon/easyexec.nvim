vim.api.nvim_create_user_command("Easyexec", function()
	require("easyexec").exec()
end, {
	desc = "Execute a command",
})
