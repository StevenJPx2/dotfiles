return {
	"akinsho/bufferline.nvim",
	version = "*",
	dependencies = "nvim-tree/nvim-web-devicons",

	---@type bufferline.UserConfig
	opts = {
		options = {
			diagnostics = "nvim_lsp",
			diagnostics_indicator = function(count, level, _diagnostics_dict, _context)
				local icon = level:match("error") and " " or " "
				return " " .. icon .. count
			end,
		},
	},
}
