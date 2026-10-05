## [素材用途] 信息栏组合组件：实例化同一套四种属性条；字号和条高由 HUD 或菜单选择。
extends PanelContainer

const Style = preload("res://scripts/ui/ui_style.gd")
const StatScenes := {
	"hp": preload("res://scenes/ui/components/hp_bar.tscn"),
	"mp": preload("res://scenes/ui/components/mp_bar.tscn"),
	"energy": preload("res://scenes/ui/components/energy_bar.tscn"),
	"san": preload("res://scenes/ui/components/san_bar.tscn")
}
## 四种属性条统一字号，用于切换 HUD 或菜单尺寸。
@export var font_size: int = 14
## 四种属性条统一高度。
@export var bar_height: int = 6
## 是否显示日期时间，菜单示例关闭。
@export var show_date: bool = true
## 日期时间显示内容，可通过 set_date 更新。
@export var date_text: String = "第1天 08:30"
var bars: Dictionary = {}
var date_label: Label

func _ready() -> void:
	theme = Style.theme(font_size)
	add_theme_stylebox_override("panel", Style.panel())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	add_child(column)
	for id in StatScenes:
		var bar = StatScenes[id].instantiate()
		bar.font_size = font_size
		bar.bar_height = bar_height
		column.add_child(bar)
		bars[id] = bar
	date_label = preload("res://scenes/ui/components/date_label.tscn").instantiate()
	date_label.text = date_text
	date_label.add_theme_font_size_override("font_size", font_size)
	date_label.visible = show_date
	column.add_child(date_label)

## 按 hp / mp / energy / san 标识更新对应属性条。
func set_stat(id: String, current: float, maximum: float = -1.0) -> void:
	if bars.has(id):
		bars[id].set_value(current, maximum)

## 更新日期时间文字，保持显示格式一致。
func set_date(day: int, hour: int, minute: int) -> void:
	date_text = "第%d天 %02d:%02d" % [day, hour, minute]
	if is_instance_valid(date_label):
		date_label.text = date_text
