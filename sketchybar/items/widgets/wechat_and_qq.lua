local icons = require("icons")
local colors = require("colors")
local settings = require("settings")
local coerce = require("helpers.coerce")

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

-- Background around wechat + qq（系统岛）
local cap = settings.capsule or {}
local wechat_qq_bracket = sbar.add("bracket", "widgets.wechat_qq.bracket", {
	M.qq.name,
	M.wechat.name,
}, {
	background = {
		color = colors.with_alpha(colors.bg1, cap.bg_alpha or 0.32),
		border_width = 1,
		border_color = colors.with_alpha(colors.white, cap.border_alpha or 0.08),
		corner_radius = cap.corner_radius or 12,
		height = cap.height or 30,
	},
})

-- Spacing after the group (consistent with other widgets)
sbar.add("item", "widgets.wechat_qq.padding", {
	position = "right",
	width = settings.group_paddings,
})

local function status_label(out)
	local num = coerce.text(out):match('"StatusLabel"=%{ "label"="?(.-)"? %}')
	if num == "" then
		return nil
	end
	return num
end

M.wechat:subscribe({ "routine", "power_source_change", "system_woke" }, function()
	sbar.exec("lsappinfo info -only StatusLabel com.tencent.xinWeChat", function(out)
		local icon = icons.wechat
		local notify_num = status_label(out)

		if notify_num == nil then
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
				label = { string = notify_num, drawing = true },
			})
			sbar.exec("sketchybar --trigger wechat_notify_trigger POPUP=true")
		end
	end)
end)

M.qq:subscribe({ "routine", "power_source_change", "system_woke" }, function()
	sbar.exec("lsappinfo info -only StatusLabel com.tencent.qq", function(out)
		local icon = icons.qq
		local notify_num = status_label(out)

		if notify_num == nil then
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
				label = { string = notify_num, drawing = true },
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
