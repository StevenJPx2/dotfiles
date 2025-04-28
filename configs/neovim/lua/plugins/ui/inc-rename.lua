return {
	"smjonas/inc-rename.nvim",
	event = "VeryLazy",
	cmd = { "IncRename" },
	keys = {
		{
			"<leader>rn",
			function()
				return ":IncRename " .. vim.fn.expand("<cword>")
			end,
			expr = true,
			desc = "[R]e[n]ame",
		},
	},
	opts = {},
}
