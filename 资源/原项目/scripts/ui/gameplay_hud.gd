## [素材用途] 游玩 HUD 组合示例：使用小尺寸信息条，特殊状态上接信息栏，输入通过信号转交游戏。
extends Control

## 输出 x / y / a / b，具体作用由游戏定义。
signal action_requested(action: StringName)
## 输出长度不超过 1 的方向向量，零向量表示停止。
signal movement_changed(direction: Vector2)

var information: PanelContainer
var special_status: PanelContainer
var joystick: Control
var action_buttons: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame = preload("res://scenes/ui/components/screen_frame.tscn").instantiate()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frame)
	var top_left := VBoxContainer.new()
	top_left.add_theme_constant_override("separation", 0)
	top_left.custom_minimum_size.x = 300
	top_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_left)
	information = preload("res://scenes/ui/components/information_panel.tscn").instantiate()
	top_left.add_child(information)
	special_status = preload("res://scenes/ui/components/special_status.tscn").instantiate()
	special_status.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	top_left.add_child(special_status)
	joystick = preload("res://scenes/ui/components/joystick.tscn").instantiate()
	joystick.anchor_top = 1
	joystick.anchor_bottom = 1
	joystick.offset_left = 24
	joystick.offset_top = -184
	joystick.offset_right = 184
	joystick.offset_bottom = -24
	add_child(joystick)
	joystick.direction_changed.connect(func(direction): movement_changed.emit(direction))
	var actions := Control.new()
	actions.anchor_left = 1
	actions.anchor_right = 1
	actions.anchor_top = 1
	actions.anchor_bottom = 1
	actions.offset_left = -196
	actions.offset_top = -196
	actions.offset_right = -24
	actions.offset_bottom = -24
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(actions)
	var positions := {"y": Vector2(58, 0), "x": Vector2(0, 58), "b": Vector2(116, 58), "a": Vector2(58, 116)}
	for id in positions:
		var button = load("res://scenes/ui/components/action_%s.tscn" % id).instantiate()
		button.position = positions[id]
		actions.add_child(button)
		button.pressed.connect(func(): action_requested.emit(StringName(id)))
		action_buttons[id] = button

## 设置特殊状态列表；HUD 常态不显示此栏。
func set_special_statuses(statuses: Array[String]) -> void:
	special_status.set_statuses(statuses)
