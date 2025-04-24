--- @param git string
--- @param colorscheme string
--- @param opts? table<string, any>
--- @return table
local function set_colorscheme_table(git, colorscheme, opts)
	if _G.colorscheme == colorscheme then
		return {
			git,
			lazy = false,
			priority = 1000,
			opts = opts,
		}
	end

	return { git, opts = opts }
end

return {
	set_colorscheme_table("ray-x/aurora", "aurora"),
	set_colorscheme_table("ellisonleao/gruvbox.nvim", "gruvbox"),
	set_colorscheme_table("sainnhe/gruvbox-material", "gruvbox-material"),
	set_colorscheme_table("folke/tokyonight.nvim", "tokyonight"),
}
