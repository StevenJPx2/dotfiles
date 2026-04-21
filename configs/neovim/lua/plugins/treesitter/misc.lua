return {
	{
		"nvim-treesitter/nvim-treesitter-textobjects",
		branch = "main",
		init = function()
			vim.g.no_plugin_maps = true
		end,
	},
	{
		"https://gitlab.com/HiPhish/rainbow-delimiters.nvim.git",
		event = "VeryLazy",
	},
}
