extends SceneTree

const Assets=preload("res://external_battle_assets.gd")
var game: Node2D
var checks:=0
var failures: Array[String]=[]
var office_count:=0
var staff_counts: Dictionary={}
var prefix: String
func _initialize() -> void:call_deferred("run")
func check(value: bool, message: String) -> void:
	checks+=1
	if not value:failures.append(message);push_error(message)
func frames() -> void:
	await process_frame;await process_frame
func transition() -> void:
	var deadline:=Time.get_ticks_msec()+20000
	while game.transition_busy and Time.get_ticks_msec()<deadline:await process_frame
	check(not game.transition_busy,"transition completes");await physics_frame;await frames()
func inside(path: String) -> bool:
	return path.replace("\\","/").simplify_path().begins_with(prefix)
func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	var dir: String=game.package_root.path_join("runtime/办公室分享预览")
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_texture().get_image().save_png(dir.path_join(name+".png"))
func run() -> void:
	game=(load("res://main.tscn") as PackedScene).instantiate();root.add_child(game);await frames()
	prefix=game.package_root.replace("\\","/").simplify_path().trim_suffix("/")+"/"
	check(game.front_end.cover.texture!=null and game.front_end.title_visible,"packaged cover loads")
	check(inside(game.battle_asset_root) and inside(game.interior_directory) and inside(game.npc_catalog.project_root),"asset roots inside portable game folder")
	for path: String in game.interior_info["assets"].values():check(inside(path) and FileAccess.file_exists(path),"interior asset bundled "+path.get_file())
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(game.package_root.path_join("素材打包清单.json")))
	for file: Dictionary in manifest["files"]:check(FileAccess.file_exists(game.package_root.path_join(file["file"])),"bundled file exists "+str(file["file"]))
	game.start_new_game();await transition()
	check(game.terrain.current_scene!=null and game.terrain.hd_manifest["tiles"].size()>1000,"HD world and tile manifest loaded")
	game.toggle_map();await frames();check(game.map_view.visible,"bundled full map opens");game.toggle_map()
	for index: int in range(game.model["regions"].size()):
		check(game.load_district(index),"all twenty outdoor maps load")
		check(game.terrain.current_scene.texture!=null,"district texture loaded")
	# Every floor has precisely one rightmost office and one nearest-stair office.
	for building_id: String in game.interior_info["buildings"]:
		var building: Dictionary=game.interior_info["buildings"][building_id]
		for floor_data: Dictionary in building["floors"]:
			var offices: Array=floor_data["rooms"].filter(func(room: Dictionary):return room.get("office",false))
			check(offices.size()==2,"two offices per floor")
			check(floor_data["rooms"][-1].get("office_location")=="right","rightmost room is office")
			for room: Dictionary in offices:
				office_count+=1
				var context: Dictionary={"building":building_id,"floor":int(floor_data["floor"]),"kind":"classroom","room":room["index"]}
				game.change_interior(context);await transition()
				var scene: Node2D=game.terrain.current_scene
				check(scene.is_office and inside(scene.source_path) and scene.title.contains("办公室"),"office uses bundled original image and title")
				check(scene.furniture_footprints.size()==21,"sixteen office desks plus cabinets and plant")
				for box: Rect2 in scene.blockers:check(box.size==Vector2.ONE,"office furniture collision one pixel")
				check(scene.navigation.walkable(scene.landing("front")) and scene.navigation.walkable(scene.landing("rear")),"office doors have safe landings")
				check(not scene.navigation.route(scene.landing("front"),scene.landing("rear")).is_empty(),"office front/rear connected")
				check(scene.portals.size()==2,"office both exits exist")
				if building_id=="B02":
					check(scene.npcs==null and game.active_monsters()!=null,"lab offices have monsters and no NPC")
					continue
				var manager: Node2D=scene.npcs
				check(manager.records.size()==4 and not manager.is_processing() and manager.get_child_count()==0,"office contains one student and three baked staff")
				var seen: Dictionary={}
				for record: Dictionary in manager.records:
					check(scene.navigation.walkable(record["at"]),"office NPC on walkable floor")
					check(not manager.approach(record["uid"],game.player.position).is_empty(),"office NPC reachable")
					var role: String=record["role"]
					seen[role]=true
					if role!="office_student":staff_counts[role]=int(staff_counts.get(role,0))+1
					game.dialogue_view.greet(record);await frames()
					check(game.dialogue_view.speech.text in game.office_plan.data["dialogue_profiles"][role]["greetings"],"role-specific staff/student greeting")
					check(game.dialogue_view.right_portrait.texture!=null and game.dialogue_view.left_portrait.texture!=null,"staff portraits loaded")
					game.dialogue_view.accept();await frames()
					check(game.dialogue_view.speech.text in game.office_plan.data["dialogue_profiles"][role]["replies"],"hero responds appropriately to identity")
					game.dialogue_view.close(false)
				check(seen.size()==4,"all three staff types and student appear")
				if int(floor_data["floor"])==1 and building_id=="B12":await shot(room["office_asset"])
		game.change_interior({"building":building_id,"floor":1,"kind":"corridor"});await transition()
		for portal: Dictionary in game.terrain.current_scene.portals:
			if portal["action"]=="room" and building["floors"][0]["rooms"][int(portal["room"])].get("office",false):check(game.interaction_text(portal)=="进入办公室","office corridor interaction labelled")
	check(office_count==34 and staff_counts.size()==3,"all thirty-four offices and staff sets")
	for count: int in staff_counts.values():check(count==26,"each staff character appears in 26 non-lab offices")
	for building_id: String in ["B01","B05","B12"]:
		game.change_interior({"building":building_id,"floor":3,"kind":"classroom","room":0});await transition()
		check(not game.terrain.current_scene.is_office and game.terrain.current_scene.npcs.movers.size()==10 and game.terrain.current_scene.npcs.records.size()==10,"three leftmost ten classes contain only named students")
		game.toggle_menu();await frames();check(game.menu_view.visible,"packaged menu textures load");game.close_menu()
	game.change_interior({"building":"B02","floor":1,"kind":"classroom","room":5});await transition()
	var monsters: Node2D=game.active_monsters()
	check(game.battle_view.start(monsters.records[0],monsters.key),"battle original UI loads from packaged scripts")
	await frames();check(game.battle_view.interface.category_buttons.size()==6,"packaged battle categories available")
	await shot("包内战斗素材")
	game.battle_view.finish("escape");game.battle_view.close();await frames()
	for path: String in Assets.reads:check(inside(path),"original UI reads only bundled files")
	for path: String in game.menu_view.asset_paths:check(inside(path),"menu reads only bundled files")
	check(game.save_game_slot(1)["ok"],"portable game saves")
	game.load_game_slot(1);await transition();check(game.terrain.current_scene.is_office,"office saved location restores")
	game.time_skip_ready_at_ms=0;var before: int=game.monster_world.period_serial
	game.fast_forward_time();await transition();check(game.monster_world.period_serial==before+1 and game.active_monsters().records.size()<=2,"laboratory office refreshes with classroom cap")
	var report: Dictionary={"checks":checks,"failures":failures,"game_root":game.package_root,"office_count":office_count,"staff_counts":staff_counts,"all_runtime_asset_reads_inside_package":true,"original_ui_asset_reads":Assets.reads.size(),"portable":true}
	var file:=FileAccess.open(game.package_root.path_join("办公室与分享验证报告.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("OFFICE_SHARE_CHECK ",checks," failures=",failures.size());game.queue_free();await frames();quit(0 if failures.is_empty() else 1)
