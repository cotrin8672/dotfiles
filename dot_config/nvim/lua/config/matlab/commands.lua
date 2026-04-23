local core = require("config.matlab.core")

vim.api.nvim_create_user_command("MatlabClientInfo", function()
	local client = core.get_client(0)

	if not client then
		vim.notify("matlab_ls client not found", vim.log.levels.ERROR)
		return
	end

	vim.notify(vim.inspect({
		id = client.id,
		name = client.name,
	}))
end, {})
