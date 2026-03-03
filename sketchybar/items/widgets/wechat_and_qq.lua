local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

local M = {}

M.qq = sbar.add("item", "widgets.qq", {
	position = "right",
	icon = {
		font = { family = settings.font.text, size = 16.0 },
	},
	label = { font = { family = settings.font.numbers } },
	update_freq = 5,
	-- drawing = true,
})

M.wechat = sbar.add("item", "widgets.wechat", {
	position = "right",
	icon = {
		font = { family = settings.font.text, size = 19.0 },
	},
	label = { font = { family = settings.font.numbers } },
	update_freq = 5,
})

-- Background around wechat + qq (keep consistent with other widgets)
local wechat_qq_bracket = sbar.add("bracket", "widgets.wechat_qq.bracket", {
	M.qq.name,
	M.wechat.name,
}, {
	background = {
		color = colors.with_alpha(colors.bg1, 0.8),
		border_color = colors.with_alpha(colors.bg2, 0.8),
		border_width = 2,
		corner_radius = 9,
	},
})

-- Spacing after the group (consistent with other widgets)
sbar.add("item", "widgets.wechat_qq.padding", {
	position = "right",
	width = settings.group_paddings,
})

M.wechat:subscribe({ "routine", "power_source_change", "system_woke" }, function()
	sbar.exec("lsappinfo -all list | grep wechat", function(wechat_notify)
		local icon = icons.wechat
		local label = ""

		local notify_num = wechat_notify:match('"StatusLabel"=%{ "label"="?(.-)"? %}')

		if notify_num == nil or notify_num == "" then
			M.wechat:set({
				icon = {
					string = icon,
					color = colors.white,
				},
				label = { drawing = false },
			})
			sbar.exec("sketchybar --trigger wechat_notify_trigger POPUP=false")
		else
			M.wechat:set({
				icon = {
					string = icon,
					color = colors.white,
				},
				label = { string = notify_num .. label, drawing = true },
			})
			sbar.exec("sketchybar --trigger wechat_notify_trigger POPUP=true")
		end
	end)
end)

M.qq:subscribe({ "routine", "power_source_change", "system_woke" }, function()
	sbar.exec("lsappinfo -all list | grep qq", function(qq_notify)
		local icon = icons.qq
		local label = ""

		local notify_num = qq_notify:match('"StatusLabel"=%{ "label"="?(.-)"? %}')

		if notify_num == nil or notify_num == "" then
			M.qq:set({
				icon = {
					string = icon,
					color = colors.white,
				},
				label = { drawing = false },
			})
		else
			M.qq:set({
				icon = {
					string = icon,
					color = colors.white,
					drawing = true,
				},
				label = { string = notify_num .. label, drawing = true },
			})
		end
	end)
end)

-- Click to focus/launch apps using stable bundle IDs
-- This avoids进程名/本地化名称差异导致的激活失败
M.qq:subscribe("mouse.clicked", function(env)
	sbar.exec([[osascript -e 'tell application id "com.tencent.qq" to activate']])
end)

M.wechat:subscribe("mouse.clicked", function(env)
	-- Use simple `open -a` for WeChat; mru-spaces 已关闭，避免了之前的空间重排问题
	sbar.exec("open -a 'WeChat'")
end)

return M
