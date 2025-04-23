return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	opts = {},
	keys = {
		{
			"<leader>?",
			function()
				require("which-key").show({ global = false })
			end,
			desc = "Buffer Local Keymaps (which-key)",
		},

		-- Lazy
		{
			"<leader>pp",
			function()
				require("lazy").home()
			end,
			desc = "Open Lazy",
		},
		{
			"<leader>ps",
			function()
				require("lazy").sync()
			end,
			desc = "Open Lazy [S]ync",
		},
	},
}
