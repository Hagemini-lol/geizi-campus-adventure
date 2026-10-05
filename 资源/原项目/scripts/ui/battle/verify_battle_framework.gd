## 框架检查：只用临时探针验证扩展接口，不写入或制作任何具体招式。
extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_verify")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _verify() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 720)
	root.add_child(host)
	var battle = load("res://scenes/ui/battle/battle_interface.tscn").instantiate()
	battle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(battle)
	await process_frame
	await process_frame
	var categories: Array[StringName] = [&"attack", &"magic", &"dodge", &"items", &"surrender", &"auto_battle"]
	check(battle.category_buttons.size() == 6, "Must provide six independent categories")
	var definition = JSON.parse_string(FileAccess.get_file_as_string("res://data/battle_ui_library.json"))
	for category in definition["categories"]:
		check(category["commands"].is_empty(), "Saved categories must contain no concrete commands")
	for id in categories:
		check(battle.submenus[id].entries.is_empty(), "Each submenu must start empty")
		battle.category_buttons[id].pressed.emit()
		check(battle.selected_category == id, "Click must open " + String(id))
		var visible_count := 0
		for submenu in battle.submenus.values():
			if submenu.visible:
				visible_count += 1
		check(visible_count == 1, "Exactly one submenu must be visible")
		check(battle.submenus[id].empty_label.visible, "Empty submenu must show empty state")
		battle.submenus[id].back_button.pressed.emit()
		check(battle.selected_category == &"" and battle.idle_label.visible, "Back must restore category state")
	check(battle.ally_slot.portrait != null, "Ally must reuse existing hero artwork")
	check(battle.enemy_slot.portrait == null and battle.enemy_slot.placeholder.visible, "Enemy must remain an editable placeholder")
	check(battle.ally_slot.get_parent() == battle.stage and battle.enemy_slot.get_parent() == battle.stage, "Combatants must share one battle viewport")
	check(battle.ally_slot.size.y > battle.enemy_slot.size.y and battle.ally_slot.position.y + battle.ally_slot.size.y > battle.enemy_slot.position.y + battle.enemy_slot.size.y, "Near ally must appear larger and lower than distant enemy")
	check(battle.stage.background_texture == null, "Default background must be replaceable placeholder")
	var test_image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	test_image.fill(Color(0.2, 0.3, 0.4, 1))
	var test_background := ImageTexture.create_from_image(test_image)
	battle.open_category(&"magic")
	var original_portrait: Texture2D = battle.ally_slot.portrait
	battle.set_battle_background(test_background)
	check(battle.stage.background_view.texture == test_background and battle.stage.background_view.visible, "Background switch must update environment layer")
	check(battle.ally_slot.portrait == original_portrait and battle.selected_category == &"magic", "Background switch must preserve actors and menu state")
	battle.set_battle_background(null)
	check(not battle.stage.background_view.visible and battle.stage.background_texture == null, "Null must restore placeholder environment")
	battle.stage.set_composition(Vector2(0.2, 0.9), Vector2(0.7, 0.6), 0.85, 0.4)
	check(battle.stage.ally_foot == Vector2(0.2, 0.9) and battle.stage.enemy_height_ratio == 0.4, "Composition must remain adjustable for future backgrounds")
	battle.stage.set_composition(Vector2(0.25, 0.90), Vector2(0.73, 0.6))
	check(battle.ally_slot.position.y + battle.ally_slot.size.y <= battle.stage.size.y, "Near actor name must remain within battlefield")
	battle.return_to_categories()
	var received: Array[Dictionary] = []
	battle.action_selected.connect(func(category, command, payload): received.append({"category": category, "command": command, "payload": payload}))
	var probes: Array[Dictionary] = [
		{"id": "__enabled_probe", "label": "接口验证", "payload": {"probe": true}},
		{"id": "__disabled_probe", "label": "禁用验证", "enabled": false}
	]
	check(battle.set_category_entries(&"attack", probes), "Future entries must be injectable")
	battle.open_category(&"attack")
	var attack = battle.submenus[&"attack"]
	check(attack.command_buttons.size() == 2 and not attack.empty_label.visible, "New entries must create independent buttons")
	attack.command_buttons[&"__enabled_probe"].pressed.emit()
	check(received.size() == 1, "Enabled entry must emit once")
	check(received[0]["category"] == &"attack" and received[0]["command"] == &"__enabled_probe" and received[0]["payload"]["probe"], "Selection must preserve category, ID and payload")
	attack.command_buttons[&"__disabled_probe"].pressed.emit()
	check(received.size() == 1, "Disabled entries must not submit")
	var duplicate: Array[Dictionary] = [{"id": "same", "label": "探针"}, {"id": "same", "label": "探针"}]
	check(not attack.set_entries(duplicate) and attack.entries.size() == 2, "Duplicate IDs must reject atomically")
	battle.set_turn_state(2, "敌方行动", false)
	check(not battle.open_category(&"magic"), "Disallowed input must block categories")
	battle.category_buttons[&"attack"].pressed.emit()
	attack.command_requested.emit(&"attack", &"__enabled_probe", {})
	check(received.size() == 1 and battle.selected_category == &"", "Inactive input must block late submissions")
	battle.set_input_enabled(true)
	check(battle.open_category(&"attack"), "Input must be restorable")
	battle.open_category(&"magic")
	attack.command_requested.emit(&"attack", &"__enabled_probe", {})
	check(received.size() == 1, "Hidden submenu must not submit")
	check(not battle.open_category(&"missing"), "Unknown categories must fail safely")
	check(battle.add_category(&"extension_probe", "扩展类别"), "Additional category must be reusable")
	check(not battle.add_category(&"extension_probe", "扩展类别"), "Duplicate categories must reject")
	host.size = Vector2(800, 600)
	await process_frame
	await process_frame
	check(battle.category_grid.columns == 3, "Compact width must wrap main categories")
	for id in categories:
		var empty: Array[Dictionary] = []
		battle.set_category_entries(id, empty)
		check(battle.submenus[id].entries.is_empty(), "Entries must be removable")
	host.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: shared battle viewport, near/far composition, background switch/reset, six empty menus, command injection, input gating and compact layout.")
		quit(0)
	else:
		quit(1)
