-- global variables
_G.colorscheme = "gruvbox"

-- general options
vim.o.completeopt = "menu,menuone,popup,fuzzy" -- modern completion menu

vim.o.guifont = "Hack Nerd Font Mono"
vim.o.clipboard = "unnamedplus" -- copy only yank and delete to system clipboard
vim.o.mouse = "a" -- enable full mouse support (i'm a noob yes make fun of me)
vim.o.inccommand = "split" -- show search results while typing
vim.o.so = 900 -- number of lines between cursor and window

vim.o.timeoutlen = 0 -- setting this for which-key

-- split to the bottom and right
vim.o.sb = true
vim.o.spr = true

vim.o.foldenable = true -- enable fold
vim.o.foldlevel = 99 -- start editing with all folds opened
vim.o.foldmethod = "expr" -- use tree-sitter for folding method
vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()"

vim.o.termguicolors = true -- enable rgb colors

vim.o.cursorline = true -- enable cursor line
vim.o.laststatus = 3 -- status line always visible

vim.o.signcolumn = "yes" -- always show sign column
vim.o.rnu = true -- relativenumber
vim.o.nu = true -- line number

vim.o.pumheight = 10 -- max height of completion menu
vim.o.winborder = "rounded" -- enable window border

vim.o.list = true -- use special characters to represent things like tabs or trailing spaces
vim.opt.listchars = { -- NOTE: using `vim.opt` instead of `vim.o` to pass rich object
	tab = "▏ ",
	trail = "·",
	extends = "»",
	precedes = "«",
}

vim.opt.diffopt:append("linematch:60") -- second stage diff to align lines

vim.o.confirm = true -- show dialog for unsaved file(s) before quit
vim.o.updatetime = 200 -- save swap file with 200ms debouncing

vim.o.ignorecase = true -- case-insensitive search
vim.o.smartcase = true -- , until search pattern contains upper case characters

vim.o.autoindent = true -- auto-indenting when starting a new line
vim.o.smartindent = true -- auto-indenting when starting a new line
vim.o.breakindent = true -- visually indent wrapped lines
vim.o.expandtab = true
vim.o.shiftround = true -- round indent to multiple of 'shiftwidth'
vim.o.shiftwidth = 0 -- 0 to follow the 'tabstop' value
vim.o.ts = 2 -- tab width
vim.o.sts = -1 -- tab width (uses 'ts' value)

vim.o.undofile = true -- enable persistent undo
vim.o.undolevels = 10000 -- 10x more undo levels

-- define <leader> and <localleader> keys
-- you should use `vim.keycode` to translate keycodes or pass raw keycode values like `" "` instead of just `"<space>"`
vim.g.mapleader = vim.keycode("<space>")
vim.g.maplocalleader = vim.keycode("<cr>")

-- remove netrw banner for cleaner looking
vim.g.netrw_banner = 0

-- AUTOCMDS

-- Highlight on yank
local highlight_group = vim.api.nvim_create_augroup("YankHighlight", { clear = true })

vim.api.nvim_create_autocmd("TextYankPost", {
	callback = function()
		vim.highlight.on_yank()
	end,
	group = highlight_group,
	pattern = "*",
})

vim.diagnostic.config({
	virtual_lines = {
		current_line = true,
	},
})

-- Make background transparent
vim.api.nvim_create_autocmd("VimEnter", {
	callback = function()
		vim.cmd([[ hi Normal ctermbg=NONE guibg=NONE ]])
	end,
	pattern = "*",
})
