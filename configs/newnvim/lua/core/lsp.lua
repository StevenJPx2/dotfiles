-- :h lsp-config

-- show diagnostics as separate lines only for the current line
vim.diagnostic.config({
	virtual_text = { current_line = true },
})

-- enable lsp completion
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("UserLspAttach", { clear = true }),
	callback = function(ev)
		local client = vim.lsp.get_client_by_id(ev.data.client_id)

		if client == nil then
			return
		end

		-- enable autocomplete
		if client:supports_method("textDocument/completion") then
			vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
		end
	end,
})

-- enable configured language servers
-- you can find server configurations from lsp/*.lua files
vim.lsp.enable("gopls")
vim.lsp.enable("lua_ls")
vim.lsp.enable("ts_ls")
