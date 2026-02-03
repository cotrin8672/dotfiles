-- init.lua (minimal lazy.nvim bootstrap)
-- 余計なものは入れず、必要な機能だけを手で組む前提の最小構成

-- lazy.nvim のインストール先（標準の data ディレクトリ）
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  -- lazy.nvim をまだ入れていなければ自動で取得
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
-- lazy.nvim をランタイムパスに追加
vim.opt.rtp:prepend(lazypath)

-- 基本設定（最低限）
vim.g.mapleader = " "
vim.opt.number = true
vim.opt.termguicolors = true

-- Mason が npm を呼べるように、mise の shims を PATH に追加
-- PowerShell と Neovim の PATH がズレることがあるため、ここで補正する
local mise_shims = (os.getenv("LOCALAPPDATA") or "") .. "\\mise\\shims"
if not string.find(vim.env.PATH or "", mise_shims, 1, true) then
  vim.env.PATH = (vim.env.PATH or "") .. ";" .. mise_shims
end

-- MATLAB のインストール先（自分の環境に合わせて変更）
local matlab_install = nil
if vim.fn.has("win32") == 1 then
  -- Windows 側の MATLAB パス
  matlab_install = "C:\\Program Files\\MATLAB\\R2022a"
else
  -- WSL / Linux 側の MATLAB パス
  matlab_install = "/usr/local/MATLAB/R2024b"
end

