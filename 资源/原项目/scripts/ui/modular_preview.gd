## [素材用途] 素材预览专用场景：查看组合与点击反馈，不代替真实游戏存档或角色逻辑。
extends Control

const Style = preload("res://scripts/ui/ui_style.gd")
var hud: Control
var menu: Control
var message: Label

func _ready() -> void:
	theme = Style.theme(14)
	var backdrop := ColorRect.new()
	backdrop.color = Color("#4d6059")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	hud = preload("res://scenes/ui/examples/gameplay_hud.tscn").instantiate()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(hud)
	menu = preload("res://scenes/ui/examples/character_menu.tscn").instantiate()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu)
	menu.hide()
	menu.close_requested.connect(show_hud)
	menu.settings_action_requested.connect(func(action): message.text = "已选择：" + {"save": "保存", "load": "加载", "exit": "退出", "unstuck": "脱离卡死"}.get(String(action), String(action)))
	var tools := HBoxContainer.new()
	tools.anchor_left = 1
	tools.anchor_right = 1
	tools.offset_left = -284
	tools.offset_top = 8
	tools.offset_right = -8
	tools.offset_bottom = 44
	add_child(tools)
	for mode in ["游玩UI", "菜单UI", "特殊状态"]:
		var button := Button.new()
		button.text = mode
		tools.add_child(button)
		if mode == "游玩UI":
			button.pressed.connect(show_hud)
		elif mode == "菜单UI":
			button.pressed.connect(show_menu)
		else:
			button.pressed.connect(func():
				show_hud()
				var values: Array[String] = ["疲劳"] if hud.special_status.statuses.is_empty() else []
				hud.set_special_statuses(values)
			)
	message = Style.label("独立组件预览", 14)
	message.anchor_left = 0.3
	message.anchor_right = 0.7
	message.anchor_top = 1
	message.anchor_bottom = 1
	message.offset_top = -26
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(message)

func show_hud() -> void:
	hud.show()
	menu.hide()

func show_menu() -> void:
	menu.show()
	hud.hide()
