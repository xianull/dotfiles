local colors = require("colors")
local icons = require("icons")
local settings = require("settings")
local coerce = require("helpers.coerce")

local COVER_W = 26
-- get_artwork.sh 输出 96px；0.28 ≈ 27px，贴进 26 宽的封面槽
local ART_SCALE = 0.28
local MAX_TEXT_W = 260
local MAX_LYRIC_W = 200
local LYRIC_SIZE = 10.0

local function measure_text(s, size)
	if not s or s == "" then
		return 0
	end
	local w = 0
	local i = 1
	local n = #s
	while i <= n do
		local c = s:byte(i)
		if not c then
			break
		end
		local wide
		if c < 0x80 then
			wide = false
			i = i + 1
		elseif c < 0xE0 then
			wide = false
			i = i + 2
		elseif c < 0xF0 then
			wide = c >= 0xE3
			i = i + 3
		else
			wide = true
			i = i + 4
		end
		-- Maple Mono CN Bold：西文 0.6em，CJK 1.2em（TTF advance 600/1200）
		w = w + (wide and (size * 1.2) or (size * 0.6))
	end
	return math.ceil(w) + 2
end

local function column_width(title, artist)
	local w = math.max(measure_text(title, 11), measure_text(artist, 9))
	if w < 12 then
		w = 12
	end
	if w > MAX_TEXT_W then
		w = MAX_TEXT_W
	end
	return w
end

-- Felix 顺序：position=right 先加的在最右 → [双行字 | 封面]
-- 封面必须走 icon.background.image：item 的 background.image 会在
-- 含 padding 的整块背景里居中，往左盖住标题/艺人。
local media_cover = sbar.add("item", "media.cover", {
	position = "right",
	drawing = false,
	width = COVER_W,
	padding_left = 0,
	padding_right = 5,
	background = {
		drawing = false,
		color = colors.transparent,
		border_width = 0,
		image = { drawing = false },
	},
	icon = {
		string = "􀑪",
		font = { family = settings.font.text, size = 12 },
		color = colors.white,
		drawing = true,
		width = COVER_W,
		align = "center",
		padding_left = 0,
		padding_right = 0,
		background = {
			drawing = true,
			color = colors.transparent,
			height = COVER_W,
			corner_radius = 6,
			image = {
				string = "",
				scale = ART_SCALE,
				corner_radius = 6,
				drawing = false,
			},
		},
	},
	label = { drawing = false, padding_left = 0, padding_right = 0 },
	updates = true,
	popup = {
		align = "center",
		horizontal = true,
		height = 28,
	},
})

-- 封面和字之间的固定空隙。不能写在 title.padding_right 上：
-- 艺人 width=0 会跟着封面左缘走，右 padding 会把艺人整列往右推进封面。
-- 封面和字之间的空隙。width=8 时双行原点对齐；cover 会吃掉约 5px，可视约 3px。
local media_gap = sbar.add("item", "media.gap", {
	position = "right",
	drawing = false,
	width = 8,
	padding_left = 0,
	padding_right = 0,
	icon = { drawing = false, width = 0, padding_left = 0, padding_right = 0 },
	label = { drawing = false, width = 0, padding_left = 0, padding_right = 0 },
	background = { drawing = false },
})

-- position=right：封面已钉在最右。艺人 width=0 贴在封面左缘，
-- 标签往左画；标题随后加，和艺人落在同一列，变长只往左伸。
local media_artist = sbar.add("item", "media.artist", {
	position = "right",
	drawing = false,
	width = 0,
	padding_left = 0,
	padding_right = 0,
	icon = { drawing = false, width = 0, padding_left = 0, padding_right = 0 },
	label = {
		string = "",
		font = { family = settings.font.text, style = "Bold", size = 9.0 },
		color = colors.with_alpha(colors.white, 0.5),
		width = 12,
		align = "left",
		padding_left = 0,
		padding_right = 0,
		y_offset = 6,
	},
	scroll_texts = true,
})

