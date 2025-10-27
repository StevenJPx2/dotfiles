return {
  {
    "Irdis/fff.nvim",
    build = "cargo build --release",
    lazy = false,
  },
  {
    "madmaxieee/fff-snacks.nvim",
    dependencies = {
      "Irdis/fff.nvim",
      "folke/snacks.nvim",
    },
    cmd = "FFFSnacks",
    keys = {
      {
        "<leader><space>",
        "<cmd> FFFSnacks <cr>",
        desc = "FFF",
      },
    },
    config = true,
  },
}
