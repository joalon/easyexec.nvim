# Send Visual Selection to Terminal — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `send_visual()` function that sends the current visual selection to the open terminal and executes it.

**Architecture:** Extract terminal-ensuring logic from `exec_snacks`/`exec_raw` into standalone helpers, then add `send_visual()` that reuses them. New `<Plug>` keymap and user command for visual mode.

**Tech Stack:** Neovim Lua API, `vim.fn.getregion`, `vim.fn.chansend`

**Note on testing:** This project has no test framework. Steps include manual verification instructions in Neovim instead of automated tests.

---

### Task 1: Extract `ensure_terminal` helpers from existing exec functions

**Files:**
- Modify: `lua/easyexec/init.lua:40-94`

The terminal-opening logic is currently coupled with command sending in `exec_snacks` and `exec_raw`. Extract the "ensure terminal is open and channel is set" part so `send_visual()` can reuse it.

- [ ] **Step 1: Extract `ensure_snacks_terminal()`**

Extract lines 41-58 of `exec_snacks` into a new local function. The remaining `exec_snacks` calls the helper then sends the command.

```lua
local ensure_snacks_terminal = function()
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
end

local exec_snacks = function(command)
	ensure_snacks_terminal()
	vim.fn.chansend(M.current_channel_id, { command, "" })
	M.last_command = command
	scroll_to_end(M.current_buffer)
end
```

- [ ] **Step 2: Extract `ensure_raw_terminal()`**

Extract lines 67-89 of `exec_raw` into a new local function.

```lua
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

		M.current_channel_id = vim.fn.termopen({ vim.opt.shell:get() }, {
			on_exit = function(_, _, _)
				if vim.api.nvim_win_is_valid(win) then
					vim.api.nvim_win_close(win, true)
				end
			end,
		})

		vim.api.nvim_set_current_win(cur_win)
	end
end

local exec_raw = function(command)
	ensure_raw_terminal()
	vim.fn.chansend(M.current_channel_id, { command, "" })
	M.last_command = command
	scroll_to_end(M.current_buffer)
end
```

- [ ] **Step 3: Add `ensure_terminal()` dispatcher**

Add a local function that picks the right backend based on config:

```lua
local ensure_terminal = function()
	if M.config.use_snacks_terminal then
		ensure_snacks_terminal()
	else
		ensure_raw_terminal()
	end
end
```

- [ ] **Step 4: Verify existing functionality**

Open Neovim, run `:Easyexec`, type `echo hello`. Confirm terminal opens and command runs. Run `:Easyexec` again with a different command — confirm terminal is reused.

- [ ] **Step 5: Commit**

```bash
git add lua/easyexec/init.lua
git commit -m "refactor: extract ensure_terminal helpers from exec functions"
```

---

### Task 2: Add `send_visual()` function

**Files:**
- Modify: `lua/easyexec/init.lua` (add function after `reexec`)

- [ ] **Step 1: Add `M.send_visual()`**

```lua
function M.send_visual()
	local lines = vim.fn.getregion(vim.fn.getpos("'<"), vim.fn.getpos("'>"), { type = vim.fn.visualmode() })

	if #lines == 0 then
		return
	end

	ensure_terminal()

	M.last_command = table.concat(lines, "\n")
	table.insert(lines, "")
	vim.fn.chansend(M.current_channel_id, lines)
	scroll_to_end(M.current_buffer)
end
```

Key details:
- `vim.fn.getregion()` returns a list of selected lines (Neovim 0.10+)
- `vim.fn.visualmode()` ensures correct mode (charwise `v`, linewise `V`, blockwise `<C-v>`)
- `vim.list_extend(lines, { "" })` appends a trailing empty string so chansend sends a final newline (consistent with existing `{ command, "" }` pattern)
- `table.concat(lines, "\n")` stores the full text as `last_command` for reexec

- [ ] **Step 2: Verify in Neovim**

Open a file with a few lines like:
```
echo "line 1"
echo "line 2"
```
Visually select both lines, then run `:lua require("easyexec").send_visual()`. Confirm:
- Terminal opens (if not already open)
- Both lines execute in the terminal
- Output shows "line 1" then "line 2"

- [ ] **Step 3: Verify reexec works after send_visual**

After the previous step, call `:lua require("easyexec").reexec()`. Confirm the same two lines execute again.

- [ ] **Step 4: Commit**

```bash
git add lua/easyexec/init.lua
git commit -m "feat: add send_visual() to send visual selection to terminal"
```

---

### Task 3: Add keymap and user command

**Files:**
- Modify: `plugin/easyexec.lua`

- [ ] **Step 1: Add visual mode keymap and user command**

Append before the end of `plugin/easyexec.lua`:

```lua
vim.keymap.set("x", "<Plug>(EasyexecSendVisual)", function()
	require("easyexec").send_visual()
end, { noremap = true })

vim.api.nvim_create_user_command("EasyexecSendVisual", function()
	require("easyexec").send_visual()
end, {
	range = true,
	desc = "Send visual selection to terminal",
})
```

- [ ] **Step 2: Verify keymap**

In Neovim, add a test binding: `:xmap <leader>s <Plug>(EasyexecSendVisual)`

Open a file, visually select text, press `<leader>s`. Confirm terminal opens and selection executes.

- [ ] **Step 3: Verify user command with range**

Visually select lines, type `:'<,'>EasyexecSendVisual`. Confirm it works the same way.

- [ ] **Step 4: Commit**

```bash
git add plugin/easyexec.lua
git commit -m "feat: add EasyexecSendVisual keymap and command"
```

---

### Task 4: Update README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add send_visual documentation**

Add the new keymap to the keymaps section and document the new function/command in the appropriate sections of the README. Follow the existing documentation style.

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add send_visual documentation to README"
```
