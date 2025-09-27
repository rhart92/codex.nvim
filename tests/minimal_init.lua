-- Minimal init for running plenary tests
local fn = vim.fn
local opt = vim.opt

local repo_root = fn.fnamemodify(fn.expand('<sfile>:p'), ':h:h')
opt.runtimepath:append(repo_root)

local plenary_candidates = {
  fn.getenv('PLENARY_PATH'),
  repo_root .. '/vendor/plenary.nvim',
  fn.stdpath('data') .. '/lazy/plenary.nvim',
  fn.stdpath('data') .. '/site/pack/packer/start/plenary.nvim',
  fn.stdpath('data') .. '/site/pack/packer/opt/plenary.nvim',
  fn.stdpath('data') .. '/site/pack/lazy/start/plenary.nvim',
}

local plenary_path
for _, candidate in ipairs(plenary_candidates) do
  if candidate == vim.NIL then
    candidate = nil
  end
  if candidate ~= nil and candidate ~= '' then
    if type(candidate) ~= 'string' then
      candidate = tostring(candidate)
    end
    if vim.loop.fs_stat(candidate) then
      plenary_path = candidate
      break
    end
  end
end

if not plenary_path then
  error('plenary.nvim not found. Set PLENARY_PATH or install plenary.nvim')
end

opt.runtimepath:append(plenary_path)

vim.cmd('runtime! plugin/plenary.vim')
