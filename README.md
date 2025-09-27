# codex.nvim

A lightweight Neovim companion for the Codex CLI. It opens Codex inside a dedicated split or floating terminal, so you can send code snippets or entire buffers without leaving your editor.

## Features
- Toggleable horizontal, vertical, or floating Codex terminal
- Automatic `/status` trigger after starting the CLI
- Commands for sending the current buffer or visual selection
- Optional auto-focus on the Codex terminal after sharing context
- Automatically shuts down the Codex CLI when Neovim exits
- Sensible defaults with room for extension (session tracking, log tailing)

## Requirements
- Neovim 0.8 or newer
- [Codex CLI](https://github.com/) installed and available on your `$PATH`

## Installation
Add `codex.nvim` to your plugin manager. With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "yourname/codex.nvim",
  opts = {
    split = "float",
    codex_cmd = { "codex", "--profile", "nvim" },
  },
}
```

With `packer.nvim`:

```lua
use {
  "yourname/codex.nvim",
  config = function()
    require("codex").setup {
      split = "vertical",
      size = 0.35,
    }
  end,
}
```

## Usage
- `require("codex").open()` / `close()` / `toggle()` control the terminal
- `require("codex").actions.send_selection()` shares the active visual selection
- `require("codex").actions.send_buffer()` shares the entire current buffer
- Call `require("codex").send(text)` from Lua to programmatically send content

Example manual mappings:

```lua
vim.keymap.set("n", "<leader>cc", require("codex").toggle, { desc = "Codex: Toggle" })
vim.keymap.set("v", "<leader>cs", require("codex").actions.send_selection, { desc = "Codex: Send selection" })
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
  codex_cmd = { "codex" }, -- command argv used with termopen
  auto_status_delay_ms = 150,
  enable_session_cache = true,
  log_tail_enabled = false,
  focus_after_send = false,
  log_level = "warn",
  autostart = false,
}
```

Setting `split = "float"` opens Codex in a centered floating window. Horizontal and vertical splits honor `size` (use a fraction ≤ 1 for percentages or an absolute number for rows/columns).

When `focus_after_send = true`, the plugin automatically moves the cursor to the Codex terminal after sending a visual selection or buffer so you can review or submit immediately. Set `log_level = "debug"` to emit detailed traces at `stdpath('state') .. '/codex.nvim.log'` for troubleshooting. Tabs in selections respect your buffer settings: if `expandtab` is enabled the plugin expands tabs using the current `tabstop`; otherwise tabs are passed through unchanged. Enable `autostart = true` to spin up the Codex CLI in the background without opening the terminal window.

## Extensibility
`session.lua` and `scratch.lua` are placeholders for advanced workflows like tailing Codex logs or composing multi-turn prompts. Hook into the exported APIs or submit a PR if you need these features sooner.

## Troubleshooting
- Verify `codex` runs in an external terminal
- Use `:messages` to inspect plugin notifications if the terminal fails to spawn
- Set `codex_cmd` to an explicit executable path when Codex is installed outside `$PATH`

## Testing
- Launch Neovim and call `require("codex").toggle()` (or your mapping) with each `split` mode to verify window geometry
- Check that `/status` automatically triggers when the terminal opens
- Highlight code in Visual mode and trigger `require("codex").actions.send_selection()` (or your own keymap)
- Trigger `require("codex").actions.send_buffer()` inside a file with content to ensure Codex receives the full buffer
- Close the window manually to confirm the job shuts down cleanly
- Quit Neovim with Codex running to verify the CLI shuts down without errors
- Run automated specs with plenary: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests" -c "qa"`
  - If plenary isn't in a standard install path, set `PLENARY_PATH=/path/to/plenary.nvim` before running the command

## Roadmap
- Session awareness and rollout log tailing
- Scratch buffer helpers for composing prompts
- Broaden automated test coverage with additional scenarios

## License
[MIT](LICENSE)
