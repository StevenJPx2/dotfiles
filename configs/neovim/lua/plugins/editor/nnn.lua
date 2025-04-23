return {
	"luukvbaal/nnn.nvim",
	opts = function()
		local builtin = require("nnn").builtin
		return {
			mappings = {
				{ "<C-t>", builtin.open_in_tab },
				{ "<C-v>", builtin.open_in_vsplit },
				{ "<C-x>", builtin.open_in_split },
				{ "<C-p>", builtin.open_in_preview },
			},
		}
	end,
	keys = {
		{
			"<leader>n",
			"<cmd>NnnPicker %:p:h<cr>",
			desc = "Open n³",
		},
	},
}
