local M = {}

local defaults = {
	split = "horizontal", -- horizontal|vertical|float
	size = 0.3, -- percentage of total width/height for splits
	float = {
		width = 0.6,
		height = 0.6,
		border = "rounded",
		row = nil,
		col = nil,
		title = "Codex",
	},
	codex_cmd = { "codex" },
	auto_status_delay_ms = 0,
	enable_session_cache = true,
	log_tail_enabled = false,
	focus_after_send = false,
	log_level = "warn",
	autostart = false,
}

local options = vim.deepcopy(defaults)

---Merge user supplied options into defaults.
---@param opts table|nil
function M.setup(opts)
	if opts and type(opts) == "table" then
		options = vim.tbl_deep_extend("force", {}, defaults, opts)
	else
		options = vim.deepcopy(defaults)
	end
	local log = require("codex.log")
	log.set_level(options.log_level or "warn")
	return options
end

---Return a copy of the effective configuration so modules cannot mutate state accidentally.
---@return table
function M.get()
	return vim.deepcopy(options)
end

---Expose defaults for documentation/tests.
---@return table
function M.defaults()
	return vim.deepcopy(defaults)
end

return M
