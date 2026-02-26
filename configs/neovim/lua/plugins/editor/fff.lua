return {
	{
		"dmtrKovalenko/fff.nvim",
		build = function()
			require("fff.download").download_or_build_binary()
		end,
		lazy = false,
	},
	{
		"madmaxieee/fff-snacks.nvim",
		dependencies = {
			"dmtrKovalenko/fff.nvim",
			"folke/snacks.nvim",
		},
		lazy = false,
		keys = {
			{
				"<leader><space>",
				function()
					require("fff-snacks").find_files()
				end,
				desc = "Find Files",
			},
			{
				"<leader>sg",
				function()
					require("fff-snacks").live_grep({ grep_mode = { "fuzzy", "plain", "regex" } })
				end,
				desc = "Grep [G]lobal",
			},
		},
	},
}
