# Send Visual Selection to Terminal

## Summary

Add a new function `send_visual()` to easyexec.nvim that sends the current visual selection directly to the open terminal and executes it. If no terminal is open, one is created automatically using the existing backend (snacks.nvim or native).

## Motivation

Currently easyexec.nvim only accepts commands via a `vim.fn.input()` prompt. Users working with code files often want to select a block of code and run it directly in the terminal — a common workflow when working with scripts, REPLs, or iterating on shell commands stored in files.

## Design

### New function: `M.send_visual()`

Located in `lua/easyexec/init.lua`.

Behavior:

1. Get the visual selection using `vim.fn.getregion(vim.fn.getpos("'<"), vim.fn.getpos("'>"))`, which returns a list of lines.
2. If no terminal is currently open (buffer invalid or channel nil), open one using the same logic as `exec()` — respecting the `use_snacks_terminal` config and `window_config`.
3. Join lines with `"\n"`, send via `vim.fn.chansend(channel_id, joined_text .. "\n")`.
4. Store the joined text as `M.last_command` so `reexec()` works after a visual send.
5. Call `scroll_to_end()` to keep the terminal scrolled to the latest output.

### Terminal-opening refactor

The terminal-opening logic currently lives inline in `exec()`. Extract it into a small helper (e.g., `ensure_terminal()`) so both `exec()` and `send_visual()` can reuse it without duplication.

### New keymap and command

In `plugin/easyexec.lua`:

- `vim.keymap.set("x", "<Plug>(EasyexecSendVisual)", function() require("easyexec").send_visual() end)` — visual mode only.
- `vim.api.nvim_create_user_command("EasyexecSendVisual", function() require("easyexec").send_visual() end, { range = true })` — supports range for visual selection.

### Multiline handling

Multiline selections are sent as a single block (paste-like). Each line is separated by `"\n"`. The terminal shell processes them sequentially. No line-by-line delay.

### Configuration

No new config options. The feature uses existing `window_config` and `use_snacks_terminal` settings.

## Files changed

- `lua/easyexec/init.lua` — add `send_visual()`, extract `ensure_terminal()` helper from `exec()`
- `plugin/easyexec.lua` — add `<Plug>(EasyexecSendVisual)` keymap and `:EasyexecSendVisual` command

## Out of scope

- Line-by-line sending with delays (REPL-friendly mode) — future enhancement if needed
- Sending entire buffer contents
- Operator-pending mode mapping
