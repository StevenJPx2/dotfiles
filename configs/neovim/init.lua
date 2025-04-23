-- only uncomment when using this as the main config
-- vim.cmd([[set runtimepath=$VIMRUNTIME]])

-- global variables
_G.colorscheme = "gruvbox"

if vim.fn.has("nvim-0.10") == 0 then
	vim.notify("this config only supports Neovim 0.10+", vim.log.levels.ERROR)
	return
end

require("core.options")
require("core.keymaps")
require("core.packages")

vim.cmd.colorscheme(_G.colorscheme)
