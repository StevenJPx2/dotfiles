return {
	"madmaxieee/fff.nvim",
	build = "cargo build --release",
	lazy = false,
	keys = {
		{
			"<leader><space>",
			function()
				Snacks.picker.fff()
			end,
			desc = "FFFind files",
		},
	},
}
