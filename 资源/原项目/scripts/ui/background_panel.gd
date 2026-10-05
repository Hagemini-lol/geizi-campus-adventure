## [素材用途] 通用半透明底板：透明度与内边距可独立调整，用作后续新增 UI 的基础。
extends PanelContainer

const Style = preload("res://scripts/ui/ui_style.gd")
## 底板不透明度；0 完全透明，1 完全不透明。
@export_range(0.0, 1.0) var background_opacity: float = 0.46
## 底板四周内容内边距。
@export var content_padding: int = 12

func _ready() -> void:
	var style := Style.panel(background_opacity)
	style.content_margin_left = content_padding
	style.content_margin_right = content_padding
	style.content_margin_top = content_padding
	style.content_margin_bottom = content_padding
	add_theme_stylebox_override("panel", style)
