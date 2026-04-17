return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  config = function()
    local ok, configs = pcall(require, "nvim-treesitter.configs")
    if ok then
      configs.setup({
        ensure_installed = {
          "vim", "help", "bash", "c", "cpp", "javascript", "json",
          "lua", "python", "typescript", "tsx", "css", "rust",
          "markdown", "markdown_inline", "go", "java", "sql",
          "yaml", "toml", "dockerfile", "html", "xml",
        },
        highlight = { enable = true },
        indent = { enable = true },
      })
    end
  end,
}
