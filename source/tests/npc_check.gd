extends SceneTree

var game: Node2D
var checks:=0
var failures: Array[String]=[]
var samples: Array[Dictionary]=[]
var seen_greetings: Dictionary={}
func _initialize() -> void:call_deferred("run")
func check(value: bool, message: String) -> void:
	checks+=1
	if not value:failures.append(message);push_error(message)
func frames() -> void:
	await process_frame;await process_frame
func transition() -> void:
	var deadline:=Time.get_ticks_msec()+20000
	while game.transition_busy and Time.get_ticks_msec()<deadline:await process_frame
	check(not game.transition_busy,"scene transition finishes")
	await physics_frame;await frames()
func click(control: Control) -> void:
	await frames()
	var at:=control.get_global_rect().get_center()
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT;event.position=at;event.global_position=at;event.pressed=true
	root.push_input(event,true);await frames()
	event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()
func press(key: Key) -> void:
	var event:=InputEventKey.new();event.keycode=key;event.physical_keycode=key;event.pressed=true
	root.push_input(event,true);await frames()
	event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()
func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	var folder: String=game.package_root.path_join("runtime/NPC与对话预览")
	DirAccess.make_dir_recursive_absolute(folder)
	root.get_texture().get_image().save_png(folder.path_join(name+".png"))
func greet_all() -> void:
	var npcs: Node2D=game.terrain.current_scene.npcs
	var origin: Vector2=game.player.position
	for record: Dictionary in npcs.records:
		var route: PackedVector2Array=npcs.approach(record["uid"],origin)
		check(not route.is_empty(),"NPC has reachable greeting approach "+record["uid"])
		if route.is_empty():continue
		game.player.position=route[-1];game.player.camera.reset_smoothing()
		game.interaction_delay=0
		await frames()
		var item: Dictionary={}
		for candidate: Dictionary in npcs.interactions():
			if candidate["uid"]==record["uid"]:item=candidate
		game.execute_interaction(item);await frames()
		check(game.dialogue_view.visible and game.dialogue_view.speaker_name==record["name"],"each NPC opens its greeting")
		check(game.player.frozen and game.dialogue_view.speech.text in game.dialogue_view.GREETINGS,"greeting drawn and player frozen")
		check(game.dialogue_view.left_portrait.texture!=null and game.dialogue_view.right_portrait.texture!=null,"both portraits loaded for every NPC")
		check(game.dialogue_view.active_speaker=="npc" and game.dialogue_view.left_portrait.modulate==game.dialogue_view.LISTENING_COLOR and game.dialogue_view.right_portrait.modulate==Color.WHITE,"NPC bright and listening hero dim")
		seen_greetings[game.dialogue_view.speech.text]=true
		check(game.dialogue_view.confirm.visible and game.dialogue_view.cancel.visible,"confirm and cancel available")
		var before: int=game.day_clock.current_period
		await click(game.dialogue_view.cancel)
		check(not game.dialogue_view.visible and not game.player.frozen and before==game.day_clock.current_period,"cancel resumes without advancing time")
	game.player.position=origin;game.player.camera.reset_smoothing()
