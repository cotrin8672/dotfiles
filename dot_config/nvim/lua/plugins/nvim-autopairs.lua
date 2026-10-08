return {
	"windwp/nvim-autopairs",
	event = { "VeryLazy", "InsertEnter" },
	opts = {
		map_bs = false,
	},
	config = function(_, opts)
		local autopairs = require("nvim-autopairs")
		local cond = require("nvim-autopairs.conds")
		local Rule = require("nvim-autopairs.rule")

		autopairs.setup(opts)
		local function matlab_prefix(context, suffix)
			local syntax = require("config.matlab.syntax")
			local row = vim.api.nvim_win_get_cursor(0)[1]
			local state = syntax.context(context.bufnr, row - 1)
			return syntax.line(context.line:sub(1, context.col - 1) .. (suffix or ""), state.in_block_comment)
		end
		local not_before_ignored_char = cond.not_after_regex(autopairs.config.ignored_next_char)
		for _, rule in ipairs(vim.list_extend(autopairs.get_rules("'"), autopairs.get_rules('"'))) do
			rule:with_pair(function(context)
				if vim.bo[context.bufnr].filetype == "matlab" then
					return matlab_prefix(context, rule.start_pair).quote == rule.start_pair
						and not_before_ignored_char(context) ~= false
				end
			end, 1)
			table.insert(rule.move_cond, 1, function(context)
				if vim.bo[context.bufnr].filetype == "matlab" then
					return matlab_prefix(context).quote == rule.start_pair
				end
			end)
		end
		for _, pair in ipairs({ "'", '"', "`", "(", "[", "{" }) do
			for _, rule in ipairs(autopairs.get_rules(pair)) do
				local function in_comment_or_literal(context)
					if vim.bo[context.bufnr].filetype == "matlab" then
						local before = matlab_prefix(context)
						if before.in_comment or (pair:match("[%(%[{]") and before.quote) then
							return false
						end
					end
				end
				rule:with_pair(in_comment_or_literal, 1)
				if rule.move_cond then
					table.insert(rule.move_cond, 1, in_comment_or_literal)
				end
			end
		end
		autopairs.add_rule(Rule("<", ">", {
			"-astro",
			"-eruby",
			"-heex",
			"-html",
			"-htmldjango",
			"-javascriptreact",
			"-matlab",
			"-php",
			"-svelte",
			"-typescriptreact",
			"-vue",
			"-xml",
		}):with_pair(cond.not_before_char("<", 1)):with_pair(cond.not_after_text(">")))
	end,
}
