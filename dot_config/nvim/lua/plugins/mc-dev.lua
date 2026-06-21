local function latest_mcdev_jdtls_jar(root)
	local base = root .. "/mcdev-jdtls-extension/build/libs"
	local jars = vim.fn.glob(base .. "/io.github.mcdev.jdtls-*.jar", false, true)

	table.sort(jars, function(a, b)
		local function version(path)
			local major, minor, patch = path:match("io%.github%.mcdev%.jdtls%-(%d+)%.(%d+)%.(%d+)%.jar$")
			return tonumber(major) or -1, tonumber(minor) or -1, tonumber(patch) or -1, vim.fn.getftime(path)
		end

		local a_major, a_minor, a_patch, a_time = version(a)
		local b_major, b_minor, b_patch, b_time = version(b)
		if a_major ~= b_major then
			return a_major > b_major
		end
		if a_minor ~= b_minor then
			return a_minor > b_minor
		end
		if a_patch ~= b_patch then
			return a_patch > b_patch
		end
		return a_time > b_time
	end)

	return jars[1]
end

return {
	"cotrin8672/mc-dev-lsp",
	name = "mcdev-nvim",
	event = "VeryLazy",
	version = "*",
	build = "gradle :mcdev-jdtls-extension:jar --no-daemon",
	init = function(plugin)
		vim.opt.rtp:prepend(plugin.dir .. "/mcdev-nvim")
	end,
	opts = function(plugin)
		return {
			jdtls = {
				extension_jar = latest_mcdev_jdtls_jar(plugin.dir),
			},
			insert = {
				at_target = "smart",
				mixin_class_import = true,
				inject_method_descriptor = "auto",
			},
		}
	end,
	config = function(plugin, opts)
		vim.opt.rtp:prepend(plugin.dir .. "/mcdev-nvim")
		require("mcdev").setup(opts)
	end,
}
