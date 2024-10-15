vim.cmd([[set runtimepath=$VIMRUNTIME]])

local colorscheme = "gruvbox"

-- LAZY.NVIM BOOTSTRAP
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

-- DEFAULTS

vim.o.guifont = "Hack Nerd Font Mono"
vim.o.rnu = true
vim.o.nu = true
vim.o.clipboard = "unnamed"
vim.o.completeopt = "menu,menuone,noinsert"
vim.o.signcolumn = "yes"
vim.o.termguicolors = true
vim.o.inccommand = "nosplit"
vim.o.mouse = "a"
vim.o.sb = true
vim.o.spr = true
vim.g.noshowmode = true
vim.o.timeoutlen = 0
vim.o.autoindent = true
vim.o.expandtab = true
vim.o.shiftwidth = 2
vim.o.smartindent = true
vim.o.softtabstop = 2
vim.o.tabstop = 2
vim.o.laststatus = 3
vim.o.so = 999

--Enable break indent
vim.o.breakindent = true

--Save undo history
vim.opt.undofile = true
vim.g.noswapfile = true

--Case insensitive searching UNLESS /C or capital in search
vim.o.ignorecase = true
vim.o.smartcase = true

vim.keymap.set({ "n", "v" }, "<Space>", "<Nop>", { silent = true })
vim.g.mapleader = " "
vim.g.maplocalleader = " "

