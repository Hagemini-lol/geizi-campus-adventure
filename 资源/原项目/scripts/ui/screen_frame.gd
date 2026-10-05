## [素材用途] 可适配尺寸的黑白窄边框：随父容器尺寸重绘，并忽略鼠标事件。
extends Control

## 边线不透明度；0 完全透明，1 完全不透明。
@export var line_opacity: float = 0.7

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), Color(0, 0, 0, line_opacity), false, 2)
	draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), Color(0.92, 0.93, 0.94, line_opacity), false, 1)
