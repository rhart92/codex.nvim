local api = vim.api
local fn = vim.fn

local ui = require("codex.ui")
local config = require("codex.config")
local session = require("codex.session")
local log = require("codex.log")

local M = {}

local state = {
	job_id = nil,
	bufnr = nil,
	running = false,
}

local function enter_terminal_mode(bufnr)
	if not bufnr or not api.nvim_buf_is_valid(bufnr) then
		return
	end
	if not ui.is_open() then
		return
	end

	local winid = ui.state.winid
	if not winid or not api.nvim_win_is_valid(winid) then
		return
	end

	if api.nvim_win_get_buf(winid) ~= bufnr then
		return
	end

	local current_win = api.nvim_get_current_win()
	if current_win ~= winid then
		api.nvim_set_current_win(winid)
	end

	vim.cmd("startinsert")
end

local function strip_ansi(line)
	return line:gsub("\27%[[0-9;]*[A-Za-z]", "")
end

local function is_job_running()
	return state.running and state.job_id ~= nil
end

local function reset_state()
	state.job_id = nil
	state.running = false
	if state.bufnr and api.nvim_buf_is_valid(state.bufnr) then
		if not vim.bo[state.bufnr].modified then
			pcall(api.nvim_buf_delete, state.bufnr, { force = true })
		else
			api.nvim_buf_set_option(state.bufnr, "bufhidden", "hide")
		end
	end
	state.bufnr = nil
	session.reset()
end

local function handle_output(_, data, _)
	if not data then
		return
	end
	for _, line in ipairs(data) do
		if line and #line > 0 then
			session.on_status_line(strip_ansi(line))
		end
	end
end

local function handle_exit()
	log.warn("Codex job exited", { job_id = state.job_id })
	reset_state()
end

local function ensure_terminal_buffer()
	if state.bufnr and api.nvim_buf_is_valid(state.bufnr) then
		return state.bufnr
	end
	local bufnr = api.nvim_create_buf(false, true)
	api.nvim_buf_set_option(bufnr, "bufhidden", "hide")
	api.nvim_buf_set_option(bufnr, "filetype", "codex")
	state.bufnr = bufnr
	return bufnr
end

local function start_job(conf, opts)
	ops = opts or {}
	local open_window = opts.open_window
	if open_window == nil then
		open_window = true
	end

	local bufnr = ensure_terminal_buffer()
	local winid

	if open_window then
		winid = ui.open_window(conf, bufnr)
		api.nvim_set_current_win(winid)
	end

	api.nvim_buf_call(bufnr, function()
		state.job_id = fn.termopen(conf.codex_cmd, {
			on_stdout = handle_output,
			on_stderr = handle_output,
			on_exit = handle_exit,
		})
	end)

	if not state.job_id or state.job_id <= 0 then
		vim.notify("codex.nvim: failed to start Codex command", vim.log.levels.ERROR)
		log.error("termopen failed", conf.codex_cmd)
		reset_state()
		return false
	end

	log.info("Codex job started", { job_id = state.job_id, cmd = conf.codex_cmd })
	state.running = true

	vim.bo[bufnr].buflisted = false
	vim.b[bufnr].codex_terminal = true

	if open_window then
		enter_terminal_mode(bufnr)
	end

	local chan = state.job_id
	if conf.auto_status_delay_ms and conf.auto_status_delay_ms > 0 then
		vim.api.nvim_chan_send(chan, "/status")
		vim.defer_fn(function()
			if is_job_running() then
				vim.api.nvim_chan_send(chan, "\r")
			end
		end, conf.auto_status_delay_ms)
	end

	return true
end

local function ensure_job(conf, opts)
	opts = opts or {}
	local open_window = opts.open_window
	if open_window == nil then
		open_window = true
	end

	conf = conf or config.get()
	if is_job_running() then
		if open_window and not ui.is_open() and state.bufnr then
			ui.open_window(conf, state.bufnr)
			enter_terminal_mode(state.bufnr)
		end
		return true
	end
	return start_job(conf, opts)
end

function M.open()
	ensure_job(config.get(), { open_window = true })
end

function M.close()
	if is_job_running() then
		log.info("Stopping Codex job", { job_id = state.job_id })
		fn.jobstop(state.job_id)
	end
	ui.close_window()
	reset_state()
end

function M.toggle()
	if ui.is_open() then
		ui.close_window()
	else
		ensure_job(config.get(), { open_window = true })
	end
end

local function ensure_open_for_send(conf)
	if not ensure_job(conf) then
		return false
	end
	return true
end

function M.send(text, opts)
	opts = opts or {}
	if not text or text == "" then
		return
	end
	local conf = config.get()
	if not ensure_open_for_send(conf) then
		return
	end

	local submit = opts.submit
	if submit == nil then
		submit = true
	end

	local chan = state.job_id
	log.debug("sending payload", { text = text, submit = submit, last_byte = string.byte(text, -1) })
	vim.api.nvim_chan_send(chan, text)

	if submit then
		local delay = opts.submit_delay_ms or conf.auto_status_delay_ms or 150
		vim.defer_fn(function()
			if is_job_running() then
				vim.api.nvim_chan_send(chan, "\r")
			end
		end, delay)
	end

	if conf.focus_after_send and opts.focus ~= false then
		ui.focus()
	end
