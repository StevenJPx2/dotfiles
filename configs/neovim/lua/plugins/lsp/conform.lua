return {
	"stevearc/conform.nvim",
	event = { "BufWritePre" },
	cmd = { "ConformInfo" },
	keys = {
		{
			"<leader>f",
			function()
				-- formats using visual selection also
				require("conform").format({ async = true }, function(err)
					if not err then
						local mode = vim.api.nvim_get_mode().mode
						if vim.startswith(string.lower(mode), "v") then
							vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
						end
					end
				end)
			end,
			mode = "",
			desc = "Format buffer",
		},
	},
	opts = function()
		local formatters_by_ft = {
			["_"] = { "trim_whitespace", "trim_newlines" },
		}

		local eslint_fts = { "javascript", "javascriptreact", "typescript", "typescriptreact", "vue", "astro" }

		-- eslint filetypes
		for _, ft in ipairs(eslint_fts) do
			formatters_by_ft[ft] = { "eslint", "prettier", lsp_format = "first" }
		end

		-- prettier filetypes
		for _, ft in ipairs({ "css", "scss", "yaml", "html", "json" }) do
			formatters_by_ft[ft] = { "prettier" }
		end

		---@module "conform"
		---@type conform.setupOpts
		return {
			-- Define your formatters
			formatters_by_ft = vim.tbl_deep_extend("force", formatters_by_ft, {
				lua = { "stylua" },
				sql = { "sqlruff" },
				dart = { "dart_format" },
				go = { "goimports", "gofmt" },
				toml = function(bufnr)
					local fters = { "taplo" }

					local filename = vim.api.nvim_buf_get_name(bufnr)

					if filename:match("pyproject.toml") then
						table.insert(fters, "pyproject-fmt")
					end

					return fters
				end,
				sh = { "shfmt" },
				python = { "ruff" },
				rust = { "rustfmt" },
				markdown = { "prettier", "injected", quiet = true },
			}),
			default_format_opts = {
				lsp_format = "fallback",
			},
			format_on_save = { timeout_ms = 200 },

			format_after_save = function(bufnr)
				-- Weird feedback loop when after save
				if vim.tbl_contains(eslint_fts, vim.bo[bufnr].filetype) then
					return
				end

				return { timeout_ms = 500 }
			end,

			formatters = {
				shfmt = {
					prepend_args = { "-i", "2" },
				},
			},
		}
	end,
	init = function()
		vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
	end,
}
