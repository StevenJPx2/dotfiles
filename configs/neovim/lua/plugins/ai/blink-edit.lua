return {
	"BlinkResearchLabs/blink-edit.nvim",
	enabled = false,
	config = function()
		require("blink-edit").setup({
			llm = {
				provider = "sweep",
				backend = "openai",
				url = "http://localhost:8000",
				model = "sweep",
			},
		})
	end,
}
