extends SceneTree

const Clock=preload("res://day_clock.gd")
var game: Node2D
var checks:=0
var failures: Array[String]=[]
var samples: Array[Dictionary]=[]
var directory: String

func _initialize() -> void:call_deferred("run")
func check(value: bool, message: String) -> void:
	checks+=1
	if not value:failures.append(message);push_error(message)
func frames() -> void:
	await process_frame
	await process_frame
func wait_transition() -> void:
	while game.transition_busy:await process_frame
	await physics_frame
func click_fast() -> void:
	var at: Vector2=game.time_skip_button.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new()
	motion.position=at;motion.global_position=at
	root.push_input(motion,true)
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.position=at;event.global_position=at;event.pressed=true
	root.push_input(event,true)
	event=event.duplicate();event.pressed=false
	root.push_input(event,true)
func image_now() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	var picture: Image=await image_now()
	picture.save_png(directory.path_join(name+".png"))
func wait_cooldown() -> void:
	while game.time_skip_cooldown()>0:await process_frame
	await frames()
func skip_and_check() -> void:
	await wait_cooldown()
	var expected: int=game.day_clock.next_index()
	var original: int=game.terrain.current_scene.get_instance_id()
	var count: int=game.terrain.transition_count
	var position: Vector2=game.player.position
	var route: PackedVector2Array=game.player.path.duplicate()
	var initial:=Time.get_ticks_msec()
	await click_fast()
	check(game.time_skip_busy and game.transition_busy and game.player.frozen,"actual fast-forward click starts exclusive fade")
	var peak:=0.0
	var captured:=false
	while game.time_skip_busy:
		await process_frame
		peak=maxf(peak,game.fade.modulate.a)
		if not captured and game.fade.modulate.a>=.999:
			captured=true
			if DisplayServer.get_name()!="headless":
				var black: Image=await image_now()
				var centre:=black.get_pixel(640,400)
				check(centre.r+centre.g+centre.b<.01,"fast-forward actually renders black screen")
				black.save_png(directory.path_join("快进黑屏.png"))
	check(peak>=.999,"fade reaches full black")
	check(game.day_clock.period_index()==expected,"advances exactly one time range")
	check(game.player.position==position,"fast-forward preserves character position")
	check(game.player.path==route,"fast-forward preserves automatic navigation route")
	check(game.terrain.current_scene.get_instance_id()==original and game.terrain.transition_count==count,"time change retains current scene and HD cache")
	check(not game.transition_busy and not game.player.frozen and game.fade.modulate.a<.001,"fade reveals and restores movement")
	var period: int=game.day_clock.period_index()
	check(game.time_skip_button.disabled and game.time_skip_cooldown()>1,"cooldown still active after fade")
	check(game.time_skip_button.text=="冷却中","cooldown has no ticking seconds display")
	game.fast_forward_time()
	check(not game.time_skip_busy and game.day_clock.period_index()==period,"immediate repeated skip rejected")
	while Time.get_ticks_msec()-initial<1900:await process_frame
	game.fast_forward_time()
	check(not game.time_skip_busy,"skip rejected before real two seconds")
	await wait_cooldown()
	check(not game.time_skip_button.disabled,"button re-enabled after cooldown")
	samples.append({"period":Clock.PERIODS[period]["name"],"tint":str(game.terrain.modulate),"cooldown_ms":Time.get_ticks_msec()-initial,"peak_black":peak})
	await shot(str(Clock.PERIODS[period]["name"])+("_内景" if not game.interior_state.is_empty() else "_外景"))
