local function clear(tbl)
  for i = #tbl, 1, -1 do
    table.remove(tbl, i)
  end
end


describe('codex.nvim core behaviour', function()
  local codex
  local actions
  local ui

  local sent
  local termopen_calls
  local focus_calls
  local ui_state
  local current_win

  local orig_keymap_set
  local orig_keymap_del
  local orig_termopen
  local orig_jobstop
  local orig_chan_send
  local orig_ui_open
  local orig_ui_close
  local orig_ui_is_open
  local orig_ui_focus

  before_each(function()
    for name, _ in pairs(package.loaded) do
      if name == 'codex' or name:match('^codex%.') then
        package.loaded[name] = nil
      end
    end

    codex = require('codex')
    actions = codex.actions
    ui = require('codex.ui')

    current_win = vim.api.nvim_get_current_win()

    sent = {}
    termopen_calls = 0
    focus_calls = 0
    ui_state = { open = false }

    orig_keymap_set = vim.keymap.set
    orig_keymap_del = vim.keymap.del
    orig_termopen = vim.fn.termopen
    orig_jobstop = vim.fn.jobstop
    orig_chan_send = vim.api.nvim_chan_send
    orig_ui_open = ui.open_window
    orig_ui_close = ui.close_window
    orig_ui_is_open = ui.is_open
    orig_ui_focus = ui.focus

    vim.keymap.set = function() end
    vim.keymap.del = function() end

    vim.fn.termopen = function(cmd, opts)
      termopen_calls = termopen_calls + 1
      if opts and opts.on_exit then
        -- keep reference if tests need to trigger exit later
        termopen_calls = termopen_calls
      end
      return 928
    end

    vim.fn.jobstop = function()
      return 0
    end

    vim.api.nvim_chan_send = function(chan, data)
      table.insert(sent, { chan = chan, data = data })
    end

    ui.state.winid = nil
    ui.state.bufnr = nil
    ui.open_window = function(_, bufnr)
      ui_state.open = true
      ui.state.winid = current_win
      ui.state.bufnr = bufnr
      return current_win, bufnr
    end
    ui.close_window = function()
      ui_state.open = false
      ui.state.winid = nil
    end
    ui.is_open = function()
      return ui_state.open
    end
    ui.focus = function()
      focus_calls = focus_calls + 1
    end

  end)

  after_each(function()
    actions.close()

    vim.keymap.set = orig_keymap_set
    vim.keymap.del = orig_keymap_del
    vim.fn.termopen = orig_termopen
    vim.fn.jobstop = orig_jobstop
    vim.api.nvim_chan_send = orig_chan_send
    ui.open_window = orig_ui_open
    ui.close_window = orig_ui_close
    ui.is_open = orig_ui_is_open
    ui.focus = orig_ui_focus

    vim.cmd('silent! %bwipeout!')
  end)

  it('sends the most recent visual selection with newline', function()
    codex.setup({
      auto_status_delay_ms = 0,
      codex_cmd = { 'codex' },
    })

    codex.open()
    vim.api.nvim_set_current_win(current_win)

    vim.cmd('enew!')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {
      'first line',
      'second line',
      'third line',
    })

    vim.cmd('normal! gg0vlll<Esc>')
    local marks = { start = vim.fn.getpos("'<"), finish = vim.fn.getpos("'>") }
    assert.are_not.equal(0, marks.start[2])
    assert.are_not.equal(0, marks.finish[2])
    local sel1 = require('codex.terminal')._debug_get_visual_selection()
    if not sel1 then
      print(vim.inspect({
        mode = vim.fn.mode(),
        visualmode = vim.fn.visualmode(),
        marks = marks,
      }))
    end
    assert.truthy(sel1)
    assert.is_true(sel1.text:find('first') ~= nil)
    actions.send_selection()

    assert.equal(1, #sent)
    local payload1 = sent[1].data
    assert.is_true(payload1:find('first line') ~= nil)
    assert.equal('\n', payload1:sub(-1))

    clear(sent)

    vim.cmd('normal! j0vllll<Esc>')
    local sel2 = require('codex.terminal')._debug_get_visual_selection()
    assert.truthy(sel2)
    assert.is_true(sel2.text:find('second') ~= nil)
    actions.send_selection()

    assert.equal(1, #sent)
    local payload2 = sent[1].data
    assert.is_true(payload2:find('second line') ~= nil)
    assert.is_true(payload2:find('first line') == nil)
    assert.equal('\n', payload2:sub(-1))

    clear(sent)

    vim.cmd('normal! ggVj<Esc>')
    local sel3 = require('codex.terminal')._debug_get_visual_selection()
    assert.truthy(sel3)
    assert.is_true(sel3.text:find('second line') ~= nil)
    actions.send_selection()

    assert.equal(1, #sent)
    local payload3 = sent[1].data
    assert.is_true(payload3:find('first line\nsecond line') ~= nil)
  end)

  it('sends full buffer with newline and focuses when configured', function()
    codex.setup({
      auto_status_delay_ms = 0,
      codex_cmd = { 'codex' },
      focus_after_send = true,
    })

    codex.open()
    vim.api.nvim_set_current_win(current_win)
    focus_calls = 0

    vim.cmd('enew!')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {
      'alpha',
      'beta',
    })

    actions.send_buffer()

    assert.equal(1, #sent)
    local payload = sent[1].data
    assert.is_true(payload:find('alpha\nbeta') ~= nil)
    assert.equal('\n', payload:sub(-1))
    assert.equal(1, focus_calls)
  end)

  it('reuses running Codex job when toggling the terminal', function()
    ui_state.open = false
    clear(sent)

    codex.setup({
      auto_status_delay_ms = 0,
      codex_cmd = { 'codex' },
    })

    codex.toggle()
    assert.equal(1, termopen_calls)
    assert.is_true(ui_state.open)

    codex.toggle()
    assert.is_false(ui_state.open)

    codex.toggle()
    assert.is_true(ui_state.open)
    assert.equal(1, termopen_calls)

    actions.send('ping payload', { submit = false })
    assert.is_true(#sent >= 1)
    assert.equal(1, termopen_calls)
  end)
end)
