return {
	{
		"saghen/blink.cmp",
		dependencies = {
			"rafamadriz/friendly-snippets",
			"Kaiser-Yang/blink-cmp-avante",
		},

		version = "1.*",

		opts = {
			keymap = { preset = "enter" },

			appearance = {
				nerd_font_variant = "mono",
			},

			completion = {
				menu = { draw = { treesitter = { "lsp" } } },
				documentation = { auto_show = true, auto_show_delay_ms = 100 },
			},

			sources = {
				default = { "lazydev", "lsp", "path", "snippets", "buffer" },
				providers = {
					lazydev = {
						name = "LazyDev",
						module = "lazydev.integrations.blink",
						score_offset = 100,
					},
				},
			},

			signature = { enabled = true },
		},
		opts_extend = { "sources.default" },
	},
}
