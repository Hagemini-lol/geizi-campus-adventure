extends SceneTree

var game: Node2D
func _initialize() -> void:call_deferred("run")
func shot(name: String) -> void:
	for i: int in range(3):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/Godot/校园自由漫游/runtime/expansion_"+name+".png")
func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.start_new_game()
	while game.transition_busy:await process_frame
	game.story_system.stage=6;game.story_system.reward_given=true;game.campaign.index=13
	game.task_system.start("side_li_radio");game.task_system.start("side_shuo_load")
	game.teleport_outdoor(game.campaign.outdoor_point("B04"))
	while game.transition_busy:await process_frame
	game.campaign.queue_redraw();await create_timer(.4).timeout;await shot("side_markers")
	game.menu_view.open_menu();game.menu_view.select_tab("status");await shot("side_menu")
	game.side_quests.open_journal();await create_timer(.3).timeout;await shot("side_journal")
	game.campaign.selected.emit("close");await process_frame
	print("SIDEQUEST_VISUAL_CAPTURED");quit()
