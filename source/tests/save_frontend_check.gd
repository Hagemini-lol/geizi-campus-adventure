extends SceneTree

var game: Node2D
var checks:=0
var failures: Array[String]=[]
var reader:=false
func _initialize() -> void:call_deferred("run")
func check(value: bool, message: String) -> void:
	checks+=1
	if not value:failures.append(message);push_error(message)
func frames() -> void:
	await process_frame
	await process_frame
func wait_transition() -> void:
	var deadline:=Time.get_ticks_msec()+20000
	while game.transition_busy and Time.get_ticks_msec()<deadline:await process_frame
	check(not game.transition_busy,"transition finishes within deadline")
	await physics_frame
	await frames()
func click(control: Control) -> void:
	if DisplayServer.get_name()=="headless":
		(control as Button).pressed.emit();await frames();return
	await frames()
	var at:=control.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new()
	motion.position=at;motion.global_position=at
	root.push_input(motion,true)
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT;event.position=at;event.global_position=at;event.pressed=true
	root.push_input(event,true)
	await frames()
	event=event.duplicate();event.pressed=false
	root.push_input(event,true)
	await frames()
func right_click() -> void:
	if DisplayServer.get_name()=="headless":game.toggle_menu();await frames();return
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_RIGHT;event.position=Vector2(900,600);event.global_position=event.position;event.pressed=true
	root.push_input(event,true);await frames()
	event=event.duplicate();event.pressed=false
	root.push_input(event,true);await frames()
func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	var directory: String=game.terrain.asset_root.path_join("存读档与封面预览")
	DirAccess.make_dir_recursive_absolute(directory)
	root.get_texture().get_image().save_png(directory.path_join(name+".png"))
func write(path: String, text: String) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(text);file.close()
func verify_state(slot: int) -> void:
	var record: Dictionary=game.save_store.read_slot(slot)
	check(record["ok"],"slot %d readable" % slot)
	var state: Dictionary=record["state"]
	check(game.player.position.distance_to(Vector2(state["position"][0],state["position"][1]))<.1,"slot %d exact position restored" % slot)
	check(game.day_clock.display_text()==state["period"],"time period restored")
	check(game.player.facing==int(state["facing"]),"facing restored")
	check(is_equal_approx(game.player.camera.zoom.x,minf(state["camera_zoom"],game.maximum_clear_zoom())),"camera zoom restored")
	check(is_equal_approx(game.outdoor_zoom,state["outdoor_zoom"]),"outdoor zoom restored")
	check(game.event_state==state["events"],"event data round trip")
	check(game.player.path.is_empty() and not game.player.frozen,"route cleared and controls restored")
	check(not game.front_end.visible and not game.menu_view.visible and game.gameplay_hud.visible,"gameplay visible after load")
	check(game.terrain.get_child_count()==1 and game.terrain.max_scene_count==1,"only one active world scene")
	if state["scene"]["kind"]=="outdoor":
		check(game.interior_state.is_empty() and game.model["regions"][game.terrain.current_id]["id"]==state["scene"]["region"],"correct outdoor district restored")
	else:
		var restored: Dictionary=game.interior_state
		var expected: Dictionary=state["scene"]
		check(restored["kind"]==expected["kind"] and restored["building"]==expected["building"] and int(restored["floor"])==int(expected["floor"]) and int(restored.get("room",-1))==int(expected.get("room",-1)),"correct building floor room restored")
