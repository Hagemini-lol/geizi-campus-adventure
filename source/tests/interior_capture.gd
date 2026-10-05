extends SceneTree
var game: Node2D
var out:="D:/Godot/地图重绘预览/内景/实际游戏预览"
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name+".png"))
func wait_transition() -> void:
	while game.transition_busy:await process_frame
	await physics_frame
func run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	game=(load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.player.set_physics_process(false)
	for id: String in ["B12","B05","B01","B02"]:
		game.change_interior({"kind":"corridor","building":id,"floor":3})
		await wait_transition()
		await capture(id+"_三楼楼梯")
		var room: Dictionary=game.interior_info["buildings"][id]["floors"][2]["rooms"][0]
		game.player.position=Vector2(float(room["front_door_x"])*24,122)
		game.player.camera.reset_smoothing()
		await capture(id+"_三楼十班门")
	game.change_interior({"kind":"classroom","building":"B12","floor":3,"room":0})
	await wait_transition()
	await capture("十班内部")
	game.debug_geometry=true
	await capture("十班碰撞")
	game.debug_geometry=false
	game.change_interior({"kind":"classroom","building":"B12","floor":3,"room":1})
	await wait_transition()
	await capture("普通教室内部")
	game.debug_geometry=true
	await capture("普通教室碰撞")
	game.debug_geometry=false
	for entry: Dictionary in game.interior_info["entrances"]:
		if entry["id"]!="B12":continue
		game.teleport_outdoor(game.point(entry["board_arrival"])*24)
		await wait_transition()
		await capture("春华楼门口告示牌")
	game.map_view.open_map(true)
	await capture("校园全图传送界面")
	game.map_view.close_map()
	quit()
