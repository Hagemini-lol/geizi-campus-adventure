## 素材演出验收：不写入招式数据，不计算任何战斗结果。
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
	var presenter = battle.action_presenter
	var ally = battle.ally_slot
	var base: Texture2D = ally.portrait
	var origin: Vector2 = ally.position
	check(presenter.pose_textures.size() == 2, "Only punch and dodge pose variants should be configured")
	for texture in presenter.pose_textures.values():
		check(texture is Texture2D and texture.get_image().get_pixel(0, 0).a == 0, "Pose variants must be usable transparent textures")
	for sample in ["punch", "dodge_success", "dodge_failure", "hit", "auto_battle"]:
		check(presenter.show_sample(sample), "Sample must display: " + sample)
		check(presenter.active_effects.size() == 1, "Sample must contain one independent effect")
		var effect = presenter.active_effects[0]
		check(not effect.playing and effect.visible, "Sample must freeze visible effect")
		if sample == "punch":
			check(ally.displayed_pose == presenter.pose_textures["punch"], "Punch must switch pose")
		elif sample.begins_with("dodge_"):
			check(ally.displayed_pose == presenter.pose_textures["dodge"], "Both dodge outcomes must use dodge pose")
		elif sample == "auto_battle":
			check(effect.text_label.text == "woc我忘吃饭了", "Auto battle dialogue must exactly match requested text")
			check(effect.position.y >= 0 and effect.position.y < ally.global_position.y, "Auto battle bubble must remain on screen above hero")
		check(ally.portrait == base, "Pose differences must preserve base portrait")
		presenter.stop()
		await process_frame
		check(ally.displayed_pose == base and ally.position == origin and ally.portrait_view.modulate == Color.WHITE, "Stop must restore pose, position and color")
		check(presenter.effect_layer.get_child_count() == 0, "Stop must clear old effect nodes")
	check(not presenter.show_sample("unknown"), "Unknown sample must fail safely")
	var completions: Array[int] = []
	presenter.presentation_finished.connect(func(): completions.append(1))
	check(presenter.play_punch(), "Punch must start playing")
	await create_timer(0.85).timeout
	check(not presenter.busy and ally.displayed_pose == base and completions.size() == 1, "Punch must automatically complete and restore")
	check(presenter.play_dodge(true), "Success dodge must start")
	await create_timer(1.1).timeout
	check(not presenter.busy and ally.position == origin and completions.size() == 2, "Dodge must complete and restore original foot position")
	check(presenter.play_dodge(false), "Failed dodge must start")
	await create_timer(0.25).timeout
	check(ally.portrait_view.modulate.g < 1, "Failure should briefly tint hero red")
	check(presenter.play_auto_battle(), "Auto battle must interrupt previous feedback safely")
	check(presenter.active_effects.size() == 1 and ally.displayed_pose == base and ally.portrait_view.modulate == Color.WHITE, "New action must clear prior pose and tint")
	await create_timer(3.1).timeout
	check(not presenter.busy and presenter.active_effects.is_empty(), "Auto battle dialogue must expire and clean up")
	check(not presenter.play_hit(&"invalid"), "Unknown impact side must fail safely")
	check(presenter.play_hit(&"ally"), "Impact should work for ally")
	await create_timer(0.85).timeout
	check(not presenter.busy and ally.position == origin, "Impact shake must restore actor")
	battle.open_category(&"auto_battle")
	check(presenter.busy and presenter.active_effects.size() == 1 and presenter.active_effects[0].effect_kind == "auto_battle", "Auto battle option must trigger its exclusive dialogue")
	host.size = Vector2(800, 600)
	await process_frame
	await process_frame
	check(not presenter.busy and presenter.active_effects.is_empty(), "Resize must clear active presentation and restore composition")
	check(ally.position.x >= 0 and ally.position.y + ally.size.y <= battle.stage.size.y, "Resized composition must keep actor in the stage")
	for submenu in battle.submenus.values():
		check(submenu.entries.is_empty(), "Visual preview must not populate concrete move menus")
	host.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: two transparent pose variants, four effects, exact auto dialogue, animation completion, interruption cleanup and empty move menus.")
		quit(0)
	else:
		quit(1)
