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

		config = function()
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

			require("mason-lspconfig").setup({
				ensure_installed = {},
				automatic_installation = true,
				automatic_enable = true,
				handlers = {
					function(server_name)
						vim.lsp.enable(server_name)
					end,

					ts_ls = function()
						local vue_typescript_plugin = require("mason-registry")
							.get_package("vue-language-server")
							:get_install_path() .. "/node_modules/@vue/language-server" .. "/node_modules/@vue/typescript-plugin"

						vim.lsp.config.ts_ls = {
							init_options = {
								plugins = {
									{
										name = "@vue/typescript-plugin",
										location = vue_typescript_plugin,
										languages = { "javascript", "typescript", "vue" },
									},
								},
							},
							filetypes = {
								"javascript",
								"javascriptreact",
								"javascript.jsx",
								"typescript",
								"typescriptreact",
								"typescript.tsx",
								"vue",
							},
						}
						vim.lsp.enable("ts_ls")
					end,
				},
			})
		end,
	},
}
