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
			automatic_enable = { exclude = { "vue_ls" } }, -- until fix for https://github.com/mason-org/mason-lspconfig.nvim/issues/587
			ensure_installed = {
				"vtsls",
				"vue_ls",
				"pyright",
			},
		},
	},

	{ "zapling/mason-conform.nvim", dependencies = { "stevearc/conform.nvim" } },
}
