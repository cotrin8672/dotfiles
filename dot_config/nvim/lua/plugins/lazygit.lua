local float = require("shared.float")

return {
  {
    name = "plenary.nvim",
    "nvim-lua/plenary.nvim",
    lazy = true,
  },
  {
    name = "lazygit.nvim",
    "kdheepak/lazygit.nvim",
    opts = {
      float = {
        width = 0.88,
        height = 0.88,
        winblend = float.blend,
      },
    },
    cmd = {
      "LazyGit",
      "LazyGitConfig",
      "LazyGitCurrentFile",
      "LazyGitFilter",
      "LazyGitFilterCurrentFile",
    },
    dependencies = {
      "plenary.nvim",
    },
  },
  {
    name = "diffview.nvim",
    "sindrets/diffview.nvim",
    cmd = {
      "DiffviewOpen",
      "DiffviewFileHistory",
      "DiffviewClose",
    },
    dependencies = {
      "plenary.nvim",
    },
    keys = {
      {
        "<leader>gd",
        function()
          local view = require("diffview.lib").get_current_view()
          if view then
            vim.cmd("DiffviewClose")
          else
            vim.cmd("DiffviewOpen")
          end
        end,
        desc = "Diffview Toggle",
      },
      {
        "<leader>gh",
        "<cmd>DiffviewFileHistory %<cr>",
        desc = "File History",
      },
    },
  },
  {
    name = "git-conflict.nvim",
    "akinsho/git-conflict.nvim",
    event = "BufReadPre",
    opts = {
      default_mappings = false,
      default_commands = true,
      disable_diagnostics = false,
      list_opener = "copen",
    },
    config = function(_, opts)
      require("git-conflict").setup(opts)

      vim.keymap.set("n", "]m", "<Plug>(git-conflict-next-conflict)", { desc = "Next Conflict" })
      vim.keymap.set("n", "[m", "<Plug>(git-conflict-prev-conflict)", { desc = "Previous Conflict" })
      vim.keymap.set("n", "<leader>go", "<Plug>(git-conflict-ours)", { desc = "Conflict Ours" })
      vim.keymap.set("n", "<leader>gt", "<Plug>(git-conflict-theirs)", { desc = "Conflict Theirs" })
      vim.keymap.set("n", "<leader>gb", "<Plug>(git-conflict-both)", { desc = "Conflict Both" })
      vim.keymap.set("n", "<leader>g0", "<Plug>(git-conflict-none)", { desc = "Conflict None" })
    end,
  },
}
