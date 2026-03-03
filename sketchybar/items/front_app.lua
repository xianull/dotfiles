local colors = require("colors")
local settings = require("settings")

local front_app = sbar.add("item", "front_app", {
  display = "active",
  icon = { drawing = false },
  label = {
    font = {
      size = 12.0,
    },
  },
  updates = true,
})

front_app:subscribe("front_app_switched", function(env)
  -- Fade out old name
  sbar.animate("tanh", 8, function()
    front_app:set({
      label = { color = colors.with_alpha(colors.white, 0.0) },
    })
  end)
  -- After fade out, swap text and fade back in
  sbar.exec("sleep 0.1", function()
    front_app:set({ label = { string = env.INFO } })
    sbar.animate("tanh", 12, function()
      front_app:set({
        label = { color = colors.white },
      })
    end)
  end)
end)

front_app:subscribe("mouse.clicked", function(env)
  sbar.trigger("swap_menus_and_spaces")
end)
