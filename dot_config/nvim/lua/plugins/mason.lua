return {
  'williamboman/mason.nvim',
  event = 'VeryLazy',
  cmd = { 'Mason', 'MasonInstall', 'MasonUninstall', 'MasonUpdate' },
  build = ':MasonUpdate',
  opts = {},
  config = function(_, opts)
    require('mason').setup(opts)

    local languages = require('shared.languages')
    local registry = require('mason-registry')

    local desired_servers = {}
    for _, parser in ipairs(languages.treesitter_parsers) do
      local server = languages.lsp_from_treesitter[parser]
      if server then
        desired_servers[server] = true
      end
    end
    desired_servers.marksman = true
    desired_servers.gradle_ls = true
    desired_servers.biome = true
    desired_servers.matlab_ls = true

    -- Keep track of optional packages we want available in config,
    -- but do not auto-install by default.
    local manual_packages = {
      'vscode-java-decompiler',
    }
    vim.g.mason_manual_packages = manual_packages

    local function has_lspconfig_name(entry, server)
      if type(entry) == 'string' then
        return entry == server
      end
      if type(entry) == 'table' then
        for _, v in ipairs(entry) do
          if v == server then
            return true
          end
        end
      end
      return false
    end

    local function find_package_name_for_server(server)
      for _, pkg in ipairs(registry.get_all_packages()) do
        local spec = pkg.spec or {}
        local neovim = spec.neovim or {}
        if has_lspconfig_name(neovim.lspconfig, server) then
          return pkg.name
        end
      end
      return nil
    end

    local function install_missing()
      for server, _ in pairs(desired_servers) do
        local package_name = find_package_name_for_server(server)
        if package_name and registry.has_package(package_name) then
          local pkg = registry.get_package(package_name)
          if not pkg:is_installed() then
            pkg:install()
          end
        end
      end
    end

    if registry.refresh then
      registry.refresh(install_missing)
    else
      install_missing()
    end
  end,
}