end

local function normalize_column(bufnr, line, col, is_end)
	if col < 0 then
		return col
	end
	local line_text = api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1] or ""
	if col == 2147483647 then
		return #line_text
	end
	local zero_based = math.max(col - 1, 0)
	if is_end then
		zero_based = math.min(zero_based + 1, #line_text)
	else
		zero_based = math.min(zero_based, #line_text)
	end
	return zero_based
end

local function get_visual_selection()
	local bufnr = api.nvim_get_current_buf()
	local mode = vim.fn.mode()
	local needs_restore = false

	if not mode:match("^[vV\22]") then
		local ok = pcall(vim.cmd, [[normal! gv]])
		log.debug("visual reselection", { ok = ok, mode = mode })
		if not ok then
			return nil
		end
		mode = vim.fn.mode()
		needs_restore = true
	end

	local selection_type = vim.fn.visualmode() or mode or "v"
	local start_pos = vim.fn.getpos("v")
	local end_pos = vim.fn.getpos(".")
	print('selection_type', selection_type, 'start', vim.inspect(start_pos), 'end', vim.inspect(end_pos))
	log.debug("visual positions", { selection_type = selection_type, start_pos = start_pos, end_pos = end_pos })

	if start_pos[2] == 0 or end_pos[2] == 0 then
		if needs_restore or mode:match("^[vV\22]") then
			pcall(vim.cmd, [[normal! \<Esc>]])
		end
		log.debug("visual marks unavailable", { start = start_pos, finish = end_pos })
		return nil
	end

	if needs_restore or mode:match("^[vV\22]") then
		pcall(vim.cmd, [[normal! \<Esc>]])
	end

	local start_line, start_col = start_pos[2], start_pos[3]
	local end_line, end_col = end_pos[2], end_pos[3]

	if start_line > end_line or (start_line == end_line and start_col > end_col) then
		start_line, end_line = end_line, start_line
		start_col, end_col = end_col, start_col
	end

	local text
	if selection_type == "V" then
		local lines = api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
		text = table.concat(lines, "\n")
	elseif selection_type == "\22" then
		local left = math.min(start_col, end_col) - 1
		local right = math.max(start_col, end_col) - 1
		local pieces = {}
		for row = start_line - 1, end_line - 1 do
			local line = api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
			pieces[#pieces + 1] = line:sub(left + 1, math.min(right + 1, #line))
		end
		text = table.concat(pieces, "\n")
	else
		local start_c = normalize_column(bufnr, start_line, start_col, false)
		local end_c = normalize_column(bufnr, end_line, end_col, true)
		local lines = api.nvim_buf_get_text(bufnr, start_line - 1, start_c, end_line - 1, end_c, {})
		text = table.concat(lines, "\n")
	end

	if text == "" then
		log.debug("visual selection empty", { start_line = start_line, end_line = end_line, type = selection_type })
		return nil
	end

	local expand = vim.bo.expandtab
	local tabstop = vim.bo.tabstop
	local spaces
	if expand and tabstop and tabstop > 0 then
		spaces = string.rep(" ", tabstop)
		text = text:gsub("\t", spaces)
	else
		log.debug("tabs preserved (expandtab disabled)")
	end

	local selection = {
		bufnr = bufnr,
		start_line = start_line,
		end_line = end_line,
		text = text,
	}

	log.debug("visual selection captured", selection)

	return selection
end

local function get_buffer_contents(bufnr)
	local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
	return table.concat(lines, "\n")
end

local function format_metadata(bufnr, start_line, end_line)
	local filename = api.nvim_buf_get_name(bufnr)
	if filename == "" then
		filename = "[No Name]"
	else
		filename = vim.fn.fnamemodify(filename, ":t")
	end
	return string.format("File: %s:%d-%d\n\n", filename, start_line, end_line)
end

local function ensure_trailing_newline(text)
	if text:sub(-1) ~= "\n" then
		return text .. " \n\n"
	end
	return text
end

function M.send_selection()
	local selection = get_visual_selection()
	if not selection or not selection.text or selection.text == "" then
		vim.notify("codex.nvim: visual selection is empty", vim.log.levels.WARN)
		return
	end
	local payload = format_metadata(selection.bufnr, selection.start_line, selection.end_line) .. selection.text
	payload = ensure_trailing_newline(payload)
	M.send(payload, { submit = false })
end

function M.send_buffer()
	local bufnr = api.nvim_get_current_buf()
	local filename = api.nvim_buf_get_name(bufnr)
	if filename == "" then
		vim.notify("codex.nvim: buffer has no name", vim.log.levels.WARN)
		return
	end
	local display = vim.fn.fnamemodify(filename, ":.")
	local message = string.format("File: %s\nThis buffer was shared; please read it from disk.\n\n", display)
	M.send(message, { submit = false })
end

function M.ensure_background()
	return ensure_job(config.get(), { open_window = false })
end

M._debug_get_visual_selection = get_visual_selection

return M
