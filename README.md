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
