local settings = require("settings")

local icons = {
  sf_symbols = {
    plus = "􀅼",
    loading = "􀖇",
    apple = "􀣺",
    gear = "􀍟",
    cpu = "􀫥",
    clipboard = "􀉄",
    pomodoro = {
      work = "􀐭",
      ["break"] = "􀸙",
      paused = "􀐮",
    },

    switch = {
      on = "􁏮",
      off = "􁏯",
    },
    volume = {
      _100="􀊩",
      _66="􀊧",
      _33="􀊥",
      _10="􀊡",
      _0="􀊣",
    },		
    temperature = {
			_66 = "􁏄",
			_33 = "􀇬",
			_0 = "􁏃",
		},
    battery = {
      _100 = "􀛨",
      _75 = "􀺸",
      _50 = "􀺶",
      _25 = "􀛩",
      _0 = "􀛪",
      charging = "􀢋"
    },
    wifi = {
      upload = "􀄨",
      download = "􀄩",
      connected = "􀙇",
      disconnected = "􀙈",
      router = "􁓤",
    },
    media = {
      back = "􀊊",
      forward = "􀊌",
      play_pause = "􀊈",
    },
    qq = "󰘅",
    wechat = "󰘑",
    audio = {
      airpods = "􀪷",
      airpods_pro = "􀪷",
      airpods_max = "􀪶",
      headphones = "􀋋",
      speaker = "􀊠",
      iphone = "􀓱",
      ipad = "􀡚",
      macbook = "􀟛",
      display = "􀆿",
      beats = "􀪷",
      default = "􀊠",
    },
  },

  -- Alternative NerdFont icons
  nerdfont = {
    plus = "",
    loading = "",
    apple = "",
    gear = "",
    cpu = "",
    clipboard = "􀉄",

    switch = {
      on = "󱨥",
      off = "󱨦",
    },
    volume = {
      _100="",
      _66="",
      _33="",
      _10="",
      _0="",
    },
    battery = {
      _100 = "",
      _75 = "",
      _50 = "",
      _25 = "",
      _0 = "",
      charging = ""
    },
    wifi = {
      upload = "",
      download = "",
      connected = "󰖩",
      disconnected = "󰖪",
      router = "Missing Icon"
    },
    media = {
      back = "",
      forward = "",
      play_pause = "",
    },
    qq = "󰘅",
    wechat = "󰘑",
    pomodoro = {
      work = "󱎫",
      ["break"] = "󰻂",
      paused = "󱎺",
    },
    audio = {
      airpods = "󰋜",
      airpods_pro = "󰋜",
      airpods_max = "󰋝",
      headphones = "󰋋",
      speaker = "󰓃",
      iphone = "󰀲",
      ipad = "󰀳",
      macbook = "󰀂",
      display = "󰍹",
      beats = "󰋜",
      default = "󰕾",
    },
  },
}

if not (settings.icons == "NerdFont") then
  return icons.sf_symbols
else
  return icons.nerdfont
end
