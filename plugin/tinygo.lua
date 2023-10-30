-- Check we havent' loaded the plugin already...
if vim.g.loaded_tinygo == 1 then return end
vim.g.loaded_telescope = 1

-- Load our Lua codebase
local ok, tinygo = pcall(require, "tinygo")
if not ok then
	vim.print("couldn't find the tinygo codebase!")
end
