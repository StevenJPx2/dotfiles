local function set_colorscheme_table(git, colorscheme)
	if _G.colorscheme == colorscheme then
		return {
			git,
			lazy = false,
			priority = 1000,
		}
	end

	return { git }
end

return {
	set_colorscheme_table("ray-x/aurora", "aurora"),
	set_colorscheme_table("ellisonleao/gruvbox.nvim", "gruvbox"),
	set_colorscheme_table("folke/tokyonight.nvim", "tokyonight"),
}
