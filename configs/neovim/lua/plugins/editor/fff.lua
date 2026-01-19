return {
	{
		"dmtrKovalenko/fff.nvim",
		build = "cargo build --release",
		lazy = false,
	},
	{
		"dmtrKovalenko/fff-snacks.nvim",
		dependencies = {
			"Irdis/fff.nvim",
			"folke/snacks.nvim",
		},
		cmd = "FFFSnacks",
		keys = {
			{
				"<leader><space>",
				"<cmd> FFFSnacks <cr>",
				desc = "FFF",
			},
		},
		config = true,
	},
}