local media_title = sbar.add("item", "media.title", {
	position = "right",
	drawing = false,
	padding_left = 0,
	padding_right = 0,
	icon = { drawing = false, width = 0, padding_left = 0, padding_right = 0 },
	label = {
		string = "",
		font = { family = settings.font.text, style = "Bold", size = 11.0 },
		color = colors.white,
		width = 12,
		align = "left",
		padding_left = 0,
		padding_right = 0,
		y_offset = -5,
	},
	scroll_texts = true,
})

-- 歌词在标题左侧再加，封面和双行都不会被挤走。
local media_lyric_gap = sbar.add("item", "media.lyric_gap", {
	position = "right",
	drawing = false,
	width = 10,
	padding_left = 0,
	padding_right = 0,
	icon = { drawing = false, width = 0, padding_left = 0, padding_right = 0 },
	label = { drawing = false, width = 0, padding_left = 0, padding_right = 0 },
	background = { drawing = false },
})

local media_lyric = sbar.add("item", "media.lyric", {
	position = "right",
	drawing = false,
	padding_left = 0,
	padding_right = 0,
	icon = { drawing = false, width = 0, padding_left = 0, padding_right = 0 },
	label = {
		string = "",
		font = { family = settings.font.text, style = "Bold", size = LYRIC_SIZE },
		color = colors.with_alpha(colors.white, 0.78),
		width = 12,
		align = "left",
		padding_left = 0,
		padding_right = 0,
		y_offset = 0,
	},
	scroll_texts = true,
})

sbar.add("item", "media.padding", {
	position = "right",
	width = settings.group_paddings,
})

local function popup_btn(name, icon)
	return sbar.add("item", name, {
		position = "popup.media.cover",
		icon = {
			string = icon,
			font = { family = settings.font.text, size = 14 },
			color = colors.white,
			padding_left = 10,
			padding_right = 10,
		},
		label = { drawing = false },
	})
end

local popup_prev = popup_btn("media.popup.prev", icons.media.back)
local popup_toggle = popup_btn("media.popup.toggle", icons.media.play_pause)
local popup_next = popup_btn("media.popup.next", icons.media.forward)

local last_key = ""
local last_track = ""
local visible = false
local art_inflight = false
local art_queued = nil
local art_tries = 0
local cur_app = ""
local cur_title = ""
local cur_title_shown = ""
local cur_artist = ""
local cur_playing = false
local lyric_line = ""
local lyric_on = false
local text_w_track = 12
local lyric_inflight = false
local lyric_rows = {}
local lyric_state = "idle" -- idle | loading | ready | miss
local lyric_gen = 0

local function show_icon_fallback()
	media_cover:set({
		background = { image = { drawing = false } },
		icon = {
			string = "􀑪",
			drawing = true,
			background = { image = { drawing = false } },
		},
	})
end

local function show_artwork(path)
	media_cover:set({
		background = { image = { drawing = false } },
		icon = {
			string = " ",
			drawing = true,
			background = {
				image = {
					string = path,
					drawing = true,
					scale = ART_SCALE,
					corner_radius = 6,
				},
			},
		},
	})
end

local function refresh_artwork(app, title)
	app = app or "Media"
	title = title or ""
	if art_inflight then
		art_queued = { app, title }
		return
	end
	art_inflight = true
	local req = app .. "|" .. title
	sbar.exec("$CONFIG_DIR/helpers/get_artwork.sh " .. string.format("%q", app), function(output)
		art_inflight = false
		local path = coerce.text(output):match("([^\r\n]+)") or "NONE"
		local ok = path and path ~= "NONE" and path ~= ""
		if ok then
			show_artwork(path)
			art_tries = 0
		else
			show_icon_fallback()
			art_tries = art_tries + 1
		end
		if art_queued then
			local queued = art_queued
			art_queued = nil
			if (queued[1] .. "|" .. queued[2]) ~= req then
				refresh_artwork(queued[1], queued[2])
				return
			end
		end
		if not ok and art_tries < 2 and last_track == req then
			sbar.delay(1.5, function()
				if last_track == req and not art_inflight then
					refresh_artwork(app, title)
				end
			end)
		end
	end)
end

local function trim(s)
	return ((s or ""):match("^%s*(.-)%s*$")) or ""
end

