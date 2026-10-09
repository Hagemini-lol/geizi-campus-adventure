extends SceneTree

var game: Node2D
var checks:=0
var failures: Array[String]=[]
var durations: Array[float]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func frames() -> void:await process_frame;await process_frame
func transition() -> void:
	var deadline:=Time.get_ticks_msec()+20000
	while game.transition_busy and Time.get_ticks_msec()<deadline:await process_frame
	check(not game.transition_busy,"transition completes");await physics_frame;await frames()
func press(key: Key) -> void:
	var event:=InputEventKey.new();event.keycode=key;event.physical_keycode=key;event.pressed=true
	root.push_input(event,true);await frames();event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()
func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	var folder: String=game.package_root.path_join("runtime/上课与体育场预览");DirAccess.make_dir_recursive_absolute(folder)
	root.get_texture().get_image().save_png(folder.path_join(name+".png"))
func lesson_item() -> Dictionary:
	for item: Dictionary in game.interactions():
		if item["action"]=="lesson":return item
	return {}
func seat_check(period: int) -> void:
	var scene: Node2D=game.terrain.current_scene
	var npcs: Node2D=scene.npcs
	var has_teacher: bool=true
	check(npcs.lesson_active and npcs.records.size()==31+int(has_teacher),"31 seated students and only the scheduled teacher")
	check(npcs.movers.is_empty() and npcs.get_child_count()==0 and not npcs.is_processing(),"seated NPCs are baked without sprite/AI nodes")
	var seats: Dictionary={};var named:=0;var ordinary:=0;var teacher:=0
	for record: Dictionary in npcs.records:
		if record.get("teacher",false):
			teacher+=1;check(record["role"]==game.campus_life.teacher_for(scene.state["building"],period),"teacher follows morning/afternoon")
			check(scene.navigation.walkable(record["at"]),"teacher beside lectern is reachable")
		else:
			check(record.get("seated",false),"all students seated")
			var seat: int=record["seat_index"];check(not seats.has(seat) and seat!=16,"unique seat and hero seat empty");seats[seat]=true
			check(Vector2(record["at"]).is_equal_approx(scene.seat_position(seat)),"student artwork follows actual furniture positions")
			if record["character"] in game.npc_catalog.NAMED_IDS:named+=1
			else:ordinary+=1
		var route: PackedVector2Array=npcs.approach(record["uid"],scene.landing("front"))
		check(not route.is_empty() and route[-1].distance_to(record["at"])<=12.01,"every seated NPC has a reachable small interaction ring")
	var scheduled: int=game.campaign.classmates_for(scene.state).size()
	check(named==scheduled and ordinary==31-scheduled and teacher==int(has_teacher),"unique named classmates and scheduled teacher, others fill empty seats")
	check(seats.size()==31 and scene.HERO_SEAT_INDEX==16 and scene.hero_seat==scene.seat_position(16),"window-side second-last seat is reserved")
	check(not lesson_item().is_empty() and game.lesson_view.available(),"white circle interaction available in teaching periods")
func far_guard(item: Dictionary) -> void:
	game.player.position=item["at"]+Vector2(0,13);game.interaction_delay=999
	await frames();game.execute_interaction(item);await frames()
	check(not game.dialogue_view.visible and not game.battle_view.visible and not game.map_view.visible and not game.lesson_view.visible and not game.transition_busy,"action blocked outside one interaction ring: "+item["action"])
