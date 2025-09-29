# codex.nvim

`🚧 IN DEVELOPMENT` A lightweight Neovim companion for the Codex CLI. It opens Codex inside a dedicated split or floating terminal, so you can send code snippets without leaving your editor.

## Features

- Toggleable horizontal, vertical, or floating Codex terminal
- Commands for sending visual selection
- Automatically shuts down the Codex CLI when Neovim exits

## Requirements

- Neovim 0.8 or newer
- [Codex CLI](https://github.com/) installed and available on your `$PATH`

## Installation

Add `codex.nvim` to your plugin manager. With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{ "yourname/codex.nvim", }
```

## Usage

- `require("codex").open()` / `close()` / `toggle()` control the terminal
- `require("codex").actions.send_selection()` shares the active visual selection

Example manual mappings:

```lua
vim.keymap.set("n", "<leader>cc", function() require("codex").toggle end, { desc = "Codex: Toggle" })
vim.keymap.set("v", "<leader>cs", function() require("codex").actions.send_selection end, { desc = "Codex: Send selection" })
```

## Configuration

All settings are optional. These are the defaults:

```lua
{
  split = "horizontal", -- horizontal | vertical | float
  size = 0.3,            -- percentage or absolute size for splits
  float = {
    width = 0.6,         -- relative width when <= 1, else absolute columns
    height = 0.6,        -- relative height when <= 1, else absolute rows
    border = "rounded",
    row = nil,
    col = nil,
    title = "Codex",
  },
  codex_cmd = { "codex" },
  focus_after_send = false,
  log_level = "warn",
  autostart = false,
}
```

Setting `split = "float"` opens Codex in a centered floating window. Horizontal and vertical splits honor `size` (use a fraction ≤ 1 for percentages or an absolute number for rows/columns).

When `focus_after_send = true`, the plugin automatically moves the cursor to the Codex terminal after sending a visual selection or buffer so you can review or submit immediately. Set `log_level = "debug"` to emit detailed traces at `stdpath('state') .. '/codex.nvim.log'` for troubleshooting. Tabs in selections respect your buffer settings: if `expandtab` is enabled the plugin expands tabs using the current `tabstop`; otherwise tabs are passed through unchanged. Enable `autostart = true` to spin up the Codex CLI in the background without opening the terminal window.

## License

[MIT](LICENSE)
