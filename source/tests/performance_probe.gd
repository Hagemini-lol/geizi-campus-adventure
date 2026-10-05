extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var game: Node2D=(load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.player.set_physics_process(false)
	game.player.camera.position_smoothing_enabled=false
	game.player.position=game.Space.project(Vector2(527,1120))
	game.load_district(16)
	var label:="after"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--probe="): label=arg.trim_prefix("--probe=")
	if label=="before": install_legacy_facade(game)
	# Performance counters update periodically; discard texture-loading frames.
	var warm_until:=Time.get_ticks_msec()+1600
	while Time.get_ticks_msec()<warm_until: await process_frame
	var times: Array[float]=[]
	var draw_calls: Array[float]=[]
	var started:=Time.get_ticks_usec()
	for i: int in range(180):
		game.player.position.x+=1.68 # Camera travel at the regular 4.2 m/s speed.
		await process_frame
		await RenderingServer.frame_post_draw
		times.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
		draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var mean_frame_ms:=(Time.get_ticks_usec()-started)/1000.0/180
	times.sort()
	var sum_time:=0.0
	var sum_calls:=0.0
	for value: float in times: sum_time+=value
	for value: float in draw_calls: sum_calls+=value
	var file:=FileAccess.open(game.package_root.path_join("性能对比_"+label+".json"),FileAccess.WRITE)
	var report: Dictionary={"scene":"B12","samples":times.size(),"mean_process_ms":sum_time/times.size(),"p95_process_ms":times[int(times.size()*.95)],"mean_frame_ms":mean_frame_ms,"mean_draw_calls":sum_calls/draw_calls.size(),"map_texture_bytes":game.terrain.active_texture_bytes}
	file.store_string(JSON.stringify(report,"  "))
	print("PERFORMANCE ",label," ",report)
	quit()

func install_legacy_facade(game: Node2D) -> void:
	var scene: Node2D=game.terrain.current_scene
	var texture:=ImageTexture.create_from_image(game.terrain.trim_frame(Image.load_from_file(game.terrain.asset_root.path_join(str(game.model["regions"][16]["image"])))))
	var painter:=Node2D.new()
	painter.set_script(load("res://human_scale_details.gd"))
	painter.model=game.model
	painter.index=16
	painter.map_texture=texture
	painter.map_bounds=scene.get_node("StaticMap").map_bounds
	painter.camera=game.player.camera
	for child: Node in scene.get_children():
		if child is Sprite2D: (child.texture as AtlasTexture).atlas=texture
	for feature: Dictionary in game.data["zones"]:
		if str(feature["id"]) in ["P01","G02","G03","N01","N02"] or feature["kind"]=="building": continue
		var a: Array=feature["footprint"]
		painter.preserved.append(game.Space.box_to_world(Rect2(a[0],a[1],a[2],a[3])))
	for blocker: Dictionary in game.data["blockers"]:
		if blocker["owner"]!="trees": continue
		var a: Array=blocker["rect"]
		painter.planting.append(game.Space.box_to_world(Rect2(a[0],a[1],a[2],a[3])))
	for part: Dictionary in scene.get_node("StaticMap").parts:
		var value: Dictionary=part.duplicate()
		value["stories"]=2
		for feature: Dictionary in game.data["zones"]:
			if feature["id"]==value["owner"] and feature.get("storeys")!=null: value["stories"]=int(feature["storeys"])
		painter.parts.append(value)
	scene.add_child(painter)
