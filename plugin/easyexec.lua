if vim.g.loaded_easyexec == 1 then
	return
end
vim.g.loaded_easyexec = 1

vim.keymap.set("n", "<Plug>(Easyexec)", function()
	require("easyexec").exec()
end, { noremap = true })

vim.keymap.set("n", "<Plug>(EasyexecReexec)", function()
	require("easyexec").reexec()
end, { noremap = true })

vim.api.nvim_create_user_command("Easyexec", function()
	require("easyexec").exec()
end, {
	desc = "Execute a command",
})

vim.keymap.set("x", "<Plug>(EasyexecSendVisual)", function()
	require("easyexec").send_visual()
end, { noremap = true })

vim.api.nvim_create_user_command("EasyexecSendVisual", function()
	require("easyexec").send_visual()
end, {
	range = true,
	desc = "Send visual selection to terminal",
})
