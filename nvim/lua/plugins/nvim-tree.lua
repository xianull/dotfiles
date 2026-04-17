return {
  "nvim-tree/nvim-tree.lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  init = function()
    vim.g.loaded_netrw = 1
    vim.g.loaded_netrwPlugin = 1
  end,
  config = function()
    local image_exts = { png = true, jpg = true, jpeg = true, gif = true, bmp = true, webp = true, svg = true }

    vim.api.nvim_set_hl(0, "NvimTreeNormal",           { bg = "NONE" })
    vim.api.nvim_set_hl(0, "NvimTreeNormalNC",         { bg = "NONE" })
    vim.api.nvim_set_hl(0, "NvimTreeWinSeparator",     { fg = "#504945", bg = "NONE" })
    vim.api.nvim_set_hl(0, "NvimTreeCursorLine",       { bg = "#3c3836" })
    vim.api.nvim_set_hl(0, "NvimTreeFolderName",       { fg = "#83a598" })
    vim.api.nvim_set_hl(0, "NvimTreeOpenedFolderName", { fg = "#8ec07c" })
    vim.api.nvim_set_hl(0, "NvimTreeEmptyFolderName",  { fg = "#665c54" })
    vim.api.nvim_set_hl(0, "NvimTreeFolderIcon",       { fg = "#fabd2f" })
    vim.api.nvim_set_hl(0, "NvimTreeRootFolder",       { fg = "#fe8019", bold = true })
    vim.api.nvim_set_hl(0, "NvimTreeGitDirty",         { fg = "#fb4934" })
    vim.api.nvim_set_hl(0, "NvimTreeGitNew",           { fg = "#b8bb26" })
    vim.api.nvim_set_hl(0, "NvimTreeGitIgnored",       { fg = "#665c54" })
    vim.api.nvim_set_hl(0, "NvimTreeDotfile",          { fg = "#665c54" })

    -- 覆盖 nvim-web-devicons 的星星图标
    local devicons_ok, devicons = pcall(require, "nvim-web-devicons")
    if devicons_ok then
      devicons.set_icon({
        ["*.md"] = { icon = "", color = "#ebdbb2", name = "Markdown" },
        [".gitignore"] = { icon = "", color = "#665c54", name = "GitIgnore" },
        [".gitconfig"] = { icon = "", color = "#665c54", name = "GitConfig" },
      })
    end

    require("nvim-tree").setup({
      view = {
        width = 32,
        float = { enable = false },
      },
      renderer = {
        root_folder_label = ":~:s?$?/..?",
        highlight_git = true,
        highlight_opened_files = "name",
        indent_markers = {
          enable = true,
          icons = { corner = "└", edge = "│", item = "│", none = " " },
        },
        icons = {
          show = {
            file = true,
            folder = true,
            folder_arrow = true,
            git = false,
          },
          glyphs = {
            default = "",
            symlink = "",
            folder = {
              arrow_closed = "",
              arrow_open = "",
              default = "",
              open = "",
              empty = "",
              empty_open = "",
              symlink = "",
              symlink_open = "",
            },
          },
        },
      },
      actions = {
        open_file = {
          quit_on_open = false,
          window_picker = { enable = true },
        },
      },
      filters = {
        custom = { ".DS_Store" },
        dotfiles = false,
      },
      on_attach = function(bufnr)
        local api = require("nvim-tree.api")
        api.config.mappings.default_on_attach(bufnr)

        vim.keymap.set("n", "<CR>", function()
          local node = api.tree.get_node_under_cursor()
          if node and node.type == "file" then
            local ext = node.name:match("%.(%w+)$")
            if ext and image_exts[ext:lower()] then
              vim.cmd(string.format('vsplit | terminal viu "%s"', node.absolute_path))
              return
            end
          end
          api.node.open.edit()
        end, { buffer = bufnr, noremap = true, silent = true })
      end,
    })
  end,
}
