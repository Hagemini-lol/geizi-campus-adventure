## [素材用途] 独立移动摇杆：支持鼠标和单指触摸，提供方向信号；此组件不直接移动角色。
extends Control

## 拖动或释放时输出方向；仅提供输入，不直接移动角色。
signal direction_changed(direction: Vector2)
## 中心死区比例，避免轻微拖动造成移动。
@export var dead_zone: float = 0.12
var direction := Vector2.ZERO
var dragging := false
var touch_index := -1

func _ready() -> void:
	custom_minimum_size = Vector2(100, 100)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.48
	draw_circle(center, radius, Color(0.05, 0.07, 0.09, 0.22))
	draw_arc(center, radius, 0, TAU, 96, Color(0.80, 0.82, 0.85, 0.6), 1, true)
	for axis in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		var p: Vector2 = center + axis * radius * 0.80
		draw_circle(p, 2, Color(0.83, 0.85, 0.88, 0.6))
	var knob_center := center + direction * radius * 0.55
	draw_circle(knob_center, radius * 0.35, Color(0.62, 0.66, 0.71, 0.28))
	draw_arc(knob_center, radius * 0.35, 0, TAU, 64, Color(0.88, 0.90, 0.92, 0.75), 1, true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		dragging = true
		touch_index = -1
		_update_direction(event.position)
		accept_event()
	elif event is InputEventScreenTouch and event.pressed and not dragging:
		dragging = true
		touch_index = event.index
		_update_direction(event.position)
		accept_event()

func _input(event: InputEvent) -> void:
	if not dragging:
		return
	if touch_index == -1:
		if event is InputEventMouseMotion:
			_update_direction(get_local_mouse_position())
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_release()
	elif event is InputEventScreenDrag and event.index == touch_index:
		_update_direction(get_global_transform_with_canvas().affine_inverse() * event.position)
	elif event is InputEventScreenTouch and event.index == touch_index and not event.pressed:
		_release()

func _update_direction(point: Vector2) -> void:
	var radius := maxf(minf(size.x, size.y) * 0.48 * 0.55, 1.0)
	direction = ((point - size * 0.5) / radius).limit_length(1.0)
	if direction.length() < dead_zone:
		direction = Vector2.ZERO
	direction_changed.emit(direction)
	queue_redraw()

## 释放拖动时归零并通知游戏，避免角色持续移动。
func _release() -> void:
	dragging = false
	touch_index = -1
	direction = Vector2.ZERO
	direction_changed.emit(direction)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree() and dragging:
		_release()
