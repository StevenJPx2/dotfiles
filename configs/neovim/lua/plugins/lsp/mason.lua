return {
	{
		"mason-org/mason.nvim",
		keys = {
			{ "<leader>m", "<cmd>Mason<cr>", desc = "Mason" },
		},
		opts = {},
	},

	{ "mason-org/mason-lspconfig.nvim", opts = {} },

	{ "zapling/mason-conform.nvim", dependencies = { "stevearc/conform.nvim" } },
}
