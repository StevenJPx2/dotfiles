return {
	"echasnovski/mini.nvim",
	version = "*",
	config = function()
		require("mini.ai").setup()
		require("mini.bracketed").setup()
		require("mini.comment").setup()
		require("mini.jump").setup()
		require("mini.pairs").setup()
		require("mini.splitjoin").setup()
	end,
}
