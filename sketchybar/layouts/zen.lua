-- Zen：一条占满的 gruvbox 实色通栏，组内是比底栏亮一档的扁平胶囊（无边框）。
-- 和 islands 的区别：islands 是透明底栏上一组组半透明玻璃胶囊 + 系统仪表盘；
-- zen 底栏实色、不受壁纸颜色影响，监控类信息不常驻（社区里 compact / zen 预设的做法）。
-- 实现上只是覆盖：栏参数、胶囊颜色、少加载几个组件。组件代码和 islands 共用。
local colors = require("colors")

-- 整体提亮两档（之前 #1d2021 / #282828 太深）：底栏用 bg2（gruvbox soft #32302f），
-- 胶囊比底栏再亮一档用 bg3（#45403d）。胶囊颜色在各组件里写死成 colors.bg1，
-- 所以在组件加载前把 bg1 指到 bg3；方案在任何组件 require 之前加载，这里改得到。
local bar_bg = colors.bg2
colors.bg1 = colors.bg3

return {
  settings = {
    -- 胶囊不要边框，颜色见文件开头
    capsule = { height = 26, corner_radius = 8, bg_alpha = 1, border_alpha = 0 },
    -- 去噪：空桌面不显示 `—`、番茄钟空闲时不常驻 25:00
    spaces = {
      hide_empty = true,
      -- 当前桌面：gruvbox 暖黄淡底（原来的半透明蓝叠在棕灰胶囊上发闷）
      active_color = colors.yellow,
      active_alpha = 0.3,
    },
    pomodoro = { hide_idle_time = true },
  },
  bar = {
    height = 34,
    -- 实色：之前 55% 透明时蓝色壁纸会透上来，整条栏发蓝，看不出 gruvbox
    color = colors.with_alpha(bar_bg, 0.95),
    padding_left = 8,
    padding_right = 8,
  },
  -- 常用的留下：电池、音量、微信 / QQ、专注（番茄 + 待办）。
  -- CPU / GPU / 内存曲线、网速、AI 用量切回 islands 看（sbar-layout islands）
  widgets = {
    "items.widgets.battery",
    "items.widgets.volume",
    "items.widgets.wechat_and_qq",
    "items.widgets.pomodoro",
    "items.widgets.obsidian_todos",
    "items.widgets.focus_bracket",
  },
}