local function set_visible(show)
	if visible == show then
		return
	end
	visible = show
	media_cover:set({ drawing = show })
	media_gap:set({ drawing = show })
	media_title:set({ drawing = show })
	media_artist:set({ drawing = show })
	if not show then
		media_lyric:set({ drawing = false })
		media_lyric_gap:set({ drawing = false })
		lyric_on = false
	end
end

local function paint_text()
	local shown = cur_title_shown
	local w = column_width(shown, cur_artist)
	if w > text_w_track then
		text_w_track = w
	end
	local title_c = cur_playing and colors.white or colors.with_alpha(colors.white, 0.55)
	local artist_c = cur_playing and colors.with_alpha(colors.white, 0.5) or colors.with_alpha(colors.white, 0.32)
	media_title:set({
		label = { string = shown, color = title_c, width = text_w_track },
	})
	media_artist:set({
		label = { string = cur_artist, color = artist_c, width = text_w_track },
	})
end

local function paint_lyric(line)
	if line == lyric_line and (line ~= "") == lyric_on then
		local c = cur_playing and colors.with_alpha(colors.white, 0.78) or colors.with_alpha(colors.white, 0.4)
		if lyric_on then
			media_lyric:set({ label = { color = c } })
		end
		return
	end
	lyric_line = line
	local show = visible and line ~= ""
	lyric_on = show
	if not show then
		media_lyric:set({ drawing = false, label = { string = "" } })
		media_lyric_gap:set({ drawing = false })
		return
	end
	local w = measure_text(line, LYRIC_SIZE)
	if w < 12 then
		w = 12
	end
	if w > MAX_LYRIC_W then
		w = MAX_LYRIC_W
	end
	media_lyric_gap:set({ drawing = true })
	media_lyric:set({
		drawing = true,
		label = {
			string = line,
			width = w,
			color = cur_playing and colors.with_alpha(colors.white, 0.78) or colors.with_alpha(colors.white, 0.4),
		},
	})
end

