local config = require("codex.config")
local actions = require("codex.actions")
local terminal = require("codex.terminal")
local ui = require("codex.ui")
local log = require("codex.log")

local M = {}

local autocmd_registered
local helptags_generated

local function ensure_autocmds()
	if autocmd_registered then
		return
	end
	local group = vim.api.nvim_create_augroup("CodexShutdown", { clear = true })
	vim.api.nvim_create_autocmd({ "QuitPre", "VimLeavePre" }, {
		group = group,
		callback = function()
			actions.close()
		end,
	})
	autocmd_registered = true
end

local function ensure_helptags()
	if helptags_generated then
		return
	end
	local docs = vim.api.nvim_get_runtime_file("doc/codex.txt", false)
	if #docs == 0 then
		return
	end
	local doc_dir = vim.fn.fnamemodify(docs[1], ":h")
	pcall(vim.cmd, ("silent! helptags %s"):format(vim.fn.fnameescape(doc_dir)))
	helptags_generated = true
end

---@param opts table|nil
function M.setup(opts)
	local conf = config.setup(opts)

	log.info("codex setup invoked", { autostart = conf.autostart, split = conf.split })

	ensure_autocmds()
	ensure_helptags()

	if conf.autostart then
		vim.schedule(function()
			log.debug("autostart: opening terminal")
			print("start")
			terminal.open()
			log.debug("autostart: closing window")
			print("close")
			ui.close_window()
		end)
	end

	return conf
end

function M.open()
	actions.open()
end

function M.close()
	actions.close()
end

function M.toggle()
	actions.toggle()
end

function M.send(text, opts)
	actions.send(text, opts)
end

function M.send_selection()
	actions.send_selection()
end

function M.send_buffer()
	actions.send_buffer()
end

M.actions = actions

return M
