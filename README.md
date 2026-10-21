# Easyexec

A Neovim plugin for running commands in a terminal split.

![Demo](https://gist.githubusercontent.com/joalon/6917e4aab8911ff3a88ea1cde3467505/raw/b7fe68448af9efcf165c69f3b39656c5d792ea8e/output.gif)

## Requirements

- Neovim 0.10 or later
- Neovim 0.11 for full shell completion (on 0.10 only command names and file paths complete)
- Optional: [snacks.nvim](https://github.com/folke/snacks.nvim) for the terminal,
  [noice.nvim](https://github.com/folke/noice.nvim) for prompt styling

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

| Mapping / command | Description |
|---|---|
| `<Plug>(Easyexec)`, `:Easyexec` | Prompt for a command and run it |
| `<Plug>(EasyexecReexec)` | Run the last command again without prompting |
| `<Plug>(EasyexecSendVisual)`, `:EasyexecSendVisual` | Send the visual selection to the terminal |

When a new terminal is opened, commands are held until the shell has drawn its
prompt, so they don't show up twice.

### The command prompt

The command is entered in a small input buffer, prefilled with the last command.

| Key | Action |
|---|---|
| `<CR>` | Run the command (or accept the selected completion) |
| `<Tab>` / `<S-Tab>` | Complete, then cycle forward / back through matches |
| `<C-c>` | Cancel |
| `<Esc>`, `q` | Cancel (normal mode) |

`<Tab>` completes shell commands, file paths and `$VARIABLES`, also after `|`, `;`
and `&&`. Paths are completed relative to Neovim's working directory, not the
terminal's.

If [bash-completion](https://github.com/scop/bash-completion) is installed,
arguments are completed by the command's own bash completion, e.g. `cargo r` →
`run`, `git ch` → `checkout`, `cargo run --q` → `--quiet`. It runs in the
background, so the menu shows up once bash has answered. Commands without a bash
completion fall back to file paths.

The buffer has filetype `easyexec_input`, so you can hook up your own mappings
or completion in a `FileType` autocmd. It sets `vim.b.completion = false` to keep
blink.cmp from popping up over the shell completion.

### Sending a selection

Select text in visual mode and use `:EasyexecSendVisual` or bind
`<Plug>(EasyexecSendVisual)` to a key. Multi-line selections are sent line by
line and become the last command, so re-exec runs them again.

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

```
opts = { input_style = "cmdline" }
```

## Health

Run `:checkhealth easyexec` to check the setup. It reports a missing snacks.nvim
when `use_snacks_terminal` is on, and warns if you set both `use_snacks_terminal`
and `window_config` (the window config is ignored for snacks terminals).
