extends SceneTree
var game: Node2D
func _initialize() -> void:call_deferred("run")
func frames() -> void:
	for n: int in range(4):await process_frame
func shot(name: String) -> void:
	await frames();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(game.package_root.path_join("runtime/"+name+".png"))
func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game);await frames()
	game.start_new_game();while game.transition_busy:await process_frame
	game.story_system.stage=6;game.story_system.reward_given=true;game.campaign.index=31
	await game.change_interior({"building":"B01","floor":3,"kind":"classroom","room":0})
	for item: String in game.relationships.content["gifts"]["items"]:game.economy.add_item(item,2)
	game.story_system.begin_sequence()
	game.relationships.gift_menu({"character":"lao_li","name":"牢李"})
	await shot("v16-gift-menu")
	game.campaign.selected.emit("cancel");await frames()
	game.dialogue_view.begin_script([{"actor":"yang_zi","text":"你坐这儿。我刚才给旁边椅子起了你的名字，结果差点叫椅子去吃饭。"},{"actor":"zhao_mugei","text":"这把椅子饭卡带了吗？"}])
	await shot("v16-dialogue")
	game.queue_free();game=null;await process_frame;quit()
