extends SceneTree
var game: Node2D
func _initialize() -> void:call_deferred("run")
func capture(name_value: String) -> void:
	for i: int in range(5):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/Godot/校园自由漫游/runtime/campaign_"+name_value+".png")
func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.game_started=true;game.front_end.hide_title();game.gameplay_hud.show();game.player.show();game.story_system.stage=6;game.story_system.reward_given=true;game.day_clock.current_period=2;game.apply_time_lighting()
	game.campaign.index=12
	for spec: Array in [["B06",1,0,"library"],["B15",1,0,"office"],["STORY_HOUSE",1,0,"house"],["STORY_SEAL",1,0,"seal"]]:
		await game.change_interior({"building":spec[0],"floor":spec[1],"kind":"classroom","room":spec[2]})
		await capture(spec[3])
	game.campaign.index=31;game.campaign.prepare_battle(game.campaign.current());await capture("prepare");game.campaign.selected.emit("cancel");await process_frame
	game.campaign.open_journal();await capture("journal");game.campaign.selected.emit("close");await process_frame
	quit()
