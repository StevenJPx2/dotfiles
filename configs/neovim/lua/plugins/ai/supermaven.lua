return {
	{
		"supermaven-inc/supermaven-nvim",
		opts = {},
	},
	{
		"saghen/blink.cmp",
		---@type blink.cmp.Config
		opts = {
			keymap = {
				["<Tab>"] = {
					"snippet_forward",
					function() -- if you are using Neovim's native inline completions
						local ok, supermaven = pcall(require, "supermaven-nvim.completion_preview")
						if ok and supermaven.has_suggestion() then
							vim.schedule(supermaven.on_accept_suggestion)
							return true
						end
					end,
					"select_next",
					"fallback",
				},
			},
		},
	},
}
