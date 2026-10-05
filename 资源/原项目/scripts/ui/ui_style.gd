## [素材用途] 共享视觉规范：四色属性、半透明底板、灰白细线和中文字体。修改这里可统一调整组件风格。
extends RefCounted

const HP := Color("#e36b6b")
const MP := Color("#629edb")
const ENERGY := Color("#e0c564")
const SAN := Color("#78bd82")
const TEXT := Color(0.88, 0.90, 0.91, 0.95)

static func panel(opacity: float = 0.46, radius: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.16, opacity)
	style.border_color = Color(0.73, 0.76, 0.79, 0.60)
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

static func theme(font_size: int = 16) -> Theme:
	var result := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	result.default_font = font
	result.default_font_size = font_size
	result.set_color("font_color", "Label", TEXT)
	return result

static func label(value: String, font_size: int = 16) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", TEXT)
	return result
