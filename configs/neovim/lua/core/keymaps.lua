-- All Keymaps

vim.keymap.set({ "n", "v" }, "<Space>", "<Nop>", { silent = true })

--Remap for dealing with word wrap
vim.keymap.set("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

---@type vim.keymap.set.Opts
local opts = { silent = true }

-- open file(s) in vertical split
vim.keymap.set("n", "<leader>vgd", "<cmd>vs | norm gd<cr>", opts)
vim.keymap.set("n", "<leader>vgf", "<cmd>vs | norm gf<cr>", opts)

vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", opts) -- exit terminal mode quickly
vim.keymap.set("n", "<Esc>", "<cmd>nohl<cr>", opts) -- remove highlight with esc

vim.keymap.set("n", "<S-l>", "<cmd>bn<cr>", opts)
vim.keymap.set("n", "<S-h>", "<cmd>bp<cr>", opts)

-- pane navigation with ctrl-hjkl
vim.keymap.set({ "n", "t" }, "<C-k>", "<C-w><C-k>", opts)
vim.keymap.set({ "n", "t" }, "<C-j>", "<C-w><C-j>", opts)
vim.keymap.set({ "n", "t" }, "<C-l>", "<C-w><C-l>", opts)
vim.keymap.set({ "n", "t" }, "<C-h>", "<C-w><C-h>", opts)

-- rename selected text
vim.keymap.set("v", "<C-r>", [["hy:%s/<C-r>h//gc<left><left><left>]], opts)
