return {
	{
		"dmtrKovalenko/fff.nvim",
		build = "cargo build --release",
		lazy = false,
	},
	{
		"madmaxieee/fff-snacks.nvim",
		dependencies = {
			"dmtrKovalenko/fff.nvim",
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
