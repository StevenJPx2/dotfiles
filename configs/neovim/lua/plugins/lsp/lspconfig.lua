return {
	{
		"neovim/nvim-lspconfig",

		cmd = { "LspInfo", "LspInstall", "LspStart" },

		event = { "BufReadPre", "BufNewFile" },

		dependencies = {
			{ "williamboman/mason.nvim" },
			{ "williamboman/mason-lspconfig.nvim" },
			{ "zapling/mason-conform.nvim" },
			{ "stevearc/conform.nvim" },
		},

		config = function()
			vim.api.nvim_create_autocmd("LspAttach", {
				desc = "LSP actions",
				callback = function(event)
					local opts = { buffer = event.buf }

					vim.keymap.set("n", "K", "<cmd>lua vim.lsp.buf.hover()<cr>", opts)
					vim.keymap.set("n", "<leader>rn", "<cmd>lua vim.lsp.buf.rename()<cr>", opts)
					vim.keymap.set("n", "<leader>ca", "<cmd>lua vim.lsp.buf.code_action()<cr>", opts)
				end,
			})

			require("mason-lspconfig").setup({
				ensure_installed = {},
				automatic_installation = true,
				handlers = {
					function(server_name)
						vim.lsp.enable(server_name)
					end,
				},
			})
		end,
	},
}
