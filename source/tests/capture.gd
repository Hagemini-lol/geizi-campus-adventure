extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var game := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	if game.player == null:
		quit(1)
		return
	game.player.position = game.Space.project(Vector2(527, 1140))
	game.load_district(game.navigation.region_at(game.player.position))
	game.player.show_direction(0)
	game.player.camera.reset_smoothing()
	for i: int in range(6): await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("campus-walk-review.png"))
	game.toggle_map()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("campus-map-review.png"))
	game.toggle_map()
	for tree: Array in game.model["trees"]:
		if int(tree[2]) != 19 or tree[0]<140 or tree[0]>170 or tree[1]<336 or tree[1]>345: continue
		game.player.position=Vector2(tree[0]+1,tree[1])*24
		game.load_district(19)
		game.player.camera.reset_smoothing()
		for i: int in range(8): await physics_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("campus-tree-review.png"))
		break
	quit()
