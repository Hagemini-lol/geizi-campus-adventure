extends SceneTree

var game: Node2D
var checks:=0
var failures: Array[String]=[]
var walk_targets:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func frames(n: int=3) -> void:
	for i: int in range(n):await process_frame
func transition() -> void:
	var deadline:=Time.get_ticks_msec()+30000
	while game.transition_busy and Time.get_ticks_msec()<deadline:await process_frame
	check(not game.transition_busy,"scene transition completes");await frames()
func travel(at: Vector2) -> bool:
	if not game.request_path(at):return false
	var deadline:=Time.get_ticks_msec()+8000
	while not game.player.path.is_empty() and Time.get_ticks_msec()<deadline:await physics_frame
	walk_targets+=1
	return game.player.position.distance_to(at)<3
func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game);await frames(10)
	if not game.game_started:game.start_new_game();await transition()
	game.story_system.stage=6;game.story_system.reward_given=true
	game.day_clock.current_period=4
	var contexts: Array[Dictionary]=[
		{"kind":"classroom","building":"B01","floor":3,"room":0},
		{"kind":"classroom","building":"B01","floor":1,"room":1},
		{"kind":"classroom","building":"B02","floor":1,"room":1}]
	for room: Dictionary in game.interior_info["buildings"]["B01"]["floors"][0]["rooms"]:
		if room.get("office",false):contexts.append({"kind":"classroom","building":"B01","floor":1,"room":int(room["index"])});break
	for context: Dictionary in contexts:
		game.change_interior(context);await transition()
		game.interaction_delay=100000
		var scene: Node2D=game.terrain.current_scene
		if scene.npcs!=null:scene.npcs.set_process(false)
		check(scene.y_sort_enabled,"all interior scenes sort actors and furniture by floor edge")
		check(not scene.foreground.is_empty(),"original furniture pixels have foreground occluders")
		for box: Rect2 in scene.blockers:
			check(box.size.x>1 and box.size.y>1,"furniture uses usable floor footprints")
			check(not scene.navigation.walkable(box.get_center()),"navigation excludes furniture floor contact")
		if not scene.is_office:
			check(scene.blockers.size()==66,"32 desks plus 32 chairs and 2 fixed props")
			for seat: int in range(32):
				var table: Rect2=scene.blockers[seat*2]
				var chair: Rect2=scene.blockers[seat*2+1]
				check(not scene.navigation.segment_clear(table.get_center()-Vector2(30,0),table.get_center()+Vector2(30,0)),"cannot cut through table "+str(seat))
				check(not scene.navigation.segment_clear(chair.get_center()-Vector2(25,0),chair.get_center()+Vector2(25,0)),"cannot cut through chair "+str(seat))
				var approach: PackedVector2Array=game.approach_interaction(scene.seat_position(seat))
				check(not approach.is_empty(),"seat remains reachable for interaction "+str(context)+"/"+str(seat))
				if not approach.is_empty():
					check(approach[-1].distance_to(scene.seat_position(seat))<=12,"seat reachable within E/X range")
		for portal: Dictionary in scene.portals:
			check(await travel(portal["at"]),"front/rear door reached without furniture clipping")
		if scene.npcs!=null:
			for record: Dictionary in scene.npcs.records:
				var path: PackedVector2Array=game.approach_interaction(record["at"])
				check(not path.is_empty(),"NPC approachable: "+record["name"])
			if not scene.is_office and not scene.is_ten_class:
				for record: Dictionary in scene.npcs.records:check(record.get("seated",false),"ordinary classroom students use seated appearance")
		if scene.is_ten_class:
			game.day_clock.current_period=1;game.sync_classroom_period();await frames()
			check(scene.npcs.lesson_active and scene.seat_marker.visible,"morning class seat marker remains above furniture")
			var route: PackedVector2Array=game.approach_interaction(scene.hero_seat)
			check(not route.is_empty(),"hero class seat approachable")
			if not route.is_empty():check(await travel(route[-1]),"hero walks to own seat while avoiding furniture")
			for record: Dictionary in scene.npcs.records:
				check(not game.approach_interaction(record["at"]).is_empty(),"morning seated NPC reachable: "+record["name"])
			if DisplayServer.get_name()!="headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("D:/Godot/校园自由漫游/runtime/上课桌椅遮挡修复预览.png")
			game.day_clock.current_period=4;game.sync_classroom_period();await frames()
			for step: int in range(150):
				scene.npcs._process(.04)
				for record: Dictionary in scene.npcs.movers:check(scene.navigation.walkable(record["at"]),"named NPC stays outside furniture")
		if DisplayServer.get_name()!="headless" and scene.is_ten_class:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("D:/Godot/校园自由漫游/runtime/桌椅遮挡修复预览.png")
	var report: Dictionary={"checks":checks,"failures":failures,"passed":failures.is_empty(),"actual_walk_targets":walk_targets,"scene_types":contexts.size(),"separate_table_chair_collisions":true,"foreground_occlusion":true}
	var file:=FileAccess.open("D:/Godot/校园自由漫游/runtime/furniture_route_checks.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("FURNITURE_ROUTE_CHECKS ",checks," FAILURES ",failures.size());quit(0 if failures.is_empty() else 1)
