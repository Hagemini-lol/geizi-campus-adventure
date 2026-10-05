## [素材用途] 可复用属性条：文字、数值和进度填充分离；四种属性场景共用此脚本，可分别设置颜色与尺寸。
extends HBoxContainer

const Style = preload("res://scripts/ui/ui_style.gd")
## 属性显示名称，例如 HP 或精力。
@export var stat_name: String = "HP"
## 当前值；更新时限制在 0 与 maximum 之间。
@export var value: float = 86.0
## 属性上限；零上限也能安全绘制。
@export var maximum: float = 100.0
## 名称与数值的颜色，与对应填充保持一致。
@export var tint: Color = Style.HP
## 独立进度填充贴图，轨道与填充分离。
@export var fill_texture: Texture2D = preload("res://assets/ui/components/bars/hp_fill.svg")
## 关闭后隐藏名称，便于只显示进度条。
@export var show_name: bool = true
## 关闭后隐藏数值，便于只显示进度条。
@export var show_value: bool = true
## 文字字号；HUD 使用 14，菜单示例使用 20。
@export_range(10, 48) var font_size: int = 16
## 进度条高度；宽度由父容器分配。
@export_range(4, 32) var bar_height: int = 8
var name_label: Label
var value_label: Label
var progress: TextureProgressBar

func _ready() -> void:
	theme = Style.theme(font_size)
	add_theme_constant_override("separation", 8)
	name_label = Style.label(stat_name, font_size)
	value_label = Style.label("", font_size)
	name_label.visible = show_name
	value_label.visible = show_value
	add_child(name_label)
	add_child(value_label)
	progress = TextureProgressBar.new()
	progress.texture_under = preload("res://assets/ui/components/bars/track.svg")
	progress.texture_progress = fill_texture
	progress.nine_patch_stretch = true
	progress.stretch_margin_left = 2
	progress.stretch_margin_right = 2
	progress.stretch_margin_top = 2
	progress.stretch_margin_bottom = 2
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(progress)
	set_display_size(font_size, bar_height)
	set_value(value, maximum)

## 调整字号与条高；条宽由父容器控制，可在不同界面复用。
func set_display_size(new_font_size: int, new_bar_height: int = 8) -> void:
	font_size = new_font_size
	bar_height = new_bar_height
	custom_minimum_size = Vector2(font_size * 18 if show_name or show_value else 64, font_size + 10)
	if not is_instance_valid(name_label):
		return
	name_label.custom_minimum_size.x = font_size * 3.0
	value_label.custom_minimum_size.x = font_size * 5.2
	for item in [name_label, value_label]:
		item.add_theme_font_size_override("font_size", font_size)
		item.add_theme_color_override("font_color", tint)
	progress.custom_minimum_size.y = bar_height

## 更新当前值及可选上限；名称和数值无需重新生成图片。
func set_value(new_value: float, new_maximum: float = -1.0) -> void:
	if new_maximum >= 0.0:
		maximum = maxf(new_maximum, 0.0)
	value = clampf(new_value, 0.0, maximum)
	if is_instance_valid(progress):
		progress.max_value = maxf(maximum, 1.0)
		progress.value = value
		value_label.text = "%s/%s" % [str(int(value)), str(int(maximum))]
