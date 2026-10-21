# Easyexec

A Neovim plugin for running commands in a terminal split.

![Demo](https://gist.githubusercontent.com/joalon/6917e4aab8911ff3a88ea1cde3467505/raw/b7fe68448af9efcf165c69f3b39656c5d792ea8e/output.gif)

## Installation

I'm using lazy:

```
{
  "joalon/easyexec.nvim",
  keys = {
    {"<M-t>", "<Plug>(Easyexec)", desc = "Easy exec"},
    {"<M-Shift-t>", "<Plug>(EasyexecReexec)", desc = "Easy re-exec"},
    {"<M-s>", "<Plug>(EasyexecSendVisual)", mode = "x", desc = "Send visual selection to terminal"},
  },
}
```

## Usage

Execute the Easyexec user command `:Easyexec` or bind it to a key `<cmd>Easyexec<cr>`.
It will ask for a command to run and execute it in a new terminal. Subsequent run
will reuse the terminal.

The command is entered in a small input buffer (filetype `easyexec_input`),
prefilled with the last command. `<CR>` runs it; `<C-c>`, or `<Esc>`/`q` in normal
mode, cancels.

`<Tab>` completes shell commands, file paths and `$VARIABLES`, and cycles through
matches (`<S-Tab>` goes back). `<CR>` on a selected match accepts it. Paths are
completed relative to Neovim's working directory.

You can also send a visual selection to the terminal. Select text in visual mode and use `:EasyexecSendVisual` or bind `<Plug>(EasyexecSendVisual)` to a key.

## Configuration

By default Easyexec uses `snacks.terminal`, if its installed, to open a terminal.
It can also take a window configuration according to the Neovim `api-win_config`
documentation.

```
{
  "joalon/easyexec.nvim",
  opts = { window_config = { split = "left" } },
}
```

Or for a simple floating window:

```
opts = {
  window_config = {
    style = "minimal",
    relative = "win",
    width = math.floor(vim.o.columns / 3),
    height = vim.o.lines,
    row = 1,
    col = math.floor(vim.o.columns / 3) * 2,
    border = "rounded",
  }
}
```

To turn off the snacks.nvim integration you can set `opts.use_snacks_terminal = false`.

The command prompt has two styles, set with `opts.input_style`:

- `"cmdline"`: an unstyled `Exec: ` prompt at the bottom left, like `input()`
- `"popup"`: a bordered floating box. With noice.nvim it copies the look and
  position of noice's cmdline popup.

It defaults to `"popup"` when running under LazyVim and `"cmdline"` otherwise.
