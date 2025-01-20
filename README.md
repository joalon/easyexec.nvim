# Easyexec

A Neovim plugin for running commands in the terminal.


## Installation

I'm using lazy:

```
{
  "joalon/easyexec.nvim",
  keys = { {"<leader>xe", "<cmd>Easyexec<cr>", desc = "Easyexec"} },
}
```

## Usage

Execute the Easyexec user command `:Easyexec` or bind it to a key `<cmd>Easyexec<cr>`. It will ask for a command to run and execute it in a new terminal. Subsequent runs will reuse the terminal.

## Configuration

By default Easyexec opens a split to the right with a terminal buffer inside. To customize the window you can pass a table with a window configuration, for example:

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

For more information on the window API refer to the Neovim `api-win_config` documentation.
