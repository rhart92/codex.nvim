if vim.g.loaded_codex_plugin then
  return
end
vim.g.loaded_codex_plugin = true

local ok, codex = pcall(require, "codex")
if not ok then
  vim.notify("codex.nvim: failed to load core module", vim.log.levels.ERROR)
  return
end

if vim.g.codex_config then
  codex.setup(vim.g.codex_config)
else
  codex.setup()
end
