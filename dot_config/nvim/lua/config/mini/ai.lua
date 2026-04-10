return function()
	local gen_ai_spec = require("mini.extra").gen_ai_spec
	local spec_ts = require("mini.ai").gen_spec.treesitter

	require("mini.ai").setup({
		mappings = {
			around_next = "",
			inside_next = "",
			around_last = "",
			inside_last = "",
		},
		custom_textobjects = {
			A = spec_ts({ a = "@attribute.outer", i = "@attribute.inner" }),
			B = gen_ai_spec.buffer(),
			D = gen_ai_spec.diagnostic(),
			["="] = spec_ts({ a = "@assignment.outer", i = "@assignment.rhs" }),
			c = spec_ts({ a = "@call.outer", i = "@call.inner" }),
			f = spec_ts({ a = "@function.outer", i = "@function.inner" }),
			i = gen_ai_spec.indent(),
			L = gen_ai_spec.line(),
			o = spec_ts({
				a = { "@conditional.outer", "@loop.outer" },
				i = { "@conditional.inner", "@loop.inner" },
			}),
			p = spec_ts({ a = "@parameter.outer", i = "@parameter.inner" }),
			n = gen_ai_spec.number(),
			r = spec_ts({ a = "@return.outer", i = "@return.inner" }),
		},
	})
end
