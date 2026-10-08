extends SceneTree
var game: Node2D
func _initialize() -> void:call_deferred("run")
func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.start_new_game()
	while game.transition_busy:await process_frame
	game.story_system.stage=6;game.story_system.reward_given=true;game.campaign.index=30
	var seen: Dictionary={}
	for q: Dictionary in game.task_system.definitions.values():
		for step: Dictionary in q["steps"]:
			if not step.has("puzzle") or seen.has(step["puzzle"]["kind"]):continue
			var spec: Dictionary=step["puzzle"];seen[spec["kind"]]=true
			var board:=preload("res://puzzle_board.gd").new();board.game=game
			board.run(spec,{},"0")
			for n: int in range(4):await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(game.package_root.path_join("runtime/puzzle_"+spec["kind"]+".png"))
			game.campaign.selected.emit("cancel");await process_frame
	game.menu_view.open_menu();game.menu_view.open_mod_import()
	for n: int in range(4):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(game.package_root.path_join("runtime/mod_import.png"))
	print("PUZZLE_VISUAL_CAPTURE_DONE")
	game.queue_free();game=null;await process_frame;await process_frame;quit()
