return {
	"smjonas/inc-rename.nvim",
	event = "VeryLazy",
	cmd = { "IncRename" },
	keys = {
		{
			"<leader>rn",
			-- we cannot use <cmd> here because vim will shout at us
			-- for not ending it with <cr>
			":IncRename ",
			desc = "[R]e[n]ame",
		},
	},
	opts = {},
}