--Remap for dealing with word wrap
vim.keymap.set("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

vim.api.nvim_create_user_command("Ter", function()
	vim.cmd([[ 10sp | ter ]])
end, {})

-- Make background transparent
vim.api.nvim_create_autocmd("VimEnter", {
	callback = function()
		vim.cmd([[ hi Normal ctermbg=NONE guibg=NONE ]])
	end,
	pattern = "*",
})

-- Highlight on yank
local highlight_group = vim.api.nvim_create_augroup("YankHighlight", { clear = true })
vim.api.nvim_create_autocmd("TextYankPost", {
	callback = function()
		vim.highlight.on_yank()
	end,
	group = highlight_group,
	pattern = "*",
})

local opts = { noremap = true, silent = true }

-- KEYMAPS
vim.keymap.set("n", "vgd", "<cmd>vs | norm gd<cr>", opts)
vim.keymap.set("n", "vgf", "<cmd>vs | norm gf<cr>", opts)
vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", opts)
vim.keymap.set("n", "<Esc>", "<cmd>nohl<cr>", opts)
vim.keymap.set("n", "<C-k>", "<C-w><C-k>", opts)
vim.keymap.set("n", "<S-l>", "<cmd>bn<cr>", opts)
vim.keymap.set("n", "<S-h>", "<cmd>bp<cr>", opts)
vim.keymap.set("n", "<C-j>", "<C-w><C-j>", opts)
vim.keymap.set("n", "<C-l>", "<C-w><C-l>", opts)
vim.keymap.set("n", "<C-h>", "<C-w><C-h>", opts)
vim.keymap.set("t", "<C-k>", "<C-w><C-k>", opts)
vim.keymap.set("t", "<C-j>", "<C-w><C-j>", opts)
vim.keymap.set("t", "<C-l>", "<C-w><C-l>", opts)
vim.keymap.set("t", "<C-h>", "<C-w><C-h>", opts)
vim.keymap.set("v", "<C-r>", [["hy:%s/<C-r>h//gc<left><left><left>]], opts)
-- DISABLE DIAGNOSTIC TEXT FOR LSP_LINES.NVIM
vim.diagnostic.config({
	virtual_text = false,
})

local prettier = { "prettier", "prettierd" }
local js = { prettier }

local function load_plugins()
	require("lazy").setup({

		{
			"VonHeikemen/lsp-zero.nvim",
			lazy = true,
			branch = "v3.x",
			dependencies = {
				-- LSP Support
				{
					"neovim/nvim-lspconfig", -- Required
					dependencies = {
						"SmiteshP/nvim-navbuddy",
						dependencies = {
							"SmiteshP/nvim-navic",
							"MunifTanjim/nui.nvim",
						},
						opts = { lsp = { auto_attach = true } },
					},
				},
				{
					-- Optional
					"williamboman/mason.nvim",
					build = function()
						pcall(vim.cmd, "MasonUpdate")
					end,
					dependencies = {
						"mfussenegger/nvim-dap",
					},
				},
				{ "williamboman/mason-lspconfig.nvim" }, -- Optional

				-- Autocompletion
				{ "L3MON4D3/LuaSnip", build = "make install_jsregexp" },
				{ "hrsh7th/nvim-cmp" }, -- Required
				{ "hrsh7th/cmp-nvim-lsp" }, -- Required
				{ "hrsh7th/cmp-buffer" }, -- Required
				"onsails/lspkind.nvim",
			},
		},

		-- FORMATTING
		{
			"stevearc/conform.nvim",
			event = { "BufWritePre" },
			cmd = { "ConformInfo" },
			keys = {
				{
					"<leader>f",
					function()
						require("conform").format({ async = true, lsp_fallback = true })
					end,
					mode = "",
					desc = "Format buffer",
				},
			},
			-- Everything in opts will be passed to setup()
			config = function()
				require("conform").setup({
					-- Define your formatters
					formatters_by_ft = {
						scss = { prettier },
						javascript = js,
						typescript = js,
						javascriptreact = js,
						typescriptreact = js,
						sql = { "sqlfluff" },
						dart = { "dart_format" },
						vue = { prettier },
						astro = { prettier },
						css = { prettier },
						html = { prettier },
						json = { prettier },
						jsonc = { prettier },
						yaml = { prettier },
						toml = { "taplo" },
						php = { "pint" },
						markdown = { "injected" },
						norg = { "injected" },
						graphql = { prettier },
						lua = { "stylua" },
						go = { "goimports", "gofmt" },
						sh = { "shfmt" },
						rust = { "rustfmt" },
						python = { "ruff_fix", "ruff_format", "isort" },
						zig = { "zigfmt" },
						["_"] = { "trim_whitespace", "trim_newlines" },
					},
					-- Set up format-on-save
					format_on_save = {
						-- These options will be passed to conform.format()
						timeout_ms = 500,
						lsp_fallback = true,
					},

					-- Customize formatters
					formatters = {
						shfmt = {
							prepend_args = { "-i", "2" },
						},
					},
				})
			end,
			init = function()
				-- If you want the formatexpr, here is the place to set it
				vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
			end,
		},

		-- COPILOT / LLM
		{ "David-Kunz/gen.nvim", opts = { model = "codegemma:2b-code" } },

		{
			"Exafunction/codeium.vim",
			event = "BufEnter",
			enabled = false,
		},

		{
			"supermaven-inc/supermaven-nvim",
			event = "BufEnter",
			config = function()
				require("supermaven-nvim").setup({})
			end,
		},

		{
			"huggingface/llm.nvim",
			enabled = false,
			opts = {
				backend = "ollama",
				model = "codegemma:2b-code",
				url = "http://localhost:11434",

				request_body = {
					-- Modelfile options for the model you use
					parameters = {
						num_predict = 128,
						temperature = 0,
						top_p = 0.9,
						stop = { "<|file_separator|>" },
					},
				},
				fim = {
					enabled = true,
					prefix = "<|fim_prefix|>",
					middle = "<|fim_middle|>",
					suffix = "<|fim_suffix|>",
				},

				context_window = 8192,

				tokenizer = { repository = "google/codegemma-2b" },

				lsp = {
					bin_path = vim.api.nvim_call_function("stdpath", { "data" }) .. "/mason/bin/llm-ls",
				},
			},
		},

		{
			"zbirenbaum/copilot.lua",
			enabled = false,
			cmd = "Copilot",
			event = "InsertEnter",
			config = function()
				require("copilot").setup({
					suggestion = { enabled = false },
					panel = { enabled = false },
				})
				vim.api.nvim_set_hl(0, "CmpItemKindCopilot", { fg = "#6CC644" })
			end,
		},

		{
			"zbirenbaum/copilot-cmp",
			enabled = false,
			config = function()
				require("copilot_cmp").setup()
			end,
		},

		-- THEMES
		"ray-x/aurora",
		{
			"ellisonleao/gruvbox.nvim",
			lazy = false, -- make sure we load this during startup if it is your main colorscheme
			priority = 1000, -- make sure to load this before all the other start plugins
			config = function()
				-- load the colorscheme here
				vim.cmd([[colorscheme gruvbox]])
			end,
		},
		"folke/tokyonight.nvim",

		-- Treesitter
		{
			"nvim-treesitter/nvim-treesitter",
			dependencies = {
				"nvim-treesitter/nvim-treesitter-textobjects",
				"nvim-treesitter/nvim-treesitter-refactor",
				"https://gitlab.com/HiPhish/rainbow-delimiters.nvim.git",
				{
					"windwp/nvim-ts-autotag",
					event = "InsertEnter",
				},
				{
					"JoosepAlviste/nvim-ts-context-commentstring",
					event = "BufRead",
				},
			},
			build = ":TSUpdate",
			config = function()
				require("nvim-treesitter.install").compilers = { "clang" }
				require("nvim-treesitter.configs").setup({
					auto_install = true,
					highlight = {
						enable = true, -- false will disable the whole extension
					},
					matchup = {
						enable = true, -- false will disable the whole extension
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
					indent = {
						enable = true,
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
								["]m"] = "@function.outer",
								["]]"] = "@class.outer",
							},
							goto_next_end = {
								["]M"] = "@function.outer",
								["]["] = "@class.outer",
							},
							goto_previous_start = {
								["[m"] = "@function.outer",
								["[["] = "@class.outer",
							},
							goto_previous_end = {
								["[M"] = "@function.outer",
								["[]"] = "@class.outer",
							},
						},
					},
				})
			end,
		},

		-- TELESCOPE
		{
			"nvim-telescope/telescope.nvim",
			branch = "0.1.x",
			dependencies = { "nvim-lua/plenary.nvim" },
		},
		{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },

		-- MINI
		{
			"echasnovski/mini.nvim",
			config = function()
				require("mini.bufremove").setup()
				require("mini.cursorword").setup()
				-- require("mini.indentscope").setup()
				require("mini.jump").setup()
				require("mini.starter").setup()
				require("mini.surround").setup()
				require("mini.trailspace").setup()
			end,
			dependencies = { "kyazdani42/nvim-web-devicons", "lewis6991/gitsigns.nvim" },
		},

		-- LUALINE
		{
			"nvim-lualine/lualine.nvim",
			config = function()
				require("lualine").setup({ options = { theme = "gruvbox" } })
			end,
			dependencies = { "kyazdani42/nvim-web-devicons", lazy = true },
		},

		-- AUTOSAVE
		{
			"pocco81/auto-save.nvim",
			config = function()
				require("auto-save").setup({
					execution_message = { message = "" },
				})
			end,
		},

		-- WHICHKEY
		{
			"folke/which-key.nvim",
			event = "VeryLazy",
			init = function()
				vim.o.timeout = true
				vim.o.timeoutlen = 300
			end,
			config = function()
				require("which-key").add({
					{ "<leader><space>", "<cmd>lua require('telescope.builtin').buffers()<CR>", desc = "Buffers" },
					{ "<leader>b", group = "buffer" },
					{ "<leader>bd", "<cmd>lua MiniBufremove.delete()<cr>", desc = "Delete Buffer" },
					{ "<leader>bq", "<cmd>lua MiniBufremove.unshow_in_window()<cr>", desc = "Unshow Buffer In Window" },
					{ "<leader>bw", "<cmd>lua MiniBufremove.wipeout()<cr>", desc = "Delete Buffer" },
					{ "<leader>gg", "<cmd>FloatermNew --disposable --name=lazygit lazygit<cr>", desc = "Open Lazygit" },
					{ "<leader>l", group = "LSP" },
					{ "<leader>li", "<cmd>Mason<CR>", desc = "Show Mason" },
					{ "<leader>ln", "<cmd>LspInfo<CR>", desc = "Show all active LSPs" },
					{ "<leader>lp", "<cmd>lua require('persistence').load()<cr>", desc = "Load Project" },
					{ "<leader>lr", "<cmd>LspRestart<CR>", desc = "Restart the LSP" },
					{ "<leader>n", "<cmd>NnnPicker %:p:h<cr>", desc = "Open n³" },
					{ "<leader>p", group = "Plugins" },
					{ "<leader>pc", "<cmd>Lazy clean<CR>", desc = "Clean plugins" },
					{ "<leader>pi", "<cmd>Lazy install<CR>", desc = "Install plugins" },
					{ "<leader>pp", "<cmd>Lazy<cr>", desc = "Open Lazy" },
					{ "<leader>ps", "<cmd>Lazy sync<CR>", desc = "Sync plugins" },
					{ "<leader>pu", "<cmd>Lazy update<CR>", desc = "Update plugins" },
					{ "<leader>q", "<cmd>lua MiniBufremove.unshow()<cr>", desc = "Unshow Buffer" },
					{ "<leader>s", group = "file" },
					{
						"<leader>s/",
						"<cmd>lua require('telescope.builtin').current_buffer_fuzzy_find()<CR>",
						desc = "Grep File",
					},
					{ "<leader>s?", "<cmd>lua require('telescope.builtin').oldfiles()<CR>", desc = "Open Recent File" },
					{ "<leader>sb", "<cmd>Telescope file_browser<cr>", desc = "File Browser" },
					{ "<leader>sd", "<cmd>lua require('telescope.builtin').grep_string()<CR>", desc = "Grep String" },
					{ "<leader>se", desc = "Edit File" },
					{
						"<leader>sf",
						"<cmd>lua require('telescope.builtin').find_files({ find_command = { 'rg', '--files', '--iglob', '!.git', '--hidden' }})<cr>",
						desc = "Find File",
					},
					{ "<leader>sh", "<cmd>lua require('telescope.builtin').help_tags()<CR>", desc = "Help Tags" },
					{ "<leader>so", "<cmd>lua require('telescope.builtin').help_tags()<CR>", desc = "Help Tags" },
					{ "<leader>sp", "<cmd>lua require('telescope.builtin').live_grep()<CR>", desc = "Live Grep" },
					{ "<leader>st", "<cmd>lua require('telescope.builtin').tags()<CR>", desc = "Tags" },
					{ "<leader>tb", "<cmd>Telescope builtin<cr>", desc = "Toggle Telescope builtins" },
					{ "<leader>te", "<cmd>Telescope<cr>", desc = "Toggle Telescope" },
					{ "<leader>tp", "<cmd>Telescope projects<cr>", desc = "Toggle Recent Projects" },
					{ "<leader>tt", "<cmd>TroubleToggle<cr>", desc = "Toggle Trouble" },
					{ "<leader>w", "<cmd>w<cr>", desc = "Write File" },
				})
			end,
		},

		-- DETOUR
		{
			"carbon-steel/detour.nvim",
		},

		-- COMMENT
		{
			"numToStr/Comment.nvim",
			config = true,
		},

		{
			"folke/todo-comments.nvim",
			event = "BufRead",
		},

		-- TROUBLE
		{
			"folke/trouble.nvim",
			cmd = "TroubleToggle",
		},

		-- NNN
		{
			"luukvbaal/nnn.nvim",
			config = function()
				local builtin = require("nnn").builtin
				local mappings = {
					{ "<C-t>", builtin.open_in_tab }, -- open file(s) in tab
					{ "<C-s>", builtin.open_in_split }, -- open file(s) in split
					{ "<C-v>", builtin.open_in_vsplit }, -- open file(s) in vertical split
					{ "<C-p>", builtin.open_in_preview }, -- open file in preview split keeping nnn focused
					{ "<C-y>", builtin.copy_to_clipboard }, -- copy file(s) to clipboard
					{ "<C-w>", builtin.cd_to_path }, -- cd to file directory
					{ "<C-e>", builtin.populate_cmdline }, -- populate cmdline (:) with file(s)
				}
				require("nnn").setup({ mappings = mappings })
			end,
		},

		-- BUFFERLINE
		{
			"akinsho/bufferline.nvim",
			version = "*",
			dependencies = "kyazdani42/nvim-web-devicons",
			config = function()
				require("bufferline").setup({
					options = {
						close_command = "lua MiniBufremove.delete(%d)",
						right_mouse_command = "lua MiniBufremove.delete(%d)",
						diagnostics = "nvim_lsp",
						diagnostics_indicator = function(count, level)
							local icon = level:match("error") and " " or " "
							return " " .. icon .. count
						end,
						seperator_style = "slant",
					},
				})
			end,
		},

		-- AUTOPAIRS
		{
			"windwp/nvim-autopairs",
			config = function()
				require("nvim-autopairs").setup({
					disable_filetype = { "TelescopePrompt", "guihua", "guihua_rust", "clap_input" },
				})
				if vim.o.ft == "clap_input" and vim.o.ft == "guihua" and vim.o.ft == "guihua_rust" then
					require("cmp").setup.buffer({ completion = { enable = false } })
				end
			end,
		},

		-- SURROUND
		{ "tpope/vim-surround" },

		-- MATCHUP
		{ "andymass/vim-matchup", event = "VimEnter" },

		-- AUTOREAD
		{ "djoshea/vim-autoread", event = "VimEnter" },
		{ "sindrets/diffview.nvim", event = "BufRead" },

		-- TPOPE
		{ "tpope/vim-repeat" },

		{ "tpope/vim-abolish" },

		{ "tpope/vim-unimpaired" },

		-- DIAL
		{
			"monaqa/dial.nvim",
			event = "BufRead",
			config = function()
				vim.keymap.set("n", "<C-a>", require("dial.map").inc_normal(), { noremap = true })
				vim.keymap.set("n", "<C-x>", require("dial.map").dec_normal(), { noremap = true })
				vim.keymap.set("v", "<C-a>", require("dial.map").inc_visual(), { noremap = true })
				vim.keymap.set("v", "<C-x>", require("dial.map").dec_visual(), { noremap = true })
				vim.keymap.set("v", "g<C-a>", require("dial.map").inc_gvisual(), { noremap = true })
				vim.keymap.set("v", "g<C-x>", require("dial.map").dec_gvisual(), { noremap = true })
			end,
		},

		-- LANGUAGE-SPECIFIC TOOLING

		-- JS / TS
		{
			"vuki656/package-info.nvim",
			dependencies = "MunifTanjim/nui.nvim",
		},

		-- Flutter
		{
			"akinsho/flutter-tools.nvim",
			lazy = false,
			dependencies = { "nvim-lua/plenary.nvim", "stevearc/dressing.nvim" },
		},

		"Neevash/awesome-flutter-snippets",
		"RobertBrunhage/flutter-riverpod-snippets",

		-- BUFRESIZE
		{
			"kwkarlwang/bufresize.nvim",
			config = true,
		},

		-- PERSISTENCE
		{
			"folke/persistence.nvim",
			event = "BufReadPre", -- this will only start session saving when an actual file was opened
			module = "persistence",
			config = true,
		},

		-- ROOTER.NVIM
		{
			"notjedi/nvim-rooter.lua",
			config = true,
		},

		-- REGEXPLAINER
		{
			"bennypowers/nvim-regexplainer",
			name = "regexplainer",
			config = true,
			dependencies = {
				"nvim-treesitter/nvim-treesitter",
				"MunifTanjim/nui.nvim",
			},
		},

		-- TARGETS.VIM
		"wellle/targets.vim",

		-- PROJECT.NVIM
		{
			"ahmedkhalf/project.nvim",
			config = function()
				require("project_nvim").setup()
				require("telescope").load_extension("projects")
			end,
		},

		-- DRESSING.NVIM
		{ "stevearc/dressing.nvim", config = true },

		-- FLOATERM
		"voldikss/vim-floaterm",

		-- SCHEMASTORE
		"b0o/schemastore.nvim",

		-- DIAGNOSTIC LINES
		{
			"https://git.sr.ht/~whynothugo/lsp_lines.nvim",
			config = true,
		},

		-- NOICE (experimental cmdline popupmenu replacement)
		{
			"folke/noice.nvim",
			event = "VeryLazy",
			config = function()
				require("notify").setup({ background_colour = "#000000" })
				require("noice").setup({
					lsp = {
						-- override markdown rendering so that **cmp** and other plugins use **Treesitter**
						override = {
							["vim.lsp.util.convert_input_to_markdown_lines"] = true,
							["vim.lsp.util.stylize_markdown"] = true,
							["cmp.entry.get_documentation"] = true,
						},
					},
					-- you can enable a preset for easier configuration
					presets = {
						bottom_search = false, -- use a classic bottom cmdline for search
						command_palette = true, -- position the cmdline and popupmenu together
						long_message_to_split = true, -- long messages will be sent to a split
						inc_rename = true, -- enables an input dialog for inc-rename.nvim
						lsp_doc_border = true, -- add a border to hover docs and signature help
					},
				})
			end,
			dependencies = {
				"MunifTanjim/nui.nvim",
				"rcarriga/nvim-notify",
				{
					"smjonas/inc-rename.nvim",
					config = function()
						require("inc_rename").setup()
					end,
				},
			},
		},

		-- LIVE-COMMAND
		{
			"smjonas/live-command.nvim",
			-- live-command supports semantic versioning via tags
			-- tag = "1.*",
			config = function()
				require("live-command").setup({
					commands = {
						Norm = { cmd = "norm" },
					},
				})
			end,
		},
	})

	-- LSP SERVER CONFIG

	local lsp = require("lsp-zero").preset("recommended")
	local navbuddy = require("nvim-navbuddy")

	lsp.on_attach(function(client, bufnr)
		local bindn = function(mode, keymap, command, noremap, expr)
			vim.keymap.set(
				mode,
				keymap,
				command,
				{ buffer = bufnr, noremap = not not noremap, silent = true, expr = not not expr }
			)
		end
		lsp.default_keymaps({ buffer = bufnr, preserve_mappings = false, exclude = { "gd", "gr", "gi", "go" } })
		if client.server_capabilities.documentSymbolProvider then
			navbuddy.attach(client, bufnr)
		end

		bindn("n", "<leader>rn", function()
			return ":IncRename " .. vim.fn.expand("<cword>")
		end, false, true)

		bindn("n", "<leader>ca", "<cmd>lua vim.lsp.buf.code_action()<cr>")
		bindn("v", "<leader>ca", "<cmd>lua vim.lsp.buf.range_code_action()<cr>")

		bindn("n", "gd", "<cmd>Telescope lsp_definitions<cr>")
		bindn("n", "gr", "<cmd>Telescope lsp_references<cr>")
		bindn("n", "gi", "<cmd>Telescope lsp_implementations<cr>")
		bindn("n", "go", "<cmd>Telescope lsp_type_definitions<cr>")
	end)

	require("mason").setup({})
	require("mason-lspconfig").setup({
		ensure_installed = {},
		handlers = {
			lsp.default_setup,
			volar = function()
				require("lspconfig").volar.setup({})
			end,
			ts_ls = function()
				local vue_typescript_plugin = require("mason-registry")
					.get_package("vue-language-server")
					:get_install_path() .. "/node_modules/@vue/language-server" .. "/node_modules/@vue/typescript-plugin"

				require("lspconfig").ts_ls.setup({
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
				})
			end,
			pyright = function()
				require("lspconfig").pyright.setup({ settings = { python = { venvPath = ".venv" } } })
			end,
			biome = function()
				require("lspconfig").biome.setup({ single_file_support = false })
			end,
			lua_ls = function()
				local lua_opts = lsp.nvim_lua_ls()
				require("lspconfig").lua_ls.setup(lua_opts)
			end,
		},
	})

	-- CMP SETUP
	local cmp = require("cmp")

	cmp.setup({
		formatting = {
			fields = { "abbr", "kind", "menu" },
			format = require("lspkind").cmp_format({
				mode = "symbol_text", -- show only symbol annotations
				maxwidth = 50, -- prevent the popup from showing more than provided characters
				ellipsis_char = "...", -- when popup menu exceed maxwidth, the truncated part would show ellipsis_char instead
				symbol_map = { Copilot = "󰚩" },
			}),
		},
		sources = { { name = "copilot" }, { name = "nvim_lsp" } },
		preselect = "item",
		window = {
			completion = cmp.config.window.bordered(),
			documentation = cmp.config.window.bordered(),
		},
		completion = {
			completeopt = "menu,menuone,noinsert",
		},
		mapping = cmp.mapping.preset.insert({
			["<CR>"] = cmp.mapping.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = false }),
			["<C-u>"] = cmp.mapping.scroll_docs(-4),
			["<C-d>"] = cmp.mapping.scroll_docs(4),
		}),
	})

	require("flutter-tools").setup({
		lsp = {
			capabilities = lsp.get_capabilities(),
		},
	})

	-- GITSIGNS SETUP
	require("gitsigns").setup()
end

if not vim.loop.fs_stat(lazypath) then
	print("install lazy")
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", -- latest stable release
		lazypath,
	})
	vim.opt.rtp:prepend(lazypath)

	load_plugins()
	require("lazy").sync()
	vim.cmd([[TSInstall all]])
	vim.cmd([[colorscheme ]] .. colorscheme)
else
	vim.opt.rtp:prepend(lazypath)
	load_plugins()
	vim.cmd([[colorscheme ]] .. colorscheme)
end
