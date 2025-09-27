local api = vim.api
local M = {}

M.state = {
  bufnr = nil,
  winid = nil,
  layout = nil,
}

local function normalized_size(size, total, fallback)
  total = math.max(total, 1)
  if type(size) ~= "number" then
    size = fallback
  end
  if type(size) ~= "number" then
    size = math.floor(total * 0.3)
  end
  if size > 0 and size <= 1 then
    size = total * size
  end
  size = math.floor(size + 0.5)
  size = math.max(1, size)
  size = math.min(size, math.max(total - 1, 1))
  return size
end

local function ensure_buffer(bufnr)
  if bufnr and api.nvim_buf_is_valid(bufnr) then
    return bufnr
  end
  bufnr = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(bufnr, "bufhidden", "hide")
  return bufnr
end

---Open a window for the Codex terminal according to configuration.
---@param conf table
---@param bufnr integer|nil
---@return integer winid
---@return integer bufnr
function M.open_window(conf, bufnr)
  local state = M.state
  bufnr = ensure_buffer(bufnr or state.bufnr)

  if state.winid and api.nvim_win_is_valid(state.winid) then
    if api.nvim_win_get_buf(state.winid) ~= bufnr then
      api.nvim_win_set_buf(state.winid, bufnr)
    end
    state.bufnr = bufnr
    return state.winid, bufnr
  end

  local layout = conf.split or "horizontal"
  local winid

  if layout == "horizontal" then
    local height = normalized_size(conf.size or 0.3, vim.o.lines, 10)
    vim.cmd("botright " .. height .. "split")
    winid = api.nvim_get_current_win()
  elseif layout == "vertical" then
    local width = normalized_size(conf.size or 0.3, vim.o.columns, math.floor(vim.o.columns * 0.3))
    vim.cmd("botright " .. width .. "vsplit")
    winid = api.nvim_get_current_win()
  elseif layout == "float" then
    local float = conf.float or {}
    local ui = vim.api.nvim_list_uis()[1]
    local total_width = ui and ui.width or vim.o.columns
    local total_height = ui and ui.height or vim.o.lines

    local width = float.width or 0.6
    if width > 0 and width <= 1 then
      width = total_width * width
    end
    local height = float.height or 0.6
    if height > 0 and height <= 1 then
      height = total_height * height
    end

    width = math.floor(width + 0.5)
    height = math.floor(height + 0.5)

    local max_width = math.max(total_width - 4, 1)
    local max_height = math.max(total_height - 4, 1)

    width = math.max(1, math.min(width, max_width))
    height = math.max(1, math.min(height, max_height))

    local row = float.row
    if not row then
      row = math.floor((total_height - height) / 2)
    end
    local col = float.col
    if not col then
      col = math.floor((total_width - width) / 2)
    end

    local opts = {
      relative = "editor",
      width = width,
      height = height,
      row = row,
      col = col,
      style = "minimal",
      border = float.border or "rounded",
      title = float.title or "Codex",
    }

    winid = api.nvim_open_win(bufnr, true, opts)
    if float.padding then
      pcall(vim.api.nvim_win_set_config, winid, { padding = float.padding })
    else
      pcall(vim.api.nvim_win_set_config, winid, { padding = { 0, 1, 0, 1 } })
    end
  else
    error("codex.nvim: invalid split option '" .. tostring(layout) .. "'")
  end

  api.nvim_win_set_buf(winid, bufnr)
  api.nvim_set_current_win(winid)

  state.winid = winid
  state.bufnr = bufnr
  state.layout = layout

  return winid, bufnr
end

function M.close_window()
  local state = M.state
  if state.winid and api.nvim_win_is_valid(state.winid) then
    pcall(api.nvim_win_close, state.winid, true)
  end
  state.winid = nil
end

function M.is_open()
  return M.state.winid ~= nil and api.nvim_win_is_valid(M.state.winid)
end

function M.focus()
  local winid = M.state.winid
  if winid and api.nvim_win_is_valid(winid) then
    api.nvim_set_current_win(winid)
  end
end

return M
