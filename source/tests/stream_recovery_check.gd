extends SceneTree
var game: Node2D
var checks:=0
var failures: Array[String]=[]
var samples: Array[Dictionary]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func frames(n: int=3) -> void:
	for i: int in range(n):await process_frame
func transition() -> void:
	var deadline:=Time.get_ticks_msec()+20000
	while game.transition_busy and Time.get_ticks_msec()<deadline:await process_frame
	check(not game.transition_busy,"transition finishes");await physics_frame;await frames()
func overlap() -> bool:
	var query:=PhysicsShapeQueryParameters2D.new();var shape:=CircleShape2D.new();shape.radius=game.player.RADIUS
	query.shape=shape;query.transform.origin=game.player.position;query.exclude=[game.player.get_rid()]
	return not game.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()
func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game);await frames()
	game.start_new_game();await transition()
	game.player.set_physics_process(false);game.player.camera.position_smoothing_enabled=false
	root.size=Vector2i(1920,1080)
	for index: int in range(20):
		var old: Node2D=game.terrain.current_scene
		game.load_district(index)
		check(not is_instance_valid(old),"previous region freed "+str(index))
		var a: Array=game.model["regions"][index]["visual_bounds"]
		game.player.position=Vector2(a[0]+a[2]*.5,a[1]+a[3]*.5)*24
		game.player.camera.reset_smoothing();await frames()
		var layer: Node2D=game.terrain.current_scene.hd_layer
		await layer.wait_for_view()
		check(game.terrain.get_child_count()==1,"one region only "+str(index))
		check(layer.view_ready(),"visible art completely loaded "+str(index))
		check(game.terrain.active_texture_bytes<=1048576,"preview below 1 MiB "+str(index))
		check(layer.peak_jobs<=2 and layer.pending.size()<=2,"at most two decode jobs "+str(index))
		var rebuilds: int=layer.viewport_rebuilds
		await frames(12)
		check(layer.viewport_rebuilds==rebuilds,"idle camera skips tile-list rebuild "+str(index))
		samples.append({"region":game.model["regions"][index]["id"],"base_bytes":game.terrain.active_texture_bytes,"hd_bytes":layer.active_bytes,"jobs_peak":layer.peak_jobs})
	# Rapid pan and resolution changes must not queue decode work for old views.
	for zoom: float in [.6,1,1.5,2,2.4]:
		game.player.camera.zoom=Vector2.ONE*zoom
		for step: int in range(20):
			game.player.position.x+=70 if step%2==0 else -60
			game.player.camera.force_update_scroll();await process_frame
			check(game.terrain.current_scene.hd_layer.pending.size()<=2,"pan decode queue bounded")
		await game.terrain.current_scene.hd_layer.wait_for_view()
		check(game.terrain.current_scene.hd_layer.view_ready(),"pan settles to complete HD view")
	var outdoor: Node2D=game.terrain.current_scene
	game.day_clock.current_period=3;game.story_system.stage=3
	var context: Dictionary={"building":"B02","floor":1,"kind":"classroom","room":int(game.story_system.data["lab_room"])}
	game.change_interior(context);await transition()
	check(not is_instance_valid(outdoor) and game.terrain.current_scene.get("hd_layer")==null,"outdoor resources gone indoors")
	check(not game.motion_navigation().walkable(Vector2(84,153)),"original initiation point reproduces desk bug")
	game.story_system.initiation_sequence()
	var deadline:=Time.get_ticks_msec()+60000
	var mentor_previous:=Vector2(INF,INF)
	while game.story_system.running and Time.get_ticks_msec()<deadline:
		if game.story_system.stage==4 and not game.transition_busy:
			check(game.motion_navigation().walkable(game.player.position),"hero always clear during cinematic")
			for actor: Sprite2D in game.story_system.actors:
				check(game.motion_navigation().walkable(actor.position),"cinematic actor stays in aisle")
			if is_instance_valid(game.story_system.mentor_sprite):
				var at: Vector2=game.story_system.mentor_sprite.position
				if is_finite(mentor_previous.x):check(game.motion_navigation().segment_clear(mentor_previous,at),"mentor walks around desks")
				mentor_previous=at
		if game.dialogue_view.visible:
			game.dialogue_view.accept()
		await create_timer(.03).timeout
	check(not game.story_system.running and game.story_system.stage==5,"first-chapter initiation completes")
	await physics_frame
	check(not overlap() and game.motion_navigation().walkable(game.player.position),"hero free before saving or loading")
	game.player.set_physics_process(true)
	game.interaction_delay=1000
	var target: Vector2=game.terrain.current_scene.portals[0]["at"]
	check(game.request_path(target),"exit route exists immediately after demo")
	deadline=Time.get_ticks_msec()+10000
	while not game.player.path.is_empty() and Time.get_ticks_msec()<deadline:await physics_frame
	check(game.player.position.distance_to(target)<3,"hero actually walks to exit after demo")
	# Existing affected saves recover rather than requiring a new game.
	check(game.save_game_slot(1)["ok"],"checkpoint save succeeds")
	var record: Dictionary=game.save_store.read_slot(1)
	record["state"]["position"]=[84,153]
	check(game.queue_restore(record["state"],"legacy stuck position")["ok"],"affected old checkpoint accepted")
	await transition()
	check(not overlap() and game.motion_navigation().walkable(game.player.position),"affected old checkpoint moved to aisle")
	var report: Dictionary={"checks":checks,"passed":failures.is_empty(),"failures":failures,"regions":samples,"max_active_regions":game.terrain.max_scene_count,"max_decode_jobs":2,"actual_cinematic_and_exit_walk":true}
	FileAccess.open(game.package_root.path_join("runtime/stream_recovery_checks.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("STREAM_RECOVERY ",checks," checks; ",failures);quit(0 if failures.is_empty() else 1)
