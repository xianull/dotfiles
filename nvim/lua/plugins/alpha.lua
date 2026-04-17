return {
  "goolord/alpha-nvim",
  event = "VimEnter",
  dependencies = { "nvim-telescope/telescope.nvim" },
  config = function()
    local alpha = require("alpha")
    local dashboard = require("alpha.themes.dashboard")

    dashboard.section.header.val = {
      "                                                     ",
      "  ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗ ",
      "  ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║ ",
      "  ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║ ",
      "  ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║ ",
      "  ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║ ",
      "  ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝ ",
      "                                                     ",
    }

    dashboard.section.buttons.val = {
      dashboard.button("f", "  Find file", ":Telescope find_files <CR>"),
      dashboard.button("r", "  Recent files", ":Telescope oldfiles <CR>"),
      dashboard.button("g", "  Find text", ":Telescope live_grep <CR>"),
      dashboard.button("e", "  File tree", ":NvimTreeToggle <CR>"),
      dashboard.button("q", "  Quit", ":qa<CR>"),
    }

    -- Gruvbox 主题配置
    local opts = dashboard.opts
    opts.layout[1].val = 8
    for _, button in ipairs(dashboard.section.buttons.val) do
      button.opts.hl = "GruvboxYellow"
      button.opts.hl_shortcut = "GruvboxRed"
    end
    dashboard.section.header.opts.hl = "GruvboxAqua"
    dashboard.section.buttons.opts.hl = "GruvboxYellow"

    alpha.setup(opts)
  end,
}
