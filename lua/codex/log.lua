local M = {}

local levels = {
  trace = 0,
  debug = 1,
  info = 2,
  warn = 3,
  error = 4,
}

local logfile
local current_level = levels.warn

local function resolve_path()
  if logfile then
    return logfile
  end
  local dir = vim.fn.stdpath("state") or vim.fn.stdpath("cache")
  local path = vim.fs.joinpath(dir, "codex.nvim.log")
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  logfile = path
  return logfile
end

local function should_log(level)
  return level >= current_level
end

local function append(line)
  local path = resolve_path()
  local fd = io.open(path, "a")
  if not fd then
    return
  end
  fd:write(line)
  fd:write("\n")
  fd:close()
end

local function fmt(level_name, msg)
  local ts = os.date("%Y-%m-%d %H:%M:%S")
  return string.format("[%s][%s] %s", ts, level_name:upper(), msg)
end

local function serialize(value)
  if type(value) == "string" then
    return value
  end
  local ok, dumped = pcall(vim.inspect, value)
  if ok then
    return dumped
  end
  return tostring(value)
end

local function log(level_name, ...)
  local level = levels[level_name]
  if not level or not should_log(level) then
    return
  end
  local chunks = {}
  for i = 1, select("#", ...) do
    local part = select(i, ...)
    chunks[#chunks + 1] = serialize(part)
  end
  append(fmt(level_name, table.concat(chunks, " ")))
end

function M.set_level(level_name)
  local level = levels[level_name]
  if level then
    current_level = level
  end
end

function M.trace(...)
  log("trace", ...)
end

function M.debug(...)
  log("debug", ...)
end

function M.info(...)
  log("info", ...)
end

function M.warn(...)
  log("warn", ...)
end

function M.error(...)
  log("error", ...)
end

function M.path()
  return resolve_path()
end

return M