func class_once() -> void:
	var item:=lesson_item();var before: int=game.day_clock.current_period
	game.player.position=game.terrain.current_scene.landing("front")
	var route: PackedVector2Array=game.approach_interaction(item["at"])
	check(not route.is_empty(),"class seat has a route from the entrance")
	if not route.is_empty():game.player.position=route[-1]
	game.interaction_delay=0;await frames()
	check(game.nearby.get("action")=="lesson" and game.interaction_label.text.contains("上课"),"E prompt at own seat")
	await press(KEY_E);check(game.lesson_view.visible and game.player.frozen,"E opens class confirmation")
	await shot("上课确认")
	game.fast_forward_time();game.toggle_menu();check(game.day_clock.current_period==before and not game.menu_view.visible,"confirmation blocks other time/menu actions")
	game.lesson_view.close();await frames();check(not game.player.frozen and game.day_clock.current_period==before,"cancel keeps period and releases player")
	game.interaction_delay=0;await press(KEY_E);game.lesson_view.confirm.pressed.emit()
	var deadline:=Time.get_ticks_msec()+10000
	while not game.lesson_view.black_text.visible and Time.get_ticks_msec()<deadline:await process_frame
	check(game.lesson_view.black_text.visible and game.fade.modulate.a>.999 and game.player.frozen,"lesson text shown only over full black")
	check(game.day_clock.current_period==before,"time unchanged at start of black text")
	await shot("黑屏上课"+str(before))
	await create_timer(1.75).timeout
	check(game.lesson_view.black_text.visible and game.day_clock.current_period==before,"black text remains for two seconds")
	check(not game.save_game_slot(5).get("ok",false),"cannot save an unfinished lesson")
	await transition();durations.append(game.lesson_view.held_seconds)
	check(game.lesson_view.held_seconds>=1.98 and game.day_clock.current_period==[1,5,3,4,0,2][before],"lesson holds 2 seconds and advances exactly one period")
	check(not game.player.frozen and not game.lesson_view.running and game.fade.modulate.a<.001,"fade ends and control restored")
