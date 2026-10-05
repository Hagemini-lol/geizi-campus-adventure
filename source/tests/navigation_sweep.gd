extends SceneTree
var game: Node2D
var results: Array[Dictionary]=[]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	# Accelerate the test clock while retaining the normal 1/60 s physics step.
	Engine.time_scale=6
	Engine.physics_ticks_per_second=360
	game=(load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await physics_frame
	await physics_frame
	assert(absf(game.player.get_physics_process_delta_time()-1.0/60)<.000001)
	game.player.set_physics_process(false)
	var failed:=false
	for index: int in range(20):
		var destination:=Vector2.INF
		for gate: Array in game.model["gates"]:
			if int(gate[0])!=index and int(gate[1])!=index: continue
			var at:=Vector2(gate[2],gate[3])*24
			for offset: Vector2 in [Vector2(12,0),Vector2(-12,0),Vector2(0,12),Vector2(0,-12)]:
				if game.navigation.region_at(at+offset)==index and not game.navigation.route(game.spawn,at+offset).is_empty(): destination=at+offset; break
			if destination!=Vector2.INF: break
		game.load_district(19)
		game.player.position=game.spawn
		game.player.path.clear()
		game.player.frozen=false
		await physics_frame
		var transitions_before: int=game.terrain.transition_count
		var requested: bool=destination!=Vector2.INF and game.request_path(destination)
		game.player.set_physics_process(true)
		for step: int in range(5000):
			await physics_frame
			if game.player.path.is_empty() and not game.transition_busy: break
		var passed: bool=requested and game.player.position.distance_to(destination)<6 and game.terrain.current_id==index
		game.player.set_physics_process(false)
		var row: Dictionary={"id":game.model["regions"][index]["id"],"passed":passed,"distance_pixels":game.player.position.distance_to(destination),"transitions":game.terrain.transition_count-transitions_before}
		results.append(row)
		failed=failed or not passed
		print("ACTUAL_ROUTE ",JSON.stringify(row))
	var file:=FileAccess.open(game.package_root.path_join("跨区实际移动验证.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":not failed,"results":results},"  "))
	file.close()
	quit(1 if failed else 0)
