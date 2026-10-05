## [素材用途] 组件检查脚本：验证复用、尺寸、进度范围、页签切换、设置信号和状态隐藏。
extends SceneTree

var errors: Array[String] = []

func _initialize() -> void:
	call_deferred("_verify")

func check(condition: bool, note: String) -> void:
	if not condition:
		errors.append(note)
		push_error(note)

func _verify() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 720)
	root.add_child(host)
	var hud = load("res://scenes/ui/examples/gameplay_hud.tscn").instantiate()
	var menu = load("res://scenes/ui/examples/character_menu.tscn").instantiate()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(hud)
	host.add_child(menu)
	await process_frame
	await process_frame
	check(hud.information.bars.size() == 4, "HUD must contain four stats")
	check(menu.information.bars.size() == 4, "Menu must contain the same four stat components")
	check(hud.information.bars["hp"].get_script() == menu.information.bars["hp"].get_script(), "HUD and menu must reuse the same stat script")
	check(menu.information.bars["hp"].font_size > hud.information.bars["hp"].font_size, "Menu stats must use a larger display size")
	check(hud.information.bars["hp"].name_label.get_theme_color("font_color").r > 0.7, "HP labels must retain their color at small size")
	hud.information.set_stat("hp", 999, 100)
	check(hud.information.bars["hp"].value == 100, "Bar values must clamp to maximum")
	hud.information.set_stat("mp", -5, 80)
	check(hud.information.bars["mp"].value == 0, "Bar values must clamp to zero")
	hud.information.set_stat("san", 0, 0)
	check(hud.information.bars["san"].progress.max_value > 0, "Zero maximum must not invalidate progress rendering")
	check(not hud.special_status.visible, "Special status must be hidden normally")
	var fatigue: Array[String] = ["疲劳"]
	hud.set_special_statuses(fatigue)
	check(hud.special_status.visible, "Special status must show when set")
	var empty: Array[String] = []
	hud.set_special_statuses(empty)
	check(not hud.special_status.visible, "Special status must hide when cleared")
	for id in ["status", "equipment", "items", "skills", "settings"]:
		menu.tabs[id].pressed.emit()
		check(menu.selected_tab == id, "Tab click must select " + id)
		var visible_count := 0
		for page in menu.pages.values():
			if page.visible:
				visible_count += 1
		check(visible_count == 1, "Exactly one page must be visible")
	check(menu.pages["settings"].buttons.size() == 4, "Settings must contain save/load/exit/unstuck")
	var received: Array[StringName] = []
	menu.settings_action_requested.connect(func(action): received.append(action))
	for id in ["save", "load", "exit", "unstuck"]:
		menu.pages["settings"].buttons[id].pressed.emit()
	check(received == [&"save", &"load", &"exit", &"unstuck"], "Settings buttons must emit separate game integration signals")
	menu.add_tab("quests", "任务")
	menu.select_tab("quests")
	check(menu.pages.has("quests") and menu.pages["quests"].visible, "New tabs must be addable without editing the shared component")
	var sample_items: Array[String] = ["测试物品"]
	menu.set_page_items("items", sample_items)
	check(menu.pages["items"].body.get_child(0).text == "测试物品", "Page content must be replaceable")
	var directions: Array[Vector2] = []
	hud.movement_changed.connect(func(direction): directions.append(direction))
	hud.joystick._update_direction(Vector2(999, 999))
	check(hud.joystick.direction.length() <= 1.001, "Joystick direction must normalize")
	hud.joystick._release()
	check(hud.joystick.direction == Vector2.ZERO and not directions.is_empty(), "Joystick release must reset and emit")
	host.queue_free()
	await process_frame
	if errors.is_empty():
		print("PASS: reusable stat scaling, limits, five tabs, four settings signals, hidden statuses, extensibility and joystick.")
		quit(0)
	else:
		quit(1)
