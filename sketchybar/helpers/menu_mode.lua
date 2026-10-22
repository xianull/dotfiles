-- 菜单模式（点窗口名，把空间号换成当前应用的菜单栏）的共享状态：
--   menus.lua 进出菜单模式时改 on；spaces.lua 读它，菜单模式下不再把空间号重新画出来，
--   并把 resync 注册在这里，退出菜单模式后由 menus.lua 调用，按“隐藏空桌面”重新收一遍。
return { on = false, resync = function() end }
