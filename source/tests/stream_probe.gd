extends SceneTree
var game: Node2D
var samples: Array[Dictionary]=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.game_started=true;game.front_end.hide_title();game.player.show()
	game.player.set_physics_process(false);game.player.camera.position_smoothing_enabled=false
	game.story_system.stage=6;game.story_system.reward_given=true
	root.size=Vector2i(1920,1080)
	for id: String in ["N02","S01","B12"]:
		var index:=0
		for i: int in range(game.model["regions"].size()):
			if game.model["regions"][i]["id"]==id:index=i;break
		var a: Array=game.model["regions"][index]["world_bounds"]
		game.player.position=Vector2(a[0]+a[2]*.5,a[1]+a[3]*.5)*24
		var start:=Time.get_ticks_usec()
		game.load_district(index);game.player.camera.reset_smoothing()
		await process_frame;await process_frame
		await game.terrain.current_scene.hd_layer.wait_for_view()
		var loading_ms:=(Time.get_ticks_usec()-start)/1000.0
		var layer: Node2D=game.terrain.current_scene.hd_layer
		# Godot's process monitor is a rolling statistic. Exclude previous load
		# and manual microbenchmark spikes before sampling the next scene.
		var warm_until:=Time.get_ticks_msec()+1500
		while Time.get_ticks_msec()<warm_until:await process_frame
		var timing: Array[float]=[]
		for n: int in range(120):
			await process_frame
			timing.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
		var total:=0.0
		for value: float in timing:total+=value
		timing.sort()
		var script_started:=Time.get_ticks_usec()
		for n: int in range(100):game._process(.016);layer.refresh();game.campaign._process(.016)
		var script_ms:=(Time.get_ticks_usec()-script_started)/100000.0
		samples.append({"id":id,"loading_ms":loading_ms,"mean_process_ms":total/timing.size(),"p95_process_ms":timing[114],"idle_script_ms":script_ms,"base_bytes":game.terrain.active_texture_bytes,"hd_bytes":layer.active_bytes,"tiles":layer.tiles.size(),"pending":layer.pending.size(),"render_texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"engine_static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT)})
	var tag:="before"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--probe="):tag=arg.trim_prefix("--probe=")
	var file:=FileAccess.open(game.package_root.path_join("runtime/stream_"+tag+".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(samples,"  "));print("STREAM_PROBE ",samples);quit()