-- プラグイン管理（lazy.nvim）
require("lazy").setup({
  spec = {
    -- 補完（blink.cmp）
    {
      "saghen/blink.cmp",
      version = "1.*", -- 公式のリリースタグを使ってバイナリ自動取得
      -- 他のプラグインから sources を拡張しやすくする
      opts_extend = { "sources.default" },
      opts = {
        -- 最低限のソースだけ使う
        sources = {
          default = { "lsp", "path", "snippets", "buffer" },
        },
        -- fuzzy matcher（Rust優先、なければLuaにフォールバック）
        fuzzy = { implementation = "prefer_rust_with_warning" },
      },
    },
    -- カラースキーム（Wisteria）
    {
      "masisz/wisteria.nvim",
      name = "wisteria",
      lazy = false,
      priority = 1000,
      opts = {
        transparent = true,
        overrides = function(_colors)
          return {}
        end,
      },
      config = function(_, opts)
        require("wisteria").setup(opts)
        vim.cmd.colorscheme("wisteria")
      end,
    },
    -- LSP サーバ管理（Mason）
    { "williamboman/mason.nvim", opts = {} },
    -- ステータスライン（lualine）
    {
      "nvim-lualine/lualine.nvim",
      dependencies = { "nvim-tree/nvim-web-devicons" },
      opts = {
        options = {
          theme = "wisteria",
          section_separators = "",
          component_separators = "",
        },
      },
      config = function(_, opts)
        require("lualine").setup(opts)
      end,
    },
    -- キー入力のヒント表示（key-menu.nvim）
    {
      "emmanueltouzery/key-menu.nvim",
      config = function()
        -- キー待ち時間（ヒント表示のタイミング）
        vim.o.timeoutlen = 300
        -- <Space>（リーダー）でヒントを出す
        require("key-menu").set("n", "<Space>")
      end,
    },
    -- コメントアウト操作（Comment.nvim）
    {
      "numToStr/Comment.nvim",
      opts = {},
    },
    -- LSP の進捗/通知表示（fidget.nvim）
    {
      "j-hui/fidget.nvim",
      opts = {},
    },
    -- ファイルツリー（neo-tree）
    {
      "nvim-neo-tree/neo-tree.nvim",
      branch = "v3.x",
      dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-tree/nvim-web-devicons",
        "MunifTanjim/nui.nvim",
      },
      opts = {
        filesystem = {
          filtered_items = { hide_dotfiles = false },
        },
      },
      config = function(_, opts)
        require("neo-tree").setup(opts)
        -- <leader>e でツリーの表示/非表示
        vim.keymap.set("n", "<leader>e", "<cmd>Neotree toggle<CR>")
      end,
    },
    {
      -- Tree-sitter（シンタックスハイライト強化）
      "nvim-treesitter/nvim-treesitter",
      build = ":TSUpdate",
      opts = {
        -- 必要な言語だけインストール
        ensure_installed = { "matlab", "markdown", "markdown_inline", "lua" },
        highlight = { enable = true },
      },
      config = function(_, opts)
        -- 新しいエントリポイントで設定
        require("nvim-treesitter").setup(opts)
      end,
    },
    {
      -- Mason と lspconfig をつなぐ
      "williamboman/mason-lspconfig.nvim",
      dependencies = { "williamboman/mason.nvim", "neovim/nvim-lspconfig", "saghen/blink.cmp" },
      opts = {
        -- MATLAB LSP を自動インストール対象にする
        ensure_installed = { "matlab_ls" },
        handlers = {
          -- それ以外のサーバはデフォルト設定で起動
          function(server_name)
            local capabilities = vim.lsp.protocol.make_client_capabilities()
            capabilities = require("blink.cmp").get_lsp_capabilities(capabilities)
            require("lspconfig")[server_name].setup({
              capabilities = capabilities,
            })
          end,
          -- MATLAB LSP のみ個別設定
          ["matlab_ls"] = function()
            local capabilities = vim.lsp.protocol.make_client_capabilities()
            capabilities = require("blink.cmp").get_lsp_capabilities(capabilities)
            require("lspconfig").matlab_ls.setup({
              capabilities = capabilities,
              settings = {
                MATLAB = {
                  -- MATLAB 本体のパス（必須）
                  installPath = matlab_install,
                  indexWorkspace = true,
                  matlabConnectionTiming = "onStart",
                  telemetry = false,
                },
              },
              -- 単一ファイルでも動かしたい場合は true
              single_file_support = true,
            })
          end,
        },
      },
    },
    -- LSP クライアント側の設定（サーバ定義）
    { "neovim/nvim-lspconfig" },

    -- === おすすめセット（用途別） ===
    -- 検索 / ナビゲーション
    {
      "nvim-telescope/telescope.nvim",
      dependencies = { "nvim-lua/plenary.nvim" },
      config = function()
        require("telescope").setup({})
        local builtin = require("telescope.builtin")
        vim.keymap.set("n", "<leader>ff", builtin.find_files)
        vim.keymap.set("n", "<leader>fg", builtin.live_grep)
        vim.keymap.set("n", "<leader>fb", builtin.buffers)
        vim.keymap.set("n", "<leader>fh", builtin.help_tags)
      end,
    },
    {
      "stevearc/aerial.nvim",
      opts = {},
      config = function(_, opts)
        require("aerial").setup(opts)
        vim.keymap.set("n", "<leader>o", "<cmd>AerialToggle<CR>")
      end,
    },
    {
      "akinsho/bufferline.nvim",
      version = "*",
      dependencies = { "nvim-tree/nvim-web-devicons" },
      opts = {},
    },
    {
      "kevinhwang91/nvim-bqf",
      opts = {},
    },

    -- 見た目 / 表示
    { "folke/lsp-colors.nvim", opts = {} },
    { "norcalli/nvim-colorizer.lua", opts = {} },
    { "mvllow/modes.nvim", opts = {} },
    {
      "goolord/alpha-nvim",
      config = function()
        local alpha = require("alpha")
        local dashboard = require("alpha.themes.dashboard")
        alpha.setup(dashboard.config)
      end,
    },
    {
      "petertriho/nvim-scrollbar",
      opts = {
        handlers = {
          search = true,
        },
      },
    },
    { "lukas-reineke/indent-blankline.nvim", main = "ibl", opts = {} },

    -- 編集支援
    { "machakann/vim-sandwich" },
    {
      "kevinhwang91/nvim-hlslens",
      opts = {},
      config = function(_, opts)
        require("hlslens").setup(opts)
        local map = vim.keymap.set
        map("n", "n", "<Cmd>execute('normal! ' .. v:count1 .. 'n')<CR><Cmd>lua require('hlslens').start()<CR>")
        map("n", "N", "<Cmd>execute('normal! ' .. v:count1 .. 'N')<CR><Cmd>lua require('hlslens').start()<CR>")
        map("n", "*", "*<Cmd>lua require('hlslens').start()<CR>")
        map("n", "#", "#<Cmd>lua require('hlslens').start()<CR>")
        map("n", "g*", "g*<Cmd>lua require('hlslens').start()<CR>")
        map("n", "g#", "g#<Cmd>lua require('hlslens').start()<CR>")
      end,
    },
    { "akinsho/toggleterm.nvim", version = "*", opts = {} },
    { "segeljakt/vim-silicon" },
    { "windwp/nvim-autopairs", opts = {} },
    { "andymass/vim-matchup" },
    { "ntpeters/vim-better-whitespace" },
    { "t9md/vim-quickhl" },
  },
})
