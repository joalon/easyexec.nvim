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
  },
}
```

## Usage

Execute the Easyexec user command `:Easyexec` or bind it to a key `<cmd>Easyexec<cr>`.
It will ask for a command to run and execute it in a new terminal. Subsequent run
will reuse the terminal.

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