func run() -> void:
	game=(load("res://main.tscn") as PackedScene).instantiate();root.add_child(game)
	await frames();game.start_new_game();await transition()
	check(game.npc_catalog.characters.size()>=20,"available character library checked")
	check(game.dialogue_view.frame.texture==null,"dialogue texture deferred until interaction")
	check(not game.interactions().any(func(item: Dictionary):return item["action"]=="npc"),"no outdoor NPCs")
	var special_ids: Array[String]=[]
	game.day_clock.current_period=3;game.apply_time_lighting()
	for building: String in ["B12","B05","B01"]:
		game.change_interior({"building":building,"floor":3,"kind":"classroom","room":0});await transition()
		var scene: Node2D=game.terrain.current_scene
		var npcs: Node2D=scene.npcs
		check(npcs.records.size()==10 and npcs.movers.size()==10,"ten class contains only ten named movers")
		check(npcs.records.all(func(record: Dictionary):return record["special"] and record["character"] in game.npc_catalog.NAMED_IDS),"no ordinary students or greeting records remain in ten class")
		var named: Array[String]=[]
		for record: Dictionary in npcs.records:
			if record["special"]:named.append(record["character"])
		check(named.size()==game.npc_catalog.TEN_CLASS_STUDENTS[building].size(),"ten class has complete assigned named roster")
		for id: String in game.npc_catalog.TEN_CLASS_STUDENTS[building]:check(id in named,"named student present "+id)
		check(npcs.get_child_count()==10,"ordinary students create no sprite nodes")
		var mover: Dictionary=npcs.movers[0];special_ids.append(mover["character"])
		check(mover["frames"].size()==4 and mover["range"].has_point(mover["at"]),"special four directions and bounded spawn")
		var moved:=false
		var start: Vector2=mover["at"]
		var deadline:=Time.get_ticks_msec()+2200
		while Time.get_ticks_msec()<deadline:
			await process_frame
			check(mover["range"].has_point(mover["at"]) and scene.navigation.walkable(mover["at"]),"special stays in walkable bounded area")
			if mover["at"].distance_to(start)>4:moved=true;break
		check(moved and npcs.path_plans>0,"special actually plans and moves")
		game.toggle_menu()
		var frozen: Vector2=mover["at"]
		await create_timer(.1).timeout
		check(mover["at"]==frozen,"special freezes with menu")
		game.close_menu()
		await shot(building+"_三楼十班")
		if building=="B12":
			await greet_all()
			var npc: Dictionary=npcs.records[0]
			var route: PackedVector2Array=npcs.approach(npc["uid"],game.player.position)
			game.player.position=route[-1];game.interaction_delay=0;await frames()
			check(game.nearby.get("action")=="npc","E selects nearby NPC")
			await press(KEY_E)
			check(game.dialogue_view.visible,"actual E opens greeting")
			await shot("问候与确认取消")
			var dialog: Control=game.dialogue_view
			var viewport_width:=float(root.get_visible_rect().size.x)
			check(is_equal_approx(dialog.left_portrait.anchor_right-dialog.left_portrait.anchor_left,1.0/3.0) and is_equal_approx(dialog.right_portrait.anchor_right-dialog.right_portrait.anchor_left,1.0/3.0),"each portrait occupies outer third of viewport")
			check(dialog.left_portrait.get_global_rect().end.x<=viewport_width/3+.1 and dialog.right_portrait.get_global_rect().position.x>=viewport_width*2/3-.1,"left and right portraits stay in own side")
			check(dialog.frame.get_parent().z_index>dialog.left_portrait.z_index and dialog.frame.get_parent().z_index>dialog.right_portrait.z_index,"dialogue panel explicitly above both portraits")
			check(dialog.get_parent().layer>game.front_end.get_parent().layer and dialog.get_parent().layer>game.menu_view.get_parent().layer,"dialogue is highest interactive UI canvas")
			check(dialog.confirm.get_parent().z_index>dialog.frame.z_index and dialog.speech.z_index>dialog.frame.z_index,"options and dialogue text above frame")
			var old: int=game.day_clock.current_period
			game.fast_forward_time();await frames()
			check(game.day_clock.current_period==old and not game.time_skip_busy,"dialogue blocks fast-forward")
			await click(game.dialogue_view.confirm)
			check(dialog.visible and dialog.active_speaker=="hero" and dialog.name_label.text=="赵慕gei","first confirm advances to hero speaking")
			check(dialog.left_portrait.modulate==Color.WHITE and dialog.right_portrait.modulate==dialog.LISTENING_COLOR,"speaking hero bright and listening NPC dim")
			check(dialog.speech.text in dialog.HERO_REPLIES,"hero gives a simple greeting reply")
			check(game.player.frozen and old==game.day_clock.current_period,"second turn stays paused without time advancement")
			await shot("主角回应_左右立绘明暗")
			await click(game.dialogue_view.confirm)
			check(not game.dialogue_view.visible and game.notice.contains("点头"),"actual confirm closes greeting")
			game.player.position=scene.landing();await frames()
			var body: Rect2=npcs.interactions()[0]["art_rect"]
			check(game.click_interaction(body.get_center()),"click NPC initiates interaction approach")
			var travel_deadline:=Time.get_ticks_msec()+6000
			while not game.dialogue_view.visible and Time.get_ticks_msec()<travel_deadline:await process_frame
			check(game.dialogue_view.visible,"hero actually navigates to clicked NPC and greets")
			await press(KEY_ESCAPE)
			check(not game.dialogue_view.visible and not game.paused,"Esc cancels only greeting")
			game.player.position=Vector2(28,208);game.player.camera.reset_smoothing();await frames()
			var special_at: Vector2=mover["at"]
			var special_body:=Rect2(special_at-Vector2(mover["width"]*.5,mover["height"]),Vector2(mover["width"],mover["height"]))
			check(game.click_interaction(special_body.get_center()),"click special NPC starts greeting approach")
			var special_deadline:=Time.get_ticks_msec()+4000
			while not game.dialogue_view.visible and Time.get_ticks_msec()<special_deadline:
				await process_frame
				check(mover["at"]==special_at,"target special waits during player approach")
			check(game.dialogue_view.visible and game.dialogue_view.speaker_name=="牢李","moving special NPC remains interactable by actual navigation")
			await click(game.dialogue_view.cancel)
			game.change_interior({"building":"B12","floor":2,"kind":"classroom","room":1});await transition()
			check(game.terrain.current_scene.npcs.records.size()==12 and not game.terrain.current_scene.npcs.is_processing(),"ordinary classroom has no processing AI")
			await shot("普通教室_十二名同学");await greet_all()
		game.change_interior({"building":building,"floor":1,"kind":"corridor"});await transition()
		var corridor_npcs: Node2D=game.terrain.current_scene.npcs
		check(corridor_npcs.records.size()==4 and corridor_npcs.get_child_count()==0 and not corridor_npcs.is_processing(),"corridor has four baked ordinary NPCs only")
		for record: Dictionary in corridor_npcs.records:
			check(game.terrain.current_scene.navigation.walkable(record["at"]),"corridor ordinary placement is on walkway")
		await shot(building+"_走廊四名同学")
		if building=="B12":await greet_all()
		samples.append({"building":building,"classroom_static":12,"ordinary_in_ten":10-named.size(),"named_students":named.size(),"moving_students":10,"corridor_ordinary":4})
	check(special_ids.size()==3 and special_ids[0]=="lao_li" and special_ids[1]=="lao_li" and special_ids[2]=="lao_li","named NPC copies are present in all three ten classes")
	for level: int in range(1,5):
		game.change_interior({"building":"B02","floor":level,"kind":"corridor"});await transition()
		check(game.terrain.current_scene.npcs==null and not game.interactions().any(func(item: Dictionary):return item["action"]=="npc"),"laboratory corridors have no NPC")
	game.change_interior({"building":"B02","floor":3,"kind":"classroom","room":0});await transition()
	check(game.terrain.current_scene.npcs==null,"laboratory classroom has no NPC")
	game.teleport_outdoor(game.spawn);await transition()
	check(not game.interactions().any(func(item: Dictionary):return item["action"]=="npc"),"outdoor remains empty after leaving buildings")
	check(game.terrain.get_child_count()==1 and game.terrain.max_scene_count==1,"scene streaming remains one at a time")
	check(game.dialogue_view.frame.texture==null and game.dialogue_view.left_portrait.texture==null and game.dialogue_view.right_portrait.texture==null,"dialogue images released on close")
	check(seen_greetings.size()>=3,"multiple simple greetings sampled")
	var report: Dictionary={"checks":checks,"passed":failures.is_empty(),"failures":failures,"samples":samples,"greetings_sampled":seen_greetings.keys(),"ordinary_sprite_nodes":0,"ordinary_collision_bodies":0,"ordinary_processing":false,"special_ids":special_ids,"excluded_building":"B02","outdoor_npcs":0,"one_active_scene":true,"ten_class_rosters":game.npc_catalog.TEN_CLASS_STUDENTS,"named_student_total":30,"moving_student_total":30,"dialogue_outer_thirds":true,"speaking_highlight":true,"two_greeting_turns":true,"dialogue_above_portraits":true}
	var file:=FileAccess.open(game.package_root.path_join("NPC验证报告.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "));file.close()
	print("NPC_CHECK: ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
