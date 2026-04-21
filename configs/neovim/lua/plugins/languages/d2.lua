return {
	{
		"ravsii/tree-sitter-d2",
		dependencies = { "nvim-treesitter/nvim-treesitter" },
		version = "*", -- use the latest git tag instead of main
		build = "make nvim-install",
	},
	{
		"terrastruct/d2-vim",
		ft = { "d2" },
	},
}
