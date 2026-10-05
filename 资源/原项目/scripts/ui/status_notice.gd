## [素材用途] 特殊状态提示组件：列表为空时隐藏，有状态时显示像素块底板；不用于常驻普通状态。
extends PanelContainer

const Style = preload("res://scripts/ui/ui_style.gd")
## 特殊状态名称列表；为空时隐藏整个组件。
@export var statuses: Array[String] = []
## 状态提示文字字号。
@export var font_size: int = 14
var status_label: Label

func _ready() -> void:
	theme = Style.theme(font_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pixel_style := StyleBoxTexture.new()
	pixel_style.texture = preload("res://assets/ui/components/panels/special_status.svg")
	pixel_style.texture_margin_left = 4
	pixel_style.texture_margin_top = 4
	pixel_style.texture_margin_right = 16
	pixel_style.texture_margin_bottom = 8
	pixel_style.content_margin_left = 10
	pixel_style.content_margin_top = 5
	pixel_style.content_margin_right = 20
	pixel_style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", pixel_style)
	status_label = Style.label("", font_size)
	add_child(status_label)
	set_statuses(statuses)

## 非空列表显示提示；空列表自动隐藏整个状态框。
func set_statuses(new_statuses: Array[String]) -> void:
	statuses = new_statuses.duplicate()
	visible = not statuses.is_empty()
	if is_instance_valid(status_label):
		status_label.text = "■ " + " · ".join(statuses)
