## [素材用途] 通用选项按钮：支持菜单页签、设置操作及圆形 ABXY；显示文字与逻辑 ID 分离。
extends Button

const Style = preload("res://scripts/ui/ui_style.gd")
## 按钮显示文字，修改文字不必改变逻辑 ID。
@export var option_text: String = "选项"
## 稳定逻辑标识，用于连接菜单或游戏动作。
@export var option_id: StringName = &"option"
## 开启时使用圆形 ABXY 底板。
@export var round_button: bool = false
## 独立控制按钮文字字号。
@export_range(10, 48) var font_size: int = 18

func _ready() -> void:
	text = option_text
	theme = Style.theme(font_size)
	add_theme_font_size_override("font_size", font_size)
	add_theme_color_override("font_color", Style.TEXT)
	add_theme_color_override("font_hover_color", Color.WHITE)
	add_theme_color_override("font_pressed_color", Color.WHITE)
	add_theme_color_override("font_focus_color", Color.WHITE)
	custom_minimum_size = Vector2(54, 54) if round_button else Vector2(104, 42)
	for entry in [["normal", 0.24], ["hover", 0.46], ["pressed", 0.58], ["disabled", 0.12]]:
		if round_button:
			var disc := StyleBoxTexture.new()
			disc.texture = preload("res://assets/ui/components/controls/action_disc.svg")
			disc.modulate_color = Color(1, 1, 1, 0.5 if entry[0] == "disabled" else 1.0)
			add_theme_stylebox_override(entry[0], disc)
		else:
			var style := Style.panel(entry[1])
			if entry[0] == "pressed":
				style.bg_color = Color(0.52, 0.56, 0.60, 0.25)
				style.border_color = Color(0.92, 0.94, 0.95, 0.9)
			add_theme_stylebox_override(entry[0], style)
	var focus_style := Style.panel(0.0, 27 if round_button else 0)
	focus_style.border_color = Color(0.94, 0.95, 0.96, 0.9)
	add_theme_stylebox_override("focus", focus_style)
