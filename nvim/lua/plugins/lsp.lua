return {
  "neovim/nvim-lspconfig",
  dependencies = {
    "williamboman/mason.nvim",
    "williamboman/mason-lspconfig.nvim",
  },
  config = function()
    require("mason").setup({
      ui = {
        icons = {
          package_installed = "✓",
          package_pending = "➜",
          package_uninstalled = "✗",
        },
      },
    })
    require("mason-lspconfig").setup({
      ensure_installed = { "lua_ls", "ts_ls", "pyright" },
    })

    local capabilities = require("cmp_nvim_lsp").default_capabilities()

    -- Neovim 0.11+ 新 API
    vim.lsp.config["lua_ls"] = {
      capabilities = capabilities,
    }
    vim.lsp.config["ts_ls"] = {
      capabilities = capabilities,
    }
    vim.lsp.config["pyright"] = {
      capabilities = capabilities,
    }
    vim.lsp.enable("lua_ls")
    vim.lsp.enable("ts_ls")
    vim.lsp.enable("pyright")
  end,
}
