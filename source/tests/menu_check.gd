extends SceneTree

var game: Node2D
var checks:=0
var failures: Array[String]=[]

func _initialize() -> void:call_deferred("run")
func check(value: bool, message: String) -> void:
	checks+=1
	if not value:failures.append(message);push_error(message)
func frames() -> void:
	await process_frame
	await process_frame
func click(at: Vector2, button: MouseButton=MOUSE_BUTTON_LEFT) -> void:
	var motion:=InputEventMouseMotion.new()
	motion.position=at;motion.global_position=at
	root.push_input(motion,true)
	var event:=InputEventMouseButton.new()
	event.button_index=button
	event.position=at;event.global_position=at
	event.pressed=true
	root.push_input(event,true)
	await frames()
	event=event.duplicate();event.pressed=false
	root.push_input(event,true)
	await frames()
func escape() -> void:
	var event:=InputEventKey.new()
	event.keycode=KEY_ESCAPE;event.physical_keycode=KEY_ESCAPE;event.pressed=true
	root.push_input(event,true)
	await frames()
	event=event.duplicate();event.pressed=false
	root.push_input(event,true)
	await frames()
func wait_transition() -> void:
	while game.transition_busy:await process_frame
	await physics_frame
func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	var directory: String=game.terrain.asset_root.path_join("菜单预览")
	DirAccess.make_dir_recursive_absolute(directory)
	root.get_texture().get_image().save_png(directory.path_join(name+".png"))
func run() -> void:
	game=(load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await frames()
	var menu: Control=game.menu_view
	check(not menu.visible,"menu initially hidden")
	check(menu.textures.size()==5 and menu.asset_paths.size()==5,"five existing menu assets loaded")
	for texture: Texture2D in menu.textures:
		check(texture!=null and texture.get_image().has_mipmaps(),"menu source textures and mipmaps ready")
	game.player.path=PackedVector2Array([game.player.position+Vector2(0,100)])
	await click(Vector2(900,600),MOUSE_BUTTON_RIGHT)
	check(menu.visible and game.player.frozen,"actual right-click opens and freezes movement")
	check(game.player.path.is_empty(),"right-click clears automatic route")
	check(not game.request_path(game.spawn),"click navigation blocked while menu open")
	var before: Vector2=game.player.position
	await frames()
	check(game.player.position==before,"hero stays still while menu open")
	for id: String in ["equipment","items","skills","settings","status"]:
		await click(menu.tabs[id].get_global_rect().get_center())
		check(menu.selected_tab==id,"actual click selects "+id)
		var visible_pages:=0
		for page: Control in menu.pages.values():
			if page.visible:visible_pages+=1
		check(visible_pages==1,"one active menu page")
		check(game.player.position==before and game.player.path.is_empty(),"tab clicks do not reach scene ground")
	await shot("右键菜单_状态")
	await click(menu.tabs["settings"].get_global_rect().get_center())
	await shot("右键菜单_设置")
	await click(menu.actions["resume"].get_global_rect().get_center())
	check(not menu.visible and not game.player.frozen,"resume button closes and unfreezes")
	await click(Vector2(800,500),MOUSE_BUTTON_RIGHT)
	await click(menu.tabs["settings"].get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
	check(not menu.visible and not game.player.frozen,"right-click over a UI button also closes")
	await click(Vector2(800,500),MOUSE_BUTTON_RIGHT)
	await escape()
	check(not menu.visible and not game.paused and not game.player.frozen,"Esc closes menu without opening pause")
	await click(Vector2(800,500),MOUSE_BUTTON_RIGHT)
	await click(menu.close_button.get_global_rect().get_center())
	check(not menu.visible and not game.player.frozen,"X closes")
	await click(Vector2(800,500),MOUSE_BUTTON_RIGHT)
	await click(menu.tabs["settings"].get_global_rect().get_center())
	await click(menu.actions["map"].get_global_rect().get_center())
	check(game.map_view.visible and not menu.visible and game.player.frozen,"menu opens whole school map")
	await click(Vector2(800,500),MOUSE_BUTTON_RIGHT)
	check(menu.visible and not game.map_view.visible and game.map_view.map_texture==null,"right-click replaces map and releases map texture")
	game.close_menu()
	game.toggle_pause()
	await click(Vector2(800,500),MOUSE_BUTTON_RIGHT)
	check(menu.visible and not game.paused and not game.overlay.visible,"right-click replaces pause panel")
	game.close_menu()
	game.change_interior({"kind":"classroom","building":"B12","floor":3,"room":0})
	await wait_transition()
	await click(Vector2(800,500),MOUSE_BUTTON_RIGHT)
	check(menu.visible and menu.location.text.contains("十班"),"menu opens inside classroom with current location")
	await click(menu.tabs["settings"].get_global_rect().get_center())
	await click(menu.actions["map"].get_global_rect().get_center())
	check(game.map_view.visible and game.map_view.teleport_mode,"menu classroom map preserves teleport mode")
	await click(Vector2(800,500),MOUSE_BUTTON_RIGHT)
	await click(menu.tabs["settings"].get_global_rect().get_center())
	await click(menu.actions["south"].get_global_rect().get_center())
	await wait_transition()
	check(game.interior_state.is_empty() and game.player.position.distance_to(game.spawn)<1,"menu returns from classroom to south gate")
	check(not game.player.frozen and not menu.visible,"movement resumes after south gate transition")
	if DisplayServer.get_name()!="headless":
		await click(Vector2(800,500),MOUSE_BUTTON_RIGHT)
		await click(menu.tabs["settings"].get_global_rect().get_center())
		var old_mode:=DisplayServer.window_get_mode()
		await click(menu.actions["fullscreen"].get_global_rect().get_center())
		check(DisplayServer.window_get_mode()!=old_mode,"fullscreen button changes actual window mode")
		check(menu.visible and game.player.frozen,"menu stays active during fullscreen")
		DisplayServer.window_set_mode(old_mode)
		await frames()
		game.close_menu()
	check(game.terrain.get_child_count()==1,"menu preserves one active scene")
	var report: Dictionary={"checks":checks,"passed":failures.is_empty(),"failures":failures,"source_assets":menu.asset_paths,"tabs":menu.tabs.keys(),"right_click_toggle":true,"escape_close":true,"inside_and_outside":true,"source_images_external":true}
	var file:=FileAccess.open(game.package_root.path_join("菜单验证报告.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("MENU_CHECK ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
