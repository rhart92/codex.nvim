local terminal = require("codex.terminal")

local M = {}

function M.open()
  terminal.open()
end

function M.close()
  terminal.close()
end

function M.toggle()
  terminal.toggle()
end

function M.send(text, opts)
  terminal.send(text, opts)
end

function M.send_selection()
  terminal.send_selection()
end

function M.send_buffer()
  terminal.send_buffer()
end

return M
