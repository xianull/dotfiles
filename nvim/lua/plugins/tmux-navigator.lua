return {
  "christoomey/vim-tmux-navigator",
  init = function()
    -- 禁止跳转到 tmux pane，只在 nvim 窗口内导航
    vim.g.tmux_navigator_no_wrap = 1
    vim.g.tmux_navigator_disable_when_zoomed = 1
    -- 自定义方向键映射：j=左 k=下 i=上 l=右
    vim.g.tmux_navigator_no_mappings = 1
  end,
  keys = {
    { "<C-j>", "<cmd>TmuxNavigateLeft<CR>",  mode = "n", silent = true },
    { "<C-k>", "<cmd>TmuxNavigateDown<CR>",  mode = "n", silent = true },
    { "<C-i>", "<cmd>TmuxNavigateUp<CR>",    mode = "n", silent = true },
    { "<C-l>", "<cmd>TmuxNavigateRight<CR>", mode = "n", silent = true },
  },
}
