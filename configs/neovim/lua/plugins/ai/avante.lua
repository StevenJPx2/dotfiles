return {
	"yetone/avante.nvim",
	event = "VeryLazy",
	version = false,
	opts = {
		provider = "openrouter",
		vendors = {
			openrouter = {
				__inherited_from = "openai",
				endpoint = "https://openrouter.ai/api/v1",
				api_key_name = "OPENROUTER_API_KEY_AVANTE",
				model = "thudm/glm-z1-32b:free",
				disable_tools = true,
			},
		},
		openai = {
			endpoint = "https://api.openai.com/v1",
			model = "gpt-4o",
			timeout = 30000,
			temperature = 0,
			max_completion_tokens = 8192,
			--reasoning_effort = "medium", -- low|medium|high, only used for reasoning models
		},
	},
	build = "make",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"stevearc/dressing.nvim",
		"nvim-lua/plenary.nvim",
		"MunifTanjim/nui.nvim",
		"folke/snacks.nvim",
		"nvim-tree/nvim-web-devicons",
		{
			"HakonHarnes/img-clip.nvim",
			event = "VeryLazy",
			opts = {
				default = {
					embed_image_as_base64 = false,
					prompt_for_file_name = false,
					drag_and_drop = {
						insert_mode = true,
					},
					use_absolute_path = true,
				},
			},
		},
		{
			"MeanderingProgrammer/render-markdown.nvim",
			opts = {
				file_types = { "markdown", "Avante" },
			},
			ft = { "markdown", "Avante" },
		},
	},
}
