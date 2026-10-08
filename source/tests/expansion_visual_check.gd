extends SceneTree

var game: Node2D
func _initialize() -> void:call_deferred("run")
func shot(name: String) -> void:
	for i: int in range(3):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/Godot/校园自由漫游/runtime/expansion_"+name+".png")
func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.game_started=true;game.front_end.hide_title();game.gameplay_hud.show();game.story_system.stage=6;game.story_system.reward_given=true
	game.campaign.index=31;game.campaign.flags["FINAL_ROUTE"]="H"
	var r: RefCounted=game.combat_rules;r.set_hero_level(35,true)
	for id: String in r.data["skills"]:r.learn(id)
	for id: String in ["book_eater_queen","dry_branch_ancient","empty_uniform_leader","gou_ga_boss"]:
		var monster: Dictionary={"uid":"visual","id":id,"level":45,"hp":r.monster_stats(id,45)["hp"]}
		game.battle_view.start({"monster":monster},"test")
		await create_timer(.5).timeout
		game.battle_view.interface.open_category(&"attack");await shot(id)
		if id=="gou_ga_boss":
			var v: Control=game.battle_view;v.enemy["hp_current"]=int(v.enemy["hp"])/2
			v.tactics.change_phase(v.enemy);v.tactics.begin_turn(v.enemy,2);v.enemy_motion.phase=2
			v.update_ui();await create_timer(.5).timeout;v.interface.open_category(&"items");await shot("gou_ga_phase2_items")
		v_finish()
		await process_frame
	print("EXPANSION_VISUAL_CAPTURED");quit()
func v_finish() -> void:
	game.battle_view.finish("escape");game.battle_view.close()
