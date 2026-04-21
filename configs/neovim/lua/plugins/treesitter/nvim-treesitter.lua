return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	version = false,
	lazy = false,
	build = ":TSUpdate",

	init = function()
		vim.api.nvim_create_autocmd("FileType", {
			desc = "Enable Treesitter features",
			callback = function(args)
				local lang = vim.treesitter.language.get_lang(args.match) or args.match

				if vim.treesitter.query.get(lang, "highlights") then
					vim.treesitter.start()
				end
				if vim.treesitter.query.get(lang, "indents") then
					vim.bo.indentexpr = "v:lua.require('nvim-treesitter').indentexpr()"
				end
				if vim.treesitter.query.get(lang, "folds") then
					vim.wo.foldmethod = "expr"
					vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
				end
			end,
		})
	end,

	opts = {
		auto_install = true,
		matchup = {
			enable = true,
			enable_quotes = true,
		},
		rainbow = {
			enable = true,
		},
		incremental_selection = {
			enable = true,
			keymaps = {
				init_selection = "gnn",
				node_incremental = "grn",
				scope_incremental = "grc",
				node_decremental = "grm",
			},
		},
		textobjects = {
			select = {
				enable = true,
				lookahead = true, -- Automatically jump forward to textobj, similar to targets.vim
				keymaps = {
					-- You can use the capture groups defined in textobjects.scm
					["af"] = "@function.outer",
					["if"] = "@function.inner",
					["ac"] = "@class.outer",
					["ic"] = "@class.inner",
				},
			},
			move = {
				enable = true,
				set_jumps = true, -- whether to set jumps in the jumplist
				goto_next_start = {
					["]f"] = "@function.outer",
					["]c"] = "@class.outer",
					["]a"] = "@parameter.inner",
				},
				goto_next_end = {
					["]F"] = "@function.outer",
					["]C"] = "@class.outer",
					["]A"] = "@parameter.inner",
				},
				goto_previous_start = {
					["[f"] = "@function.outer",
					["[c"] = "@class.outer",
					["[a"] = "@parameter.inner",
				},
				goto_previous_end = {
					["[F"] = "@function.outer",
					["[C"] = "@class.outer",
					["[A"] = "@parameter.inner",
				},
			},
		},
	},
}
