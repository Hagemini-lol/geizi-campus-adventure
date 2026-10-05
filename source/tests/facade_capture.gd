extends SceneTree

var game: Node2D
var out: String

func _initialize() -> void: call_deferred("capture")

func shot(at: Vector2, zoom: float, offset: Vector2, file: String, collisions: bool=false) -> void:
	game.player.position=game.Space.project(at)
	game.load_district(game.navigation.region_at(game.player.position))
	# Inspection camera may extend beyond the loaded administrative area.
	game.player.camera.limit_left=-10000000
	game.player.camera.limit_top=-10000000
	game.player.camera.limit_right=10000000
	game.player.camera.limit_bottom=10000000
	game.player.camera.zoom=Vector2.ONE*zoom
	game.player.camera.offset=offset*24
	game.player.camera.reset_smoothing()
	game.debug_geometry=collisions
	game.collision_overlay.visible=collisions
	game.player.show_direction(0)
	for i: int in range(8): await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(file))

func capture() -> void:
	game=(load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	if not game.load_error.is_empty(): quit(1); return
	game.player.set_physics_process(false)
	out=game.package_root.get_base_dir().path_join("地图重绘预览/外墙参考预览")
	DirAccess.make_dir_recursive_absolute(out)
	await shot(Vector2(527,1120),1.25,Vector2(0,-4.5),"春华楼近景.png")
	await shot(Vector2(527,1120),.42,Vector2(0,-4.5),"春华楼全景.png")
	await shot(Vector2(210,180),1.25,Vector2(0,-4.5),"其它楼外墙示例.png")
	await shot(Vector2(527,1120),.42,Vector2(0,-4.5),"春华楼碰撞核对.png",true)
	print("FACADE_CAPTURES ",out)
	quit()
