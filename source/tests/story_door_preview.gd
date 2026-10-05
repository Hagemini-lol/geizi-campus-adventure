extends SceneTree

func _initialize() -> void:call_deferred("run")
func run() -> void:
	var game: Node2D=(load("res://main.tscn") as PackedScene).instantiate();root.add_child(game)
	await process_frame;await process_frame
	game.start_new_game()
	while game.transition_busy:await process_frame
	game.story_system.restore({"version":1,"stage":3,"reward_given":false,"leave_permission":false})
	game.day_clock.current_period=3
	game.change_interior({"building":"B02","floor":1,"kind":"corridor"})
	while game.transition_busy:await process_frame
	game.player.position=Vector2(game.story_system.observed_door_x,108);game.interaction_delay=0
	game.player.camera.reset_smoothing()
	await process_frame;await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(game.package_root.path_join("runtime/剧情预览/03_震动教室门.png"))
	print("DOOR_PREVIEW ",game.nearby.get("room",-1)," ",game.interaction_label.text)
	game.queue_free();await process_frame;quit()
