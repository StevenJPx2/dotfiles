return {
	"yetone/avante.nvim",
	event = "VeryLazy",
	version = false,
	---@module "avante"
	---@class avante.Config
	opts = {
		provider = "gemini",
		selector = {
			provider = "snacks",
		},
		providers = {
			openrouter = {
				__inherited_from = "openai",
				endpoint = "https://openrouter.ai/api/v1",
				api_key_name = "OPENROUTER_API_KEY_AVANTE",
				model = "thudm/glm-z1-32b:free",
				disable_tools = true,
			},
			openai = {
				endpoint = "https://api.openai.com/v1",
				model = "gpt-4o",
				extra_request_body = {
					timeout = 30000,
					temperature = 0,
					max_completion_tokens = 8192,
				},
				--reasoning_effort = "medium", -- low|medium|high, only used for reasoning models
			},
		},
	},
	build = "make",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"nvim-lua/plenary.nvim",
		"MunifTanjim/nui.nvim",
		"folke/snacks.nvim",
		"nvim-tree/nvim-web-devicons",
		{
			"MeanderingProgrammer/render-markdown.nvim",
			opts = {
				file_types = { "markdown", "Avante" },
			},
			ft = { "markdown", "Avante" },
		},
	},
}
