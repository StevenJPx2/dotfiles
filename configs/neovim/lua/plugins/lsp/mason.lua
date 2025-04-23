return {
	{
		"williamboman/mason.nvim",
		lazy = false,
		opts = {},
		keys = {
			{ "<leader>m", "<cmd>Mason<cr>", desc = "Mason" },
		},
	},

	"williamboman/mason-lspconfig.nvim",

	{ "zapling/mason-conform.nvim", dependencies = { "stevearc/conform.nvim" } },
}
