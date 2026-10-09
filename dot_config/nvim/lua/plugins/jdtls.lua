return {
	"mfussenegger/nvim-jdtls",
	ft = { "java", "kotlin" },
	dependencies = {
		{
			"cotrin8672/mc-dev-lsp",
			name = "mcdev-nvim",
			version = false,
			branch = "main",
		},
		"neovim/nvim-lspconfig",
		"cotrin8672/kross.nvim",
	},
	config = function()
		local ok, jdtls = pcall(require, "jdtls")
		if not ok then
			return
		end
		local kross = require("kross")
		local root_markers = {
			"gradlew",
			".git",
			"mvnw",
			"pom.xml",
			"build.gradle",
			"build.gradle.kts",
			"settings.gradle",
			"settings.gradle.kts",
		}

		local capabilities = vim.lsp.protocol.make_client_capabilities()

		pcall(function()
			capabilities = require("blink.cmp").get_lsp_capabilities(capabilities)
		end)

		local function execute_client_command(err, params, ctx)
			if params.command ~= "java.action.organizeImports.chooseImports" then
				local result, response_error = vim.lsp.handlers["workspace/executeClientCommand"](err, params, ctx)
				-- nvim-jdtls returns command errors as results; RPC errors belong in the second return value.
				if type(result) == "table" and result.code and result.message then
					return nil, result
				end
				return result, response_error
			end

			local choices = {}
			for _, selection in ipairs(params.arguments[2]) do
				local candidates = selection.candidates
				local choice = candidates[1]
				if #candidates > 1 then
					local selected = vim.lsp.handlers["window/showMessageRequest"](nil, {
						type = vim.lsp.protocol.MessageType.Info,
						message = "Choose import",
						actions = vim.tbl_map(function(candidate)
							return { title = candidate.fullyQualifiedName, candidate = candidate }
						end, candidates),
					}, ctx)
					if selected == vim.NIL then
						return vim.NIL
					end
					choice = selected.candidate
				end
				choices[#choices + 1] = choice
			end
			return choices
		end

		local function mcdev_navigation(bufnr, method)
			require("mcdev.navigation")[method](bufnr, nil, function(locations, err, raw_locations)
				if err then
					vim.notify(tostring(err), vim.log.levels.WARN)
				elseif not locations or #locations == 0 then
					local unresolved = raw_locations and raw_locations[1]
					vim.notify(
						unresolved and unresolved.resolutionMessage or "mcdev: no " .. method .. " found",
						vim.log.levels.INFO
					)
				elseif method == "definition" and #locations == 1 then
					vim.lsp.util.show_document(locations[1], "utf-16", { focus = true })
				else
					vim.fn.setqflist({}, " ", {
						title = "mcdev " .. method,
						items = vim.lsp.util.locations_to_items(locations, "utf-16"),
					})
					vim.cmd.copen()
				end
			end)
		end

		local function start_or_attach(bufnr)
			local filetype = vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype
			if filetype ~= "java" and filetype ~= "kotlin" then
				return
			end

			local source = vim.api.nvim_buf_get_name(bufnr)
			if
				source == ""
				or vim.bo[bufnr].buftype ~= ""
				or not vim.startswith(vim.uri_from_bufnr(bufnr), "file://")
			then
				return
			end
			local root_dir = require("jdtls.setup").find_root(root_markers, source)
			if not root_dir or root_dir == "" then
				return
			end
			root_dir = vim.uv.fs_realpath(root_dir) or root_dir

			local project_name = vim.fn.fnamemodify(root_dir, ":p:h:t")
			local root_hash = vim.fn.sha256(vim.fs.normalize(root_dir)):sub(1, 12)
			local workspace_dir = vim.fs.joinpath(vim.fn.stdpath("cache"), "jdtls", project_name .. "-" .. root_hash)
			local config = {
				name = "jdtls",
				cmd = {
					"jdtls",
					"-data",
					workspace_dir,
				},
				root_dir = root_dir,
				capabilities = capabilities,
				-- ponytail: full Java text repairs missed changes; revisit after incremental tracking is fixed.
				flags = { allow_incremental_sync = false },
				handlers = { ["workspace/executeClientCommand"] = execute_client_command },
				on_init = function(client)
					-- JDTLS returned stale token positions after edits; Java uses Tree-sitter.
					client.server_capabilities.semanticTokensProvider = nil
					local request = client.request
					function client:request(method, params, handler, ...)
						if method == "textDocument/completion" and handler then
							local callback = handler
							handler = function(err, result, ...)
								-- ponytail: refetch Java on each keystroke until JDTLS marks whitespace results incomplete.
								if type(result) == "table" then
									result.isIncomplete = true
								end
								return callback(err, result, ...)
							end
						elseif method == "textDocument/codeAction" and params.context then
							-- MC sends Vim diagnostics; JDTLS requires LSP ranges and diagnostic data.
							params = vim.deepcopy(params)
							params.context.diagnostics = vim.tbl_map(function(diagnostic)
								return diagnostic.range and diagnostic or vim.lsp.diagnostic.from({ diagnostic })[1]
							end, params.context.diagnostics or {})
						end
						return request(self, method, params, handler, ...)
					end
					if filetype == "kotlin" then
						kross.attach(client)
					end
				end,
				on_attach = function(_, attached_bufnr)
					vim.schedule(function()
						if vim.api.nvim_buf_is_valid(attached_bufnr) then
							require("mcdev.attach").setup(attached_bufnr)
							for key, method in pairs({ ["<leader>md"] = "definition", ["<leader>mr"] = "references" }) do
								vim.keymap.set("n", key, function()
									mcdev_navigation(attached_bufnr, method)
								end, { buffer = attached_bufnr, desc = "MC " .. method })
							end
							vim.keymap.set("n", "<leader>mh", function()
								require("mcdev.hover").show(attached_bufnr)
							end, { buffer = attached_bufnr, desc = "MC hover" })
						end
					end)
				end,
				settings = {
					java = {
						signatureHelp = { enabled = true },
						format = {
							enabled = false,
						},
					},
				},
				init_options = {
					bundles = kross.bundles(),
					extendedClientCapabilities = jdtls.extendedClientCapabilities,
				},
			}

			if require("mcdev.jdtls").extend_config(config) then
				if filetype == "kotlin" then
					-- Start the workspace without JDTLS's Java document hooks or implicit save.
					vim.lsp.start(config, { bufnr = bufnr, attach = false })
				else
					jdtls.start_or_attach(config, nil, { bufnr = bufnr })
				end
			end
		end

		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("JdtlsAttach", { clear = true }),
			pattern = { "java", "kotlin" },
			callback = function(event)
				start_or_attach(event.buf)
			end,
		})

		start_or_attach(vim.api.nvim_get_current_buf())
	end,
}
