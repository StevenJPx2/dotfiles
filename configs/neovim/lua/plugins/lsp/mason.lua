return {
	{
		"mason-org/mason.nvim",
		keys = {
			{ "<leader>m", "<cmd>Mason<cr>", desc = "Mason" },
		},
		opts = {},
	},

	{
		"mason-org/mason-lspconfig.nvim",
		lazy = true,
		---@type MasonLspconfigSettings
		opts = {
			ensure_installed = {
				"vtsls",
				"vue_ls",
				"pyright",
			},
		},
	},

	{ "zapling/mason-conform.nvim", dependencies = { "stevearc/conform.nvim" } },
}
