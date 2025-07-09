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
		---@module "mason-lspconfig"
		---@type MasonLspconfigSettings
		opts = {
			automatic_enable = true,
			ensure_installed = {
				"vtsls",
				"vue_ls",
				"pyright",
			},
		},
	},

	{ "zapling/mason-conform.nvim", dependencies = { "stevearc/conform.nvim" } },
}
