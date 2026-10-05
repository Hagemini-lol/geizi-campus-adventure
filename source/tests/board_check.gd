extends SceneTree
var game: Node2D
var failures: Array[String]=[]
var out:="D:/Godot/地图重绘预览/内景"
func _initialize() -> void:call_deferred("run")
func check(condition: bool, text: String) -> void:
	if not condition:failures.append(text);push_error(text)
func run() -> void:
	game=(load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.player.set_physics_process(false)
	for entry: Dictionary in game.interior_info["entrances"]:
		var landing: Vector2=game.point(entry["board_arrival"])*24
		game.load_district(game.navigation.region_at(landing))
		game.player.position=landing
		game.interaction_delay=0
		await physics_frame
		await process_frame
		await process_frame
		check(game.nearby.get("action","")=="board","board interaction "+str(entry["id"]))
		game.interact()
		check(game.map_view.visible and game.map_view.teleport_mode,"board map "+str(entry["id"]))
		for destination: Dictionary in game.map_view.selections:
			var safe: Vector2=game.safe_outdoor(destination["destination"])
			check(game.navigation.walkable(safe) and game.navigation.region_at(safe)>=0,"safe destination "+str(destination["id"]))
		game.map_view.close_map()
		check(game.map_view.map_texture==null,"release full campus map")
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out.path_join("实际游戏预览/告示牌_"+str(entry["id"])+".png"))
	var report: Dictionary={"boards":game.interior_info["entrances"].size(),"map_locations":30,"failures":failures,"passed":failures.is_empty()}
	var file:=FileAccess.open(out.path_join("告示牌检查.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("BOARD_CHECK ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
