return {
	{
		"neovim/nvim-lspconfig",

		cmd = { "LspInfo", "LspInstall", "LspStart" },

		event = { "BufReadPre", "BufNewFile" },

		dependencies = {
			{ "mason-org/mason.nvim" },
			{ "mason-org/mason-lspconfig.nvim" },
			{ "zapling/mason-conform.nvim" },
			{ "stevearc/conform.nvim" },
		},

		init = function()
			vim.api.nvim_create_autocmd("LspAttach", {
				desc = "LSP actions",
				callback = function(event)
					local opts = { buffer = event.buf }

					vim.keymap.set("n", "gl", function()
						vim.diagnostic.open_float()
					end, opts)
					vim.keymap.set("n", "<leader>ca", function()
						vim.lsp.buf.code_action()
					end, opts)
				end,
			})
		end,
	},
}
