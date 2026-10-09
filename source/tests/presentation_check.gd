extends SceneTree
var game: Node2D
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func frames() -> void:await process_frame;await process_frame
func transition() -> void:
	while game.transition_busy:await process_frame
	await frames()
func screenshot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(game.package_root.path_join("runtime/"+name+".png"))
func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game);await frames();game.start_new_game();await transition()
	game.story_system.stage=6;game.campaign.index=game.campaign.data["nodes"].size();game.story_system.refresh_objective()
	var portrait: Image=game.npc_catalog.dialogue_portrait("fei_yan")
	check(portrait!=null and portrait.get_height()>1000,"Feiyan receives original Leon portrait")
	check(game.npc_catalog.frame("fei_yan",0).get_height()<1000,"world Feiyan atlas remains separate")
	game.dialogue_view.begin_script([{"actor":"fei_yan","text":"先站稳，再把注意力集中在你要保护的人身上。"}])
	await frames();check(game.dialogue_view.right_portrait.texture.get_height()==portrait.get_height(),"script dialogue uses override")
	await screenshot("v15-leon-dialogue");game.dialogue_view.accept();await frames()
	for building: String in ["B02","B07","B16","B03","B15","STORY_HOUSE","STORY_SEAL"]:
		game.change_interior({"building":building,"floor":1,"kind":"classroom","room":2 if building=="B15" else 0});await transition()
		var spec: Dictionary={"uid":"presentation-probe","id":"ink_slime","level":1,"hp":100000}
		check(game.battle_view.start({"monster":spec},"probe"),"battle opens in "+building)
		await frames();var ui: Control=game.battle_view.interface
		check(ui.stage.background_view.texture is ViewportTexture,"battle uses one-shot location capture "+building)
		check(ui.location_name.contains(str(game.interior_info["buildings"][building]["name"])),"place name matches "+building)
		check(ui.submenus["attack"].visible and ui.submenus["attack"].command_buttons.has("physical"),"basic action immediately visible")
		check(ui.dock.get_global_rect().intersection(ui.stage.get_global_rect()).get_area()==0,"stage and action dock separated")
		var children: Array=game.battle_view.root_panel.get_children().filter(func(n: Node):return n is SubViewport)
		check(children.size()==1 and children[0].render_target_update_mode in [SubViewport.UPDATE_ONCE,SubViewport.UPDATE_DISABLED],"static background renders once")
		if building in ["B02","B07","STORY_SEAL"]:await screenshot("v15-battle-"+building)
		for category: String in ui.category_buttons:
			check(ui.open_category(StringName(category)) and ui.submenus[category].visible,"category opens "+category)
			for button: Button in ui.submenus[category].command_buttons.values():check(button.custom_minimum_size.y>=44,"touch command large enough")
		game.battle_view.finish("escape");game.battle_view.close();await frames()
		check(not is_instance_valid(children[0]),"background capture released after battle")
	# Exercise responsive layout with many spell entries and no input interception.
	game.change_interior({"building":"B07","floor":1,"kind":"classroom","room":0});await transition()
	game.battle_view.start({"monster":{"uid":"compact","id":"ink_slime","level":1,"hp":100000}},"probe");await frames()
	var compact: Control=game.battle_view.interface
	compact.size=Vector2(960,800);compact.sync_layout();await frames()
	check(compact.category_grid.columns==6,"compact layout uses six tabs")
	check(compact.submenus["attack"].grid.columns==2,"compact layout uses two command columns")
	check(compact.dock.get_rect().end.y<=compact.size.y+1,"compact dock stays within viewport")
	game.battle_view.finish("escape");game.battle_view.close();await frames()
	var f:=FileAccess.open(game.package_root.path_join("runtime/presentation_checks.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures},"  "))
	print("PRESENTATION_CHECK ",checks," FAILURES ",failures.size());game.queue_free();game=null;await process_frame;quit(0 if failures.is_empty() else 1)
