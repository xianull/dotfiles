return {
  "akinsho/toggleterm.nvim",
  version = "*",
  keys = {
    { "<c-\\>", ":ToggleTerm<CR>", mode = "n" },
  },
  config = function()
    require("toggleterm").setup({
      size = 20,
      open_mapping = [[<c-\>]],
      direction = "float",
      shade_terminals = true,
      float_opts = {
        border = "rounded",
      },
    })
  end,
}
