-- 加载哪些小组件由方案决定（helpers/layout.lua），默认就是下面这份
-- Focus: pomodoro + todos (order matters for right-side layout)
for _, mod in ipairs(require("helpers.layout").list("widgets", {
  "items.widgets.battery",
  "items.widgets.volume",
  "items.widgets.cpu_temp",
  "items.widgets.cpu",
  "items.widgets.memory",
  "items.widgets.gpu",
  "items.widgets.wifi",
  "items.widgets.wechat_and_qq",
  "items.widgets.ai_usage",
  "items.widgets.pomodoro",
  "items.widgets.obsidian_todos",
  "items.widgets.focus_bracket",
})) do
  require(mod)
end