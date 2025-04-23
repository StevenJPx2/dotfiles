return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	---@type snacks.Config
	opts = {
		bigfile = { enabled = true },
		bufdelete = { enabled = true },
		dashboard = { enabled = true },
		git = { enabled = true },
		gitbrowse = { enabled = true },
		image = { enabled = true },
		indent = { enabled = true },
		lazygit = { enabled = true },
		picker = { enabled = true },
		quickfile = { enabled = true },
		scroll = { enabled = true },
		statuscolumn = { enabled = true },
		words = { enabled = true },
	},

	keys = {
		--- BUFFER DELETE
		{
			"<leader>bd",
			function()
				Snacks.bufdelete.delete()
			end,
			desc = "Delete Buffer",
		},

		--- GIT
		{
			"<leader>gl",
			function()
				Snacks.git.blame_line()
			end,
			desc = "[G]it Blame [L]ine",
		},
		{
			"<leader>gR",
			function()
				Snacks.git_browse.open()
			end,
			desc = "Open file in [G]it [R]epository",
		},

		--- IMAGE
		{
			"iK",
			function()
				if Snacks.image.supports_terminal() then
					Snacks.image.hover()
				end
			end,
			desc = "Open [I]mage",
		},

		--- LAZYGIT
		{
			"<leader>gg",
			function()
				Snacks.lazygit.open()
			end,
			desc = "Toggle Lazygit",
		},

		--- PICKER

		--- Global
		{
			"<leader><space>",
			function()
				Snacks.picker.smart()
			end,
			desc = "Smart Find Files",
		},
		{
			"<leader>,",
			function()
				Snacks.picker.buffers()
			end,
			desc = "Buffers",
		},

		--- Grep / Search
		{
			"<leader>sg",
			function()
				Snacks.picker.git_grep({
					untracked = true,
					submodules = true,
				})
			end,
			desc = "Git Grep",
		},
		{
			"<leader>sgf",
			function()
				Snacks.picker.grep()
			end,
			desc = "Full Grep",
		},

		{
			"<leader>s/",
			function()
				Snacks.picker.lines()
			end,
			desc = "Buffer Lines",
		},

		-- diagnostics
		{
			"<leader>sd",
			function()
				Snacks.picker.diagnostics()
			end,
			desc = "Diagnostics",
		},
		{
			"<leader>sD",
			function()
				Snacks.picker.diagnostics_buffer()
			end,
			desc = "Buffer Diagnostics",
		},

		-- files
		{
			"<leader>sf",
			function()
				Snacks.picker.git_files({ untracked = true })
			end,
			desc = "Find Git Files",
		},
		{
			"<leader>sp",
			function()
				Snacks.picker.projects()
			end,
			desc = "Projects",
		},
		{
			"<leader>sr",
			function()
				Snacks.picker.recent()
			end,
			desc = "Recent",
		},

		--- LSP
		{
			"gd",
			function()
				Snacks.picker.lsp_definitions()
			end,
			desc = "Goto Definition",
		},
		{
			"gD",
			function()
				Snacks.picker.lsp_declarations()
			end,
			desc = "Goto Declaration",
		},
		{
			"gr",
			function()
				Snacks.picker.lsp_references()
			end,
			nowait = true,
			desc = "References",
		},
		{
			"gI",
			function()
				Snacks.picker.lsp_implementations()
			end,
			desc = "Goto Implementation",
		},
		{
			"gy",
			function()
				Snacks.picker.lsp_type_definitions()
			end,
			desc = "Goto T[y]pe Definition",
		},
		{
			"<leader>ss",
			function()
				Snacks.picker.lsp_symbols()
			end,
			desc = "LSP Symbols",
		},
		{
			"<leader>sS",
			function()
				Snacks.picker.lsp_workspace_symbols()
			end,
			desc = "LSP Workspace Symbols",
		},
	},
}