func run() -> void:
	game=(load("res://main.tscn") as PackedScene).instantiate();root.add_child(game);await frames()
	game.start_new_game();await transition();game.player.set_physics_process(false)
	# Test routine classes after the new mandatory first chapter is complete.
	game.story_system.restore({"version":1,"stage":6,"reward_given":true,"leave_permission":false})
	check(game.INTERACTION_RADIUS==12,"interaction radius is 0.5 m")
	var door: Dictionary={};var board: Dictionary={}
	for item: Dictionary in game.interactions():
		if item.get("building")=="B12":
			if item["action"]=="entrance":door=item
			elif item["action"]=="board":board=item
	await far_guard(door);await far_guard(board)
	game.player.position=board["at"]+Vector2(0,9);game.execute_interaction(board);await frames()
	check(game.map_view.visible,"wall map still works in small ring");game.map_view.close_map()
	for building: String in ["B12","B05","B01"]:
		for period: int in [1,2,3]:
			game.day_clock.current_period=period;game.change_interior({"building":building,"floor":3,"kind":"classroom","room":0});await transition()
			if period in [1,2]:seat_check(period)
			else:
				var npcs: Node2D=game.terrain.current_scene.npcs
				check(npcs.records.size()==game.campaign.classmates_for(game.terrain.current_scene.state).size() and npcs.movers.size()==npcs.records.size() and not npcs.lesson_active,"outside teaching periods named movers only")
				check(lesson_item().is_empty(),"no lesson marker/action outside teaching periods")
	game.day_clock.current_period=1;game.change_interior({"building":"B12","floor":3,"kind":"classroom","room":0});await transition()
	await shot("上午十班")
	var npcs: Node2D=game.terrain.current_scene.npcs;var npc: Dictionary=npcs.interactions()[0]
	await far_guard(npc)
	var route: PackedVector2Array=npcs.approach(npc["uid"],game.terrain.current_scene.landing("front"))
	game.player.position=route[-1];game.execute_interaction(npc);await frames()
	check(game.dialogue_view.visible,"seated classmate greeting works close up");game.dialogue_view.close()
	await far_guard(lesson_item())
	# The radius guard deliberately teleports outside the ring, possibly onto a
	# chair; navigation must start from a reachable floor point.
	game.player.position=game.terrain.current_scene.landing("front")
	var seat_route: PackedVector2Array=game.approach_interaction(game.terrain.current_scene.hero_seat)
	check(not seat_route.is_empty() and seat_route[-1].distance_to(game.terrain.current_scene.hero_seat)<=12.01,"click navigation approaches hero circle without crossing furniture")
	await class_once();check(game.day_clock.current_period==5 and not game.lesson_view.available(),"morning class leads to lunch, not afternoon")
	game.advance_world_period();seat_check(2);await shot("下午十班")
	await class_once();check(game.terrain.current_scene.npcs.movers.size()==game.campaign.classmates_for(game.terrain.current_scene.state).size(),"afternoon class restores evening movers")
	check(int(game.event_state.get("classes_attended",0))==2,"completed lessons recorded as saveable events")
	game.day_clock.current_period=1;game.sync_classroom_period();game.apply_time_lighting()
	game.player.position=game.terrain.current_scene.landing("front");game.time_skip_ready_at_ms=0
	game.fast_forward_time();await transition();check(game.day_clock.current_period==5,"manual skip also enters lunch")
	game.advance_world_period();seat_check(2)
	var saved: Dictionary=game.save_game_slot(5);check(saved.get("ok",false),"period and completed lesson count save successfully")
	game.day_clock.current_period=3;game.sync_classroom_period();check(game.terrain.current_scene.npcs.movers.size()==game.campaign.classmates_for(game.terrain.current_scene.state).size(),"save/load test switches out of class")
	game.load_game_slot(5);await transition();seat_check(2)
	check(int(game.event_state.get("classes_attended",0))==2,"restored save retains lesson count")
	for building: String in ["B12","B05","B01"]:
		game.change_interior({"building":building,"floor":3,"kind":"corridor"});await transition()
		check(game.terrain.current_scene.npcs.records.size()==4 and not game.lesson_view.available(),"corridor NPC configuration unchanged")
		var rooms: Array=game.interior_info["buildings"][building]["floors"][2]["rooms"]
		for room: Dictionary in rooms:
			if not room.get("office",false):continue
			game.change_interior({"building":building,"floor":3,"kind":"classroom","room":room["index"]});await transition()
			check(game.terrain.current_scene.npcs.records.is_empty() and not game.lesson_view.available(),"teachers are at their scheduled offices, without duplicates in every classroom office");break
	for kind: String in ["corridor","classroom"]:
		game.change_interior({"building":"B02","floor":3,"kind":kind,"room":0});await transition()
		check(game.terrain.current_scene.npcs==null and not game.lesson_view.available() and lesson_item().is_empty(),"laboratory remains NPC-free")
		var manager: Node2D=game.active_monsters()
		if manager!=null and not manager.interactions().is_empty():await far_guard(manager.interactions()[0])
	game.day_clock.current_period=1
	game.teleport_outdoor(Vector2(93,170)*24);await transition()
	game.player.camera.zoom=Vector2.ONE*1.5;game.player.camera.reset_smoothing()
	await game.terrain.current_scene.hd_layer.wait_for_view();await shot("体育场中圈")
	for sample: Dictionary in [{"name":"北侧球门","at":Vector2(93,76),"zoom":2.4},{"name":"南侧球门","at":Vector2(93,264),"zoom":2.4},{"name":"主席台与跑道","at":Vector2(20,167),"zoom":1.5}]:
		game.teleport_outdoor(sample["at"]*24);await transition()
		game.player.camera.zoom=Vector2.ONE*sample["zoom"];game.player.camera.reset_smoothing();await frames()
		await game.terrain.current_scene.hd_layer.wait_for_view();await shot(sample["name"])
	check(game.terrain.get_child_count()==1,"one loaded scene retained")
	var report: Dictionary={"checks":checks,"failures":failures,"passed":failures.is_empty(),"lesson_hold_seconds":durations,"interaction_radius_m":.5,"hero_seat":16,"class_students":31,"class_teacher":1,"ordinary_students_per_ten_class":21,"zip_edited":false}
	var file:=FileAccess.open(game.package_root.path_join("runtime/lesson_checks.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("LESSON_CHECK ",checks," FAILURES ",failures.size());game.queue_free();await frames();quit(0 if failures.is_empty() else 1)
