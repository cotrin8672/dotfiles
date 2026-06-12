return {
	"luukvbaal/statuscol.nvim",
	event = "VeryLazy",
	opts = function()
		local builtin = require("statuscol.builtin")

		vim.opt.foldcolumn = "auto:1"

		return {
			setopt = true,
			relculright = true,
			ft_ignore = { "help", "lazy", "mason", "oil", "qf" },
			bt_ignore = { "nofile", "prompt", "quickfix", "terminal" },
			segments = {
				{
					sign = { namespace = { "diagnostic/signs" }, maxwidth = 2, auto = true },
					click = "v:lua.ScSa",
				},
				{
					sign = {
						namespace = { "gitsigns" },
						name = { "Dap.*", ".*" },
						maxwidth = 1,
						colwidth = 1,
						auto = true,
						wrap = true,
					},
					click = "v:lua.ScSa",
				},
				{
					text = { builtin.lnumfunc, " " },
					condition = { true, builtin.not_empty },
					click = "v:lua.ScLa",
				},
				{
					text = { builtin.foldfunc },
					click = "v:lua.ScFa",
				},
			},
		}
	end,
}
