-- nvim --headless -u NONE -i NONE -n -l tests/nvim_matlab_completion.lua
local config = vim.fn.fnamemodify("dot_config/nvim", ":p"):gsub("[/\\]$", "")
vim.opt.rtp:prepend(config)
for _, plugin in ipairs({ "LuaSnip", "blink.cmp", "blink.lib" }) do
	vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/" .. plugin)
end

vim.bo.filetype = "matlab"
require("luasnip").setup(require("plugins.luasnip").opts)
require("luasnip.loaders.from_lua").load({ paths = { config .. "/lua/snippets" } })
local source = require("blink.cmp.sources.snippets.luasnip").new({})
local ctx = { bufnr = vim.api.nvim_get_current_buf(), line = "if", pos = { row = 0, col = 3 } }
local snippets
source:get_completions(ctx, function(response)
	snippets = response.items
end)
local provider = require("plugins.blink").opts.sources.providers.snippets
local offset = provider.score_offset
assert(
	provider.min_keyword_length(ctx) == 1,
	"MATLAB must not preselect an unrelated snippet after closing a delimiter"
)
assert(provider.should_show_items(ctx), "A statement-start keyword must keep its block snippet")
ctx.line, ctx.pos.col = "value = if", 10
assert(not provider.should_show_items(ctx), "Statement snippets do not belong inside expressions")
vim.api.nvim_buf_set_lines(ctx.bufnr, 0, -1, false, { "f( ...", "    b" })
ctx.line, ctx.pos.row, ctx.pos.col = "    b", 1, 5
assert(not provider.should_show_items(ctx), "A b argument must not preselect the bld function snippet")
vim.api.nvim_buf_set_lines(ctx.bufnr, 0, -1, false, { "" })
ctx.line, ctx.pos.row, ctx.pos.col = "if", 0, 3
for _, item in ipairs(snippets) do
	item.score_offset = offset(ctx)
	item.source_id = "snippets"
end

local lsp = {}
for index, label in ipairs({ "if", "ifanbeam", "ifft", "ifft2", "ifftn", "ifftshift" }) do
	lsp[index] = {
		label = label,
		kind = label == "if" and 14 or 3,
		sortText = ("%010d"):format(index),
		source_id = "lsp",
	}
end
require("blink.cmp.config").set({
	snippets = { preset = "luasnip" },
	fuzzy = { implementation = "lua", frecency = { enabled = false }, use_proximity = false },
})
local ranked = require("blink.cmp.fuzzy").fuzzy("if", 2, { snippets = snippets, lsp = lsp }, "full")
assert(ranked[1].label == "if" and ranked[1].source_id == "snippets", "MATLAB if block must outrank the keyword")
assert(ranked[1].insertText == "if condition\n    \nend", "retain the existing MATLAB snippet")
vim.bo.filetype = "lua"
assert(offset(ctx) == -1, "other filetypes must keep the default snippet score")
assert(provider.min_keyword_length(ctx) == 0, "other filetypes must keep the default snippet trigger")
print("MATLAB completion: if snippet ranking OK")
vim.cmd("qa!")
