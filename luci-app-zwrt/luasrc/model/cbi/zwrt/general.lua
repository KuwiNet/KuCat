local m, s, o

m = Map("zwrt", translate("ZWRT Theme"), translate("ZWRT 主题外观设置"))

s = m:section(NamedSection, "basic", "basic", translate("基本设置"))
s.addremove = false
s.anonymous = true

o = s:option(ListValue, "mode", translate("主题模式"))
o:value("light", translate("浅色"))
o:value("dark", translate("深色"))
o:value("auto", translate("自动"))
o.default = "light"

o = s:option(Flag, "bkuse", translate("启用背景壁纸"))
o.default = "1"
o.rmempty = false

o = s:option(ListValue, "background", translate("背景来源"))
o:value("0", translate("内置默认"))
o:value("1", translate("iciba"))
o:value("2", translate("bing"))
o:value("3", translate("birdpaper"))
o:value("4", translate("birdpaper 2"))
o:value("5", translate("自定义"))
o.default = "0"
o:depends("bkuse", "1")

o = s:option(Value, "primary_rgbs", translate("主色 RGB（亮）"))
o.placeholder = "28,66,188"

o = s:option(Value, "primary_rgbm", translate("主色 RGB（暗）"))
o.placeholder = "20,109,179"

o = s:option(Value, "primary_opacity", translate("主色透明度 (0-100)"))
o.placeholder = "0"

o = s:option(Flag, "setbar", translate("显示侧边栏"))
o.default = "1"

o = s:option(Flag, "dayword", translate("每日一言"))
o.default = "0"

o = s:option(Value, "font_d", translate("大号字体"))
o.placeholder = "1.1rem"

o = s:option(Value, "font_z", translate("中号字体"))
o.placeholder = "0.92rem"

o = s:option(Value, "font_x", translate("小号字体"))
o.placeholder = "0.875rem"

return m
