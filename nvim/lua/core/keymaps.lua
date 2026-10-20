vim.g.mapleader = " "

local keymap = vim.keymap

-- ---------- 导航: j=左 k=下 i=上 l=右 ---------- ---
local nav_modes = { "n", "v" }
keymap.set(nav_modes, "j", "<Left>")
keymap.set(nav_modes, "k", "<Down>")
keymap.set(nav_modes, "i", "<Up>")
keymap.set(nav_modes, "l", "<Right>")
-- h 替代原来的 i 进入插入模式
keymap.set("n", "h", "i")

-- ---------- 插入模式 ---------- ---
keymap.set("i", "jk", "<ESC>")

-- ---------- 视觉模式 ---------- ---
-- 单行或多行移动
keymap.set("v", "J", ":m '>+1<CR>gv=gv")
keymap.set("v", "K", ":m '<-2<CR>gv=gv")

-- ---------- 正常模式 ---------- ---
-- 窗口
keymap.set("n", "<leader>sv", "<C-w>v") -- 水平新增窗口
keymap.set("n", "<leader>sh", "<C-w>s") -- 垂直新增窗口
-- 窗口间跳转（只在 nvim 内，不跳到 tmux pane；tmux 用 C-M-jkil）
keymap.set("n", "<C-j>", "<C-w>h")
keymap.set("n", "<C-k>", "<C-w>j")
keymap.set("n", "<C-i>", "<C-w>k")
keymap.set("n", "<C-l>", "<C-w>l")

-- 取消高亮
keymap.set("n", "<leader>nh", ":nohl<CR>")

-- 删除字符（因为 s 被 flash.nvim 占用）
keymap.set("n", "x", "s")

-- 切换buffer
keymap.set("n", "<Tab>", ":bnext<CR>")
keymap.set("n", "<S-Tab>", ":bprevious<CR>")

-- ---------- 插件 ---------- ---
-- nvim-tree
keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>")
