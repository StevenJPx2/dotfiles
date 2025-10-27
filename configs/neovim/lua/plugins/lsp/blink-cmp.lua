return {
  {
    "saghen/blink.cmp",
    version = "*",
    event = "InsertEnter",
    dependencies = {
      "rafamadriz/friendly-snippets",
    },


    init = function()
      -- turn Snacks off while the cmp menu is open, turn it back on afterward
      local group = vim.api.nvim_create_augroup("BlinkCmpSnacksToggle", { clear = true })

      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "BlinkCmpMenuOpen",
        callback = function()
          vim.g.snacks_animate = false
        end,
      })

      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "BlinkCmpMenuClose",
        callback = function()
          vim.g.snacks_animate = true
        end,
      })
    end,

    --- @module "blink.cmp"
    --- @type blink.cmp.Config
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
