extends SceneTree
var game: Node2D
var checks:=0
var failures: Array[String]=[]
var started:=0
var auto_dialogue:=false
var saw_flash:=false
var output:="D:/Godot/校园自由漫游/runtime"
var report_name:="mobile_ui_fix_checks"
func _initialize() -> void:
	started=Time.get_ticks_msec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report-root="):output=arg.trim_prefix("--report-root=")
		if arg.begins_with("--report-name="):report_name=arg.trim_prefix("--report-name=")
	call_deferred("run")
func _process(_delta: float) -> bool:
	if Time.get_ticks_msec()-started>120000:push_error("MOBILE_UI_FIX_TIMEOUT");quit(1)
	if auto_dialogue and game!=null:
		if game.dialogue_view.visible:game.dialogue_view.accept()
		saw_flash=saw_flash or game.fade.modulate.a>0
	return false
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func frames(n: int=3) -> void:
	for i: int in range(n):await process_frame
func tap(at: Vector2) -> void:
	var event:=InputEventScreenTouch.new();event.position=at;event.index=0;event.pressed=true;root.push_input(event,true);await frames(2)
	event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames(3)
func press_text(owner: Node, text: String) -> void:
	var found: Button=null
	for button: Button in owner.find_children("*","Button",true,false):
		if button.text==text and button.is_visible_in_tree():found=button;break
	check(found!=null,"touch target exists: "+text)
	if found!=null:
		var parent: Node=found.get_parent()
		while parent!=null and not parent is ScrollContainer:parent=parent.get_parent()
		if parent is ScrollContainer:parent.ensure_control_visible(found);await frames()
		await tap(found.get_global_rect().get_center())
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(report_name+"-"+name+".png"))
func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game);await frames(6)
	if "--wide-mobile" in OS.get_cmdline_user_args():DisplayServer.window_set_size(Vector2i(1600,900));await frames(8)
	check(game.load_error.is_empty(),"game starts with bundled font")
	check(game.ui_font is FontFile and not game.ui_font.allow_system_fallback,"shared embedded font without OEM fallback")
	for c: String in "!！?？。，：；…—◇×·−+0123456789老美子勾尬":check(game.ui_font.has_char(c.unicode_at(0)),"font glyph "+c)
	var front: Control=game.front_end
	await tap(front.title_buttons["settings"].get_global_rect().get_center())
	check(front.settings_open and front.mobile_settings!=null,"touch opens dedicated mobile settings")
	check(front.find_children("*","OptionButton",true,false).is_empty(),"no native option popups in mobile settings")
	check(not front.settings_controls.has("resolution") and not front.settings_controls.has("fullscreen"),"desktop window switches excluded")
	check(not game.mobile_controls.visible,"world controls disabled on settings")
	var scale_before: float=front.draft["control_scale"]
	await tap(front.settings_controls["control_scale"]["plus"].get_global_rect().get_center())
	check(is_equal_approx(float(front.draft["control_scale"]),scale_before+.05),"large touch stepper edits control size")
	await press_text(front,"性能与画面")
	await tap(front.settings_controls["mobile_fps"].get_global_rect().get_center())
	check(front.draft["mobile_fps"]==30,"mobile FPS switches with ordinary touch button")
	await tap(front.settings_controls["reduce_flash"].get_global_rect().get_center())
	check(front.draft["reduce_flash"],"flash reduction touch switch")
	await press_text(front,"声音")
	await tap(front.settings_controls["master"]["minus"].get_global_rect().get_center())
	check(front.draft["master"]==75,"sound touch stepper works")
	await press_text(front,"保存设置")
	check(Engine.max_fps==30 and game.preferences.values["master"]==75,"mobile settings applied and saved")
	var parsed: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(game.preferences.path))
	check(parsed["control_scale"]==front.draft["control_scale"] and parsed["mobile_fps"]==30,"new fields persist with old settings")
	await shot("settings")
	await press_text(front,"返回游戏")
	await tap(front.title_buttons["settings"].get_global_rect().get_center());await press_text(front,"声音")
	await tap(front.settings_controls["master"]["minus"].get_global_rect().get_center());await press_text(front,"返回游戏")
	check(game.preferences.values["master"]==75 and is_equal_approx(AudioServer.get_bus_volume_db(0),linear_to_db(.75)),"cancel restores saved sound without writing draft")
	await tap(front.title_buttons["start"].get_global_rect().get_center())
	while game.transition_busy:await process_frame
	game.story_system.stage=6;game.story_system.reward_given=true;game.campaign.index=31
	await frames(8)
	var controls: Control=game.mobile_controls
	check(controls.visible and controls.stick_rect.size.x>=250 and controls.x_rect.size.x>=128,"joystick and right buttons enlarged by default")
	var rects: Array[Rect2]=[controls.stick_rect,controls.x_rect,controls.y_rect,controls.run_rect]
	for i: int in range(rects.size()):
		check(Rect2(Vector2.ZERO,controls.size).encloses(rects[i]),"control inside viewport "+str(i))
		for j: int in range(i+1,rects.size()):check(not rects[i].intersects(rects[j]),"touch areas do not overlap %d/%d" % [i,j])
	controls.update_stick(controls.stick_rect.get_center()+Vector2(controls.stick_rect.size.x*.35,0));check(is_equal_approx(controls.direction.x,1),"stick travel follows resized radius");controls.reset_stick()
	await shot("controls")
	await tap(game.phone.launcher.get_global_rect().get_center());await frames(20)
	var phone: Control=game.phone
	check(phone.visible and not controls.visible and not controls.movement_available,"phone keeps world controls hidden over many frames")
	check(controls.button_at(controls.x_rect.get_center()).is_empty() and controls.button_at(controls.y_rect.get_center()).is_empty(),"modal blocks synchronous world hit tests")
	var position: Vector2=game.player.position
	await tap(controls.x_rect.get_center());await frames()
	check(game.player.position==position and game.player.path.is_empty(),"phone touch cannot move hero through hidden controls")
	phone.home();await frames();await tap(phone.body.get_child(4).get_global_rect().get_center())
	check(phone.page=="warning","forbidden warning receives touch")
	# Low FPS reproduces both old finale tweens finishing in one frame.
	Engine.max_fps=8;auto_dialogue=true
	await tap(phone.body.get_child(1).get_global_rect().get_center())
	while phone.initiating:await process_frame
	auto_dialogue=false;Engine.max_fps=60;await frames(8)
	check(phone.visible and phone.page=="editor" and game.world_editor.unlocked,"8 FPS first-use animation reaches modifier without lost signal")
	check(saw_flash and game.fade.modulate.a==0 and game.player.camera.offset==Vector2.ZERO,"reduced flash completes and restores camera")
	check(not controls.visible and game.player.frozen,"world controls remain disabled after animation")
	await tap(phone.body.get_child(2).get_global_rect().get_center())
	check(phone.page=="editor/money","secondary editor receives real touch after animation")
	await tap(phone.inputs.values()[0]["button"].get_global_rect().get_center())
	check(phone.page=="keypad" and phone.find_children("*","SpinBox",true,false).is_empty(),"mobile editor uses game keypad without native keyboard")
	for digit: String in ["5","4","3","2","1"]:await press_text(phone,digit)
	await shot("keypad");await press_text(phone,"确认修改")
	check(game.economy.money==54321 and phone.page=="editor/money","keypad touch changes money and returns to category")
	phone.editor("affinity");await frames();await tap(phone.inputs.values()[0]["button"].get_global_rect().get_center())
	phone.keypad_press("9");phone.keypad_press("9");phone.keypad_press("9");phone.keypad_press("−");phone.commit_number()
	check(game.relationships.bond(game.relationships.COMPANIONS[0])==-100,"signed affinity input respects caps")
	phone.editor("item");await frames()
	check(phone.inputs.size()<=12,"mobile item page bounded to twelve controls")
	await press_text(phone,"下一页");check(phone.editor_offset==12,"mobile material pages remain navigable")
	phone.close();await frames();check(controls.visible and not game.player.frozen,"closing phone restores movement")
	phone.open();phone.forbidden();await frames();check(phone.page=="editor" and not phone.initiating,"later forbidden opening skips animation")
	phone.close();game.toggle_menu();await frames()
	check(not controls.visible and controls.button_at(controls.y_rect.get_center()).is_empty(),"world menu button cannot cover game menu options")
	front.open_settings();await frames()
	check(front.settings_open and not controls.visible,"in-game settings blocks controls too")
	await press_text(front,"触屏引导");await shot("guide")
	check(front.mobile_settings.body.get_child_count()>=6,"mobile guidance explains touch and time")
	front.close_modal();game.close_menu();await frames()
	var report:=FileAccess.open(output.path_join(report_name+".json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"device":"desktop engine touch events; physical Android not tested"},"  "))
	print("MOBILE_UI_FIX_CHECKS ",checks," FAILURES ",failures.size());game.queue_free();game=null;await frames();quit(0 if failures.is_empty() else 1)
