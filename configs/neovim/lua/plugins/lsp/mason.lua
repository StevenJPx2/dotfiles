return {
	{
		"williamboman/mason.nvim",
		lazy = false,
		opts = {
			ui = {
				border = vim.o.winborder,
			},
		},
		keys = {
			{ "<leader>m", "<cmd>Mason<cr>", desc = "Mason" },
		},
	},

	"williamboman/mason-lspconfig.nvim",

	{ "zapling/mason-conform.nvim", dependencies = { "stevearc/conform.nvim" } },
}