local function parse_idx(out)
	local rows = {}
	for line in (out or ""):gmatch("[^\r\n]+") do
		if line == "MISS" or line == "EMPTY" then
			return nil
		end
		local t, s = line:match("^([%d%.]+)\t(.*)$")
		t = tonumber(t)
		if t and s then
			rows[#rows + 1] = { t, s }
		end
	end
	if #rows == 0 then
		return nil
	end
	return rows
end

local function pick_lyric(pos)
	local t = (pos or 0) + 0.12
	local cur = ""
	local nxt = nil
	for i = 1, #lyric_rows do
		local when = lyric_rows[i][1]
		if when <= t then
			cur = lyric_rows[i][2]
		else
			nxt = when
			break
		end
	end
	local delay = nxt and (nxt - pos) or 2.5
	return cur, delay
end

local function clamp_delay(d)
	if not d then
		return 0.8
	end
	if d < 0.35 then
		return 0.35
	end
	if d > 2.2 then
		return 2.2
	end
	return d
end

local function load_lyrics()
	if cur_title == "" and cur_artist == "" then
		lyric_state = "miss"
		return
	end
	lyric_state = "loading"
	local gen = lyric_gen
	sbar.exec(
		string.format("$CONFIG_DIR/helpers/get_lyrics.sh dump %q %q", cur_title, cur_artist),
		function(out)
			if gen ~= lyric_gen then
				return
			end
			local rows = parse_idx(out)
			if rows then
				lyric_rows = rows
				lyric_state = "ready"
			else
				lyric_rows = {}
				lyric_state = "miss"
			end
		end
	)
end

local function apply(state, app, title, artist)
	state = trim(state)
	title = trim(title)
	artist = trim(artist)
	if title == "null" then
		title = ""
	end
	if artist == "null" then
		artist = ""
	end

	if not state or state == "stopped" or (title == "" and artist == "") then
		set_visible(false)
		last_key = ""
		last_track = ""
		cur_title = ""
		lyric_line = ""
		lyric_rows = {}
		lyric_state = "idle"
		lyric_gen = lyric_gen + 1
		text_w_track = 12
		return
	end

	local playing = (state == "playing")
	local key = state .. "|" .. (app or "") .. "|" .. title .. "|" .. artist
	if key == last_key then
		return
	end
	last_key = key

	set_visible(true)
	cur_app = app or "Media"
	cur_title = title
	cur_title_shown = title ~= "" and title or "正在播放"
	cur_artist = artist
	cur_playing = playing

	local track = (app or "") .. "|" .. title
	if track ~= last_track then
		last_track = track
		lyric_line = ""
		lyric_rows = {}
		lyric_state = "idle"
		lyric_gen = lyric_gen + 1
		text_w_track = 12
		art_tries = 0
		refresh_artwork(app, title)
		paint_lyric("")
		load_lyrics()
	end

	paint_text()
	if lyric_on then
		paint_lyric(lyric_line)
	end
	popup_toggle:set({
		icon = { color = playing and colors.white or colors.grey },
	})
end

local function apply_env(env)
	local info = env and env.INFO
	if type(info) ~= "table" then
		return false
	end
	apply(info.state, info.app, info.title, info.artist)
	return true
end

local function parse(out)
	out = coerce.text(out)
	if out == "" then
		return nil
	end
	return out:match("^([^|]*)|([^|]*)|([^|]*)|([^|\r\n]*)")
end

local inflight = false
local pending = false

local function update()
	if inflight then
		pending = true
		return
	end
	inflight = true
	sbar.exec("$CONFIG_DIR/helpers/get_media.sh", function(out)
		inflight = false
		if coerce.text(out):match("%S") then
			local a, b, c, d = parse(out)
			apply(a, b, c, d)
		end
		if pending then
			pending = false
			update()
		else
			sbar.delay(6, update)
		end
	end)
end

media_cover:subscribe("media_change", function(env)
	apply_env(env)
end)

local function tick_lyric()
	if not visible or cur_title == "" then
		sbar.delay(2, tick_lyric)
		return
	end
	if lyric_state == "miss" then
		sbar.delay(8, tick_lyric)
		return
	end
	if lyric_state ~= "ready" then
		if lyric_state ~= "loading" then
			load_lyrics()
		end
		sbar.delay(1, tick_lyric)
		return
	end
	if not cur_playing then
		if lyric_on then
			paint_lyric(lyric_line)
		end
		sbar.delay(2, tick_lyric)
		return
	end
	if lyric_inflight then
		sbar.delay(0.4, tick_lyric)
		return
	end
	lyric_inflight = true
	local gen = lyric_gen
	sbar.exec(
		string.format("$CONFIG_DIR/helpers/get_lyrics.sh pos %q", cur_app ~= "" and cur_app or "Media"),
		function(out)
			lyric_inflight = false
			if gen ~= lyric_gen then
				sbar.delay(0.4, tick_lyric)
				return
			end
			local pos = tonumber(trim(out or ""))
			if not pos then
				sbar.delay(1.5, tick_lyric)
				return
			end
			local line, delay = pick_lyric(pos)
			if line ~= lyric_line then
				paint_lyric(line)
			end
			sbar.delay(clamp_delay(delay), tick_lyric)
		end
	)
end

update()
tick_lyric()

local function click_exec(cmd)
	sbar.exec("$CONFIG_DIR/helpers/media_ctrl.sh " .. cmd, function()
		sbar.delay(0.2, update)
	end)
end

local function on_click(env)
	if env.BUTTON == "right" then
		media_cover:set({ popup = { drawing = "toggle" } })
	else
		click_exec("toggle")
	end
end

media_cover:subscribe("mouse.clicked", on_click)
media_title:subscribe("mouse.clicked", on_click)
media_artist:subscribe("mouse.clicked", on_click)
media_lyric:subscribe("mouse.clicked", on_click)

popup_prev:subscribe("mouse.clicked", function()
	click_exec("prev")
	media_cover:set({ popup = { drawing = false } })
end)
popup_toggle:subscribe("mouse.clicked", function()
	click_exec("toggle")
	media_cover:set({ popup = { drawing = false } })
end)
popup_next:subscribe("mouse.clicked", function()
	click_exec("next")
	media_cover:set({ popup = { drawing = false } })
end)

media_cover:subscribe("mouse.exited.global", function()
	media_cover:set({ popup = { drawing = false } })
end)