func finish() -> void:
	var result: Dictionary={"checks":checks,"failures":failures,"reader":reader,"save_directory":game.save_store.directory,"active_scenes":game.terrain.get_child_count(),"max_scenes":game.terrain.max_scene_count}
	write(game.package_root.path_join("存读档验证报告_"+("重启" if reader else "界面")+".json"),JSON.stringify(result,"  "))
	print("SAVE_FRONTEND_CHECK: ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
func run() -> void:
	reader="--reader" in OS.get_cmdline_user_args()
	game=(load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game);await frames()
	var front: Control=game.front_end
	check(front.title_visible and front.visible and not game.game_started,"startup title screen")
	check(front.cover.texture!=null and front.cover.texture.get_image().has_mipmaps(),"existing HD cover loaded")
	check(front.title_buttons.size()==4,"start load exit settings available")
	check(game.terrain.get_child_count()==0 and game.terrain.current_scene==null,"no map loaded on title")
	check(game.player.frozen and not game.player.visible and not game.gameplay_hud.visible,"title freezes and hides hero HUD")
	check(not game.advance_time_from_event() and not game.request_path(game.spawn),"title blocks time and movement")
	if reader:
		check(game.preferences.values["master"]==33 and game.preferences.values["music"]==44 and game.preferences.values["sfx"]==55,"volumes persisted across process restart")
		check(game.preferences.values["resolution"]==1 and game.preferences.values["fps"]==120 and not game.preferences.values["vsync"],"display settings persisted across process restart")
		await click(front.title_buttons["load"])
		check(front.slot_buttons[1].disabled==false and front.slot_buttons[3].disabled==false,"saved slots visible on reopened title")
		await click(front.slot_buttons[3]);await wait_transition();verify_state(3)
		check(game.interior_state["kind"]=="classroom" and game.interior_state["floor"]==3 and game.interior_state["room"]==0,"restart loads third floor ten classroom")
		await shot("重启读取十班")
		finish();return
	await shot("游戏封面")
	await click(front.title_buttons["load"])
	check(front.modal.visible and front.slot_mode=="load","title load opens selector")
	for slot: int in range(1,6):check(front.slot_buttons[slot].disabled,"empty slot disabled")
	await click(front.back_button)
	check(front.title_actions.visible and not front.modal.visible,"load back returns cover")
	await click(front.title_buttons["settings"])
	check(front.settings_open and front.settings_controls.size()==8,"title settings opens all controls")
	await shot("设置")
	front.settings_controls["master"].value=0
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")),"zero volume mutes master immediately")
	await click(front.back_button)
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")) and game.preferences.values["master"]==80,"back cancels unsaved volume preview")
	await click(front.title_buttons["start"]);await wait_transition()
	check(game.game_started and game.front_end.cover.texture==null,"start enters game and releases cover")
	check(game.player.position==game.spawn and game.day_clock.display_text()=="上午","new game begins at south gate morning")
	check(game.terrain.get_child_count()==1 and not game.player.frozen,"start loads one scene with controllable hero")
	game.day_clock.current_period=4;game.apply_time_lighting()
	game.player.show_direction(2);game.player.camera.zoom=Vector2.ONE*1.2;game.outdoor_zoom=1.2
	game.event_state={"test_flag":true,"nested":{"value":7}}
	await right_click()
	await click(game.menu_view.tabs["saves"])
	check(game.menu_view.selected_tab=="saves","right-click menu has save/load tab")
	await shot("菜单存读档")
	await click(game.menu_view.actions["save"])
	check(front.visible and game.menu_view.visible and game.player.frozen,"save selector overlays menu and freezes")
	check(not game.request_path(game.spawn) and game.time_skip_button.disabled,"modal blocks movement and fast forward")
	await click(front.slot_buttons[1])
	check(game.save_store.read_slot(1)["ok"] and front.message.text.contains("已保存"),"actual save button writes slot")
	await shot("保存游戏")
	var bytes:=FileAccess.get_file_as_bytes(game.save_store.slot_path(1))
	await click(front.slot_buttons[1])
	check(front.overwrite.visible,"overwrite asks confirmation")
	front.overwrite.get_cancel_button().pressed.emit();front.overwrite.hide();await frames()
	check(FileAccess.get_file_as_bytes(game.save_store.slot_path(1))==bytes,"cancel leaves original save byte identical")
	await click(front.slot_buttons[1])
	front.overwrite.get_ok_button().pressed.emit();await frames()
	check(FileAccess.file_exists(game.save_store.slot_path(1)+".bak"),"confirmed overwrite retains backup")
	await click(front.back_button)
	check(game.menu_view.visible and game.player.frozen,"back to menu remains frozen")
	game.close_menu()
	game.day_clock.current_period=1;game.apply_time_lighting();game.player.show_direction(3)
	game.player.position+=Vector2(0,-25);game.player.camera.zoom=Vector2.ONE*1.8
	check(game.load_game_slot(1)["ok"],"outdoor load accepted");await wait_transition();verify_state(1)
	check(game.terrain.modulate==game.day_clock.tint(false),"night lighting restored")
	game.change_interior({"kind":"corridor","building":"B12","floor":3},Vector2(130,122));await wait_transition()
	game.player.camera.zoom=Vector2.ONE*1.8;game.player.show_direction(1)
	check(game.save_game_slot(2)["ok"],"third-floor corridor saved")
	game.change_interior({"kind":"classroom","building":"B12","floor":3,"room":0});await wait_transition()
	check(game.save_game_slot(3)["ok"],"ten classroom saved")
	game.change_interior({"kind":"classroom","building":"B05","floor":2,"room":1},Vector2(INF,INF),"rear");await wait_transition()
	check(game.save_game_slot(4)["ok"],"ordinary classroom rear entrance saved")
	game.change_interior({"kind":"corridor","building":"B02","floor":4});await wait_transition()
	check(game.save_game_slot(5)["ok"],"laboratory fourth floor saved")
	for slot: int in [2,3,4,5,1]:
		check(game.load_game_slot(slot)["ok"],"interior/outdoor restore accepted")
		await wait_transition();verify_state(slot)
	game.toggle_menu();game.menu_view.select_tab("saves");game.menu_action("load");await frames()
	await shot("加载存档")
	await click(front.slot_buttons[3]);await wait_transition();verify_state(3)
	check(game.request_path(game.terrain.current_scene.navigation.astar.get_point_position(game.terrain.current_scene.navigation.closest_cell(game.player.position))),"restored room accepts navigation")
	game.player.path.clear()
	# Invalid data must not change the live scene or position.
	var old_scene: Node2D=game.terrain.current_scene
	var old_position: Vector2=game.player.position
	var valid: Dictionary=game.save_store.read_slot(3)["state"]
	for variant: Dictionary in [{"period":"25:00"},{"scene":{"kind":"classroom","building":"B99","floor":1,"room":0}},{"scene":{"kind":"classroom","building":"B12","floor":3,"room":999}},{"position":[-999,999]},{"facing":99}]:
		var invalid:=valid.duplicate(true);invalid.merge(variant,true)
		check(not game.queue_restore(invalid,"invalid")["ok"],"semantic invalid state rejected")
		check(game.terrain.current_scene==old_scene and game.player.position==old_position and not game.transition_busy,"invalid load preserves live game")
	var slot1: String=game.save_store.slot_path(1)
	var primary:=FileAccess.get_file_as_string(slot1)
	write(slot1,"damaged")
	check(game.save_store.read_slot(1)["backup"],"damaged primary recovers backup")
	check(game.load_game_slot(1)["ok"],"backup load accepted");await wait_transition();verify_state(1)
	write(slot1,primary)
	print("SAVE_TEST: recovery checks finished")
	var invalid_record: Dictionary=JSON.parse_string(primary)
	invalid_record["version"]=999
	write(game.save_store.slot_path(5),JSON.stringify(invalid_record))
	check(not game.load_game_slot(5)["ok"],"unsupported save version rejected")
	invalid_record["version"]=1;invalid_record["sha256"]="wrong"
	write(game.save_store.slot_path(5),JSON.stringify(invalid_record))
	check(not game.load_game_slot(5)["ok"],"checksum tamper rejected")
	check(not game.load_game_slot(99)["ok"],"out-of-range slot rejected")
	game.toggle_menu();game.menu_view.select_tab("settings")
	await frames()
	print("SAVE_TEST: settings button ",game.menu_view.actions["preferences"].get_global_rect())
	await click(game.menu_view.actions["preferences"])
	check(front.settings_open and game.player.frozen,"in-game settings accessible and frozen")
	var resolution: OptionButton=front.settings_controls["resolution"]
	resolution.select(3);resolution.item_selected.emit(3)
	front.settings_controls["master"].value=33
	front.settings_controls["music"].value=44
	front.settings_controls["sfx"].value=55
	front.settings_controls["vsync"].button_pressed=false
	var fps: OptionButton=front.settings_controls["fps"]
	fps.select(2);fps.item_selected.emit(2)
	await click(front.settings_controls["apply"])
	check(FileAccess.file_exists(game.preferences.path),"settings stored on disk")
	check(Engine.max_fps==120 and game.preferences.values["resolution"]==3,"resolution and fps applied")
	if DisplayServer.get_name()!="headless":check(DisplayServer.window_get_size()==Vector2i(1920,1080),"window resized to selected 1920x1080")
	for entry: Array in [["Master",33.0],["Music",44.0],["SFX",55.0]]:
		check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(entry[0]))),float(entry[1])/100),"volume bus applied "+entry[0])
	resolution.select(1);resolution.item_selected.emit(1)
	await click(front.settings_controls["apply"])
	check(game.preferences.values["resolution"]==1,"second resolution applies")
	await click(front.back_button);game.close_menu()
	var before: String=game.day_clock.display_text()
	await create_timer(.15).timeout
	check(game.day_clock.display_text()==before,"clock remains period-only without automatic ticking")
	game.return_to_title();await wait_transition()
	check(front.title_visible and front.cover.texture!=null and game.terrain.current_scene==null and game.player.frozen,"return cover unloads active world")
	await click(front.title_buttons["start"]);await wait_transition()
	check(game.event_state.is_empty() and game.day_clock.display_text()=="上午","new game resets state without deleting manual saves")
	check(game.save_store.read_slot(3)["ok"],"manual save survives new game")
	finish()