func run() -> void:
	var clock:=Clock.new()
	check(clock.period_index()==1 and clock.display_text()=="上午","initial state is morning only")
	for index: int in range(6):
		clock.current_period=index
		check(clock.display_text()==Clock.PERIODS[index]["name"],"time display consists only of range name")
		clock.next_period()
		check(clock.period_index()==[1,5,3,4,0,2][index],"explicit next period wraps through all six ranges")
	check(not clock.has_method("advance"),"no elapsed-time advancement API remains")
	game=(load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await frames()
	game.start_new_game();await wait_transition()
	game.story_system.stage=6;game.story_system.reward_given=true
	directory=game.package_root.path_join("runtime/时间与昼夜预览")
	DirAccess.make_dir_recursive_absolute(directory)
	game.player.camera.position_smoothing_enabled=false
	game.player.set_physics_process(false)
	game.player.position=game.Space.project(Vector2(527,1120))
	game.load_district(16)
	game.player.camera.reset_smoothing()
	await frames()
	await game.terrain.current_scene.hd_layer.wait_for_view()
	check(game.time_label.text=="上午","HUD has period only, no day/hour/minute display")
	check(game.time_skip_button.get_global_rect().has_area(),"fast button has a visible clickable area")
	if DisplayServer.get_name()!="headless":
		game.player.path.clear()
		await frames()
		var before: Image=await image_now()
		game.player.path=PackedVector2Array([game.player.position+Vector2(-70,45),game.player.position+Vector2(110,85)])
		game.queue_redraw()
		await frames()
		var after: Image=await image_now()
		check(before.get_region(Rect2i(380,150,880,500)).get_data()==after.get_region(Rect2i(380,150,880,500)).get_data(),"route remains invisible in actual rendered scene")
		game.player.path.clear()
		await shot("上午_外景")
	var period: int=game.day_clock.period_index()
	await create_timer(.25).timeout
	check(game.day_clock.period_index()==period,"ordinary elapsed play does not advance time")
	# Simulate lengthy frame updates directly; no real wait or auto clock.
	game._process(86400)
	check(game.day_clock.period_index()==period,"even a simulated full day cannot advance time")
	game.toggle_pause()
	await create_timer(.12).timeout
	check(game.day_clock.period_index()==period,"pause leaves time unchanged")
	game.fast_forward_time()
	check(not game.time_skip_busy,"cannot skip while paused")
	game.toggle_pause();game.toggle_menu()
	await create_timer(.12).timeout
	check(game.day_clock.period_index()==period,"menu leaves time unchanged")
	game.close_menu();game.toggle_map()
	await create_timer(.12).timeout
	check(game.day_clock.period_index()==period,"whole map leaves time unchanged")
	game.toggle_map()
	var initial_period: int=game.day_clock.period_index()
	game.player.path=PackedVector2Array([game.player.position+Vector2(96,0)])
	for i: int in range(6):await skip_and_check()
	game.player.path.clear()
	check(game.day_clock.period_index()==initial_period,"six explicit skips complete the period cycle")
	game.day_clock.current_period=4;game.apply_time_lighting()
	game.change_interior({"kind":"classroom","building":"B12","floor":3,"room":0})
	await wait_transition()
	check(game.terrain.modulate==game.day_clock.tint(true),"night classroom uses indoor lighting")
	check(game.terrain.modulate.r>game.day_clock.tint(false).r,"indoor lighting keeps furniture readable at night")
	check(game.player.modulate==game.terrain.modulate,"hero lighting matches scene")
	check(game.time_label.get_parent().modulate==Color.WHITE and game.time_skip_button.modulate==Color.WHITE,"HUD is not darkened")
	await shot("深夜_十班")
	await skip_and_check()
	check(not game.interior_state.is_empty() and game.time_label.text.contains("凌晨"),"fast-forward also works indoors")
	# Events use the same fade and update lighting but do not consume the
	# player's manual fast-forward cooldown or automatically fire on movement.
	period=game.day_clock.period_index()
	check(game.advance_time_from_event(),"explicit gameplay event accepted")
	check(not game.advance_time_from_event(),"overlapping event rejected during transition")
	await wait_transition()
	check(game.day_clock.period_index()==[1,5,3,4,0,2][period],"explicit event advances exactly one period")
	check(game.time_label.text=="上午" and game.terrain.modulate==game.day_clock.tint(true),"event updates period label and indoor lighting")
	check(game.time_skip_cooldown()==0,"event does not start manual button cooldown")
	game.toggle_menu()
	check(game.advance_time_from_event(),"event can explicitly advance while a menu is present")
	await wait_transition()
	check(game.menu_view.visible and game.player.frozen,"event restores existing menu freeze")
	game.close_menu()
	period=game.day_clock.period_index()
	game.teleport_outdoor(game.spawn)
	await wait_transition()
	check(game.day_clock.period_index()==period,"changing scenes never advances time automatically")
	check(game.terrain.modulate==game.day_clock.tint(false),"district changes preserve correct outdoor lighting")
	check(game.terrain.get_child_count()==1,"one active scene retained")
	var report: Dictionary={"checks":checks,"passed":failures.is_empty(),"failures":failures,"ranges":[],"cooldown_seconds":2,"automatic_progression":false,"display_period_only":true,"event_advancement":true,"samples":samples,"path_line_hidden":true,"ui_lighting_independent":true}
	for entry: Dictionary in Clock.PERIODS:report["ranges"].append({"name":entry["name"]})
	var file:=FileAccess.open(game.package_root.path_join("时间昼夜验证报告.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("TIME_CHECK ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
