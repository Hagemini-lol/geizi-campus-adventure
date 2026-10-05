extends SceneTree
var game: Node2D
var failures: Array[String]=[]
var checks: Array[String]=[]
var representatives: Dictionary={}

func _initialize() -> void:call_deferred("run")

func require(value: bool, name: String) -> void:
	checks.append(name)
	if not value:
		failures.append(name)
		push_error(name)

func key(code: int, pressed: bool) -> void:
	var event:=InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func travel(start: Vector2, codes: Array[int], frames: int) -> Vector2:
	game.load_district(game.navigation.region_at(start))
	game.player.position=start
	game.player.path.clear()
	game.player.frozen=false
	game.player.set_physics_process(false)
	for code: int in codes:key(code,true)
	for i: int in range(frames):
		await physics_frame
		game.player._physics_process(1.0/60.0)
	for code: int in codes:key(code,false)
	return game.player.position

func overlap(at: Vector2) -> bool:
	var shape:=CircleShape2D.new()
	shape.radius=game.player.RADIUS
	var query:=PhysicsShapeQueryParameters2D.new()
	query.shape=shape
	query.transform.origin=at
	query.exclude=[game.player.get_rid()]
	return not game.player.get_world_2d().direct_space_state.intersect_shape(query).is_empty()

func run() -> void:
	game=(load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	require(game.load_error.is_empty(),"external_hd_districts_load")
	if game.player==null or not game.load_error.is_empty():quit(1);return
	game.player.set_physics_process(false)
	require(game.model["regions"].size()==20,"twenty_building_administrative_regions")
	require(game.player.frames.size()==4,"hero_four_directions")
	require(is_equal_approx(game.player.walking_speed,100.8),"base_is_previous_running_speed")
	require(is_equal_approx(game.player.running_speed/game.player.walking_speed,2),"shift_multiplier_two")
	require(is_equal_approx(game.player.auto_speed/game.player.walking_speed,5),"click_multiplier_five")
	var turf: Vector2=game.Space.project(Vector2(245,500))
	var straight: Vector2=await travel(turf,[KEY_D],10)
	var running: Vector2=await travel(turf,[KEY_D,KEY_SHIFT],10)
	var diagonal: Vector2=await travel(turf,[KEY_D,KEY_S],10)
	require(absf(running.distance_to(turf)/straight.distance_to(turf)-2)<0.03,"physical_two_times_speed")
	require(absf(diagonal.distance_to(turf)-straight.distance_to(turf))<0.5,"normalized_diagonal_movement")
	game.player.position=turf
	game.player.path=PackedVector2Array([turf+Vector2(300,0)])
	for i: int in range(10):
		await physics_frame
		game.player._physics_process(1.0/60.0)
	require(absf(game.player.position.distance_to(turf)/straight.distance_to(turf)-5)<0.03,"physical_five_times_auto_speed")
	key(KEY_W,true)
	game.player._physics_process(1.0/60.0)
	key(KEY_W,false)
	require(game.player.path.is_empty(),"keyboard_cancels_auto_route")
	var roof: Vector2=await travel(game.Space.project(Vector2(197,185)),[KEY_W,KEY_SHIFT],45)
	require(game.Space.unproject(roof).y>=171.9,"building_collision_blocks_player")
	var total_texture_bytes:=0
	var max_texture_bytes:=0
	for index: int in range(20):
		require(game.load_district(index),"load_hd_region_"+str(game.model["regions"][index]["id"]))
		await process_frame
		await physics_frame
		require(game.terrain.get_child_count()==1,"exactly_one_loaded_region_"+str(index))
		total_texture_bytes+=game.terrain.active_texture_bytes
		max_texture_bytes=maxi(max_texture_bytes,game.terrain.active_texture_bytes)
		var found:=false
		for gate: Array in game.model["gates"]:
			if int(gate[0])!=index and int(gate[1])!=index:continue
			var near:=Vector2(gate[2],gate[3])*24
			for offset: Vector2 in [Vector2(-12,0),Vector2(12,0),Vector2(0,-12),Vector2(0,12)]:
				var at:=near+offset
				if game.navigation.region_at(at)!=index:continue
				var route: PackedVector2Array=game.navigation.route(game.spawn,at)
				if not route.is_empty():
					representatives[index]=at
					found=true
					for j: int in range(route.size()-1):
						var a: int=game.navigation.region_at(route[j])
						var b: int=game.navigation.region_at(route[j+1])
						if a!=b and not game.navigation.can_cross(a,b,route[j+1]):
							found=false
							break
				if found:break
			if found:break
		require(found,"road_route_reaches_"+str(game.model["regions"][index]["id"]))
	require(game.terrain.max_scene_count==1,"old_region_unloaded_before_next")
	require(max_texture_bytes<total_texture_bytes*0.15,"active_map_texture_memory_under_15_percent_of_all_maps")
	require(is_equal_approx(game.player.HEIGHT/24,1.7),"hero_height_1_70m")
	require(is_equal_approx(game.model["tree_diameter_meters"],3.5),"tree_canopy_diameter_3_5m")
	require(is_equal_approx(game.model["tree_trunk_diameter_meters"],.35),"tree_trunk_diameter_0_35m")
	var tree_checked:=false
	for tree: Array in game.model["trees"]:
		game.load_district(int(tree[2]))
		await physics_frame
		var at:=Vector2(tree[0],tree[1])*24
		if overlap(at) and not overlap(at+Vector2(24,0)):
			tree_checked=true
			break
	require(tree_checked,"tree_trunk_blocks_but_canopy_is_walkable")
	game.load_district(game.navigation.region_at(game.spawn))
	game.player.position=game.spawn
	game.player.path.clear()
	game.toggle_map()
	require(game.map_view.visible and game.player.frozen,"overview_pauses_movement")
	game.toggle_map()
	game.toggle_pause()
	require(game.paused and game.player.frozen,"pause_freezes_movement")
	game.toggle_pause()
	game.toggle_pause()
	game.overlay.get_child(0).get_child(2).pressed.emit()
	require(game.transition_busy and not game.paused and not game.overlay.visible,"pause_menu_return_to_gate_resumes_game")
	while game.transition_busy: await process_frame
	require(not game.player.frozen and game.player.position.distance_to(game.spawn)<.1,"return_to_gate_finishes_at_spawn")
	var old: int=game.terrain.current_id
	var gate_used: Array=[]
	for gate: Array in game.model["gates"]:
		if int(gate[0])==old or int(gate[1])==old:
			gate_used=gate
			break
	var target: int=int(gate_used[1]) if int(gate_used[0])==old else int(gate_used[0])
	var landing: Vector2=representatives[target]
	var position_before: Vector2=game.player.position
	game.begin_transition(target,landing)
	require(game.transition_busy and game.player.frozen,"transition_freezes_input")
	var max_alpha:=0.0
	while game.transition_busy:
		await process_frame
		max_alpha=maxf(max_alpha,game.fade.modulate.a)
	require(max_alpha>=.99,"transition_reaches_full_black")
	require(game.fade.modulate.a<.01,"transition_fades_back_in")
	require(game.terrain.current_id==target and game.player.position.distance_to(landing)<.1,"transition_uses_exact_arrival_coordinates")
	require(game.terrain.get_child_count()==1,"single_scene_after_black_transition")
	var bad_crossing_found:=false
	for y: int in range(20,340):
		if bad_crossing_found:break
		for x: int in range(10,310):
			var at:=Vector2(x+.5,y+.5)*24
			var a: int=game.navigation.region_at(at)
			var b: int=game.navigation.region_at(at+Vector2(24,0))
			if a>=0 and b>=0 and a!=b and not game.navigation.can_cross(a,b,at+Vector2(24,0)):
				game.load_district(a)
				bad_crossing_found=not game.allow_motion(at,at+Vector2(24,0)) and not game.transition_busy
				break
	require(bad_crossing_found,"non_road_border_does_not_switch_regions")
	game.load_district(game.navigation.region_at(game.spawn))
	game.player.position=game.spawn
	game.player.frozen=false
	var destination: Vector2=game.Space.project(Vector2(527,1140))
	require(game.request_path(destination),"auto_route_from_gate_to_chunhua_plaza")
	game.player.set_physics_process(true)
	for i: int in range(1000):
		await physics_frame
		if game.player.path.is_empty() and not game.transition_busy:break
	require(game.player.position.distance_to(destination)<30,"auto_route_arrives_after_road_transition")
	require(game.navigation.region_at(game.player.position)==game.terrain.current_id,"auto_route_keeps_loaded_region_correct")
	game.player.set_physics_process(false)
	var report: Dictionary={"checks":checks,"failures":failures,"passed":failures.is_empty(),"total_map_texture_bytes":total_texture_bytes,"largest_active_map_texture_bytes":max_texture_bytes,"max_loaded_scenes":game.terrain.max_scene_count,"gates":game.model["gates"].size(),"trees":game.model["trees"].size()}
	var file:=FileAccess.open(game.package_root.path_join("区块验证报告.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("DISTRICT_TEST ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
