local M = {}

function M.reset()
  M.session_id = nil
end

function M.on_status_line(_line)
  -- future enhancement: parse /status output
end

M.reset()

return M
