extends "res://tests/relationship_check.gd"

var report_path:=""
func frames(n: int=3) -> void:
	for i: int in range(n):await process_frame
func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	game.player.camera.position_smoothing_enabled=false;game.player.camera.reset_smoothing()
	await frames();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(report_path.get_base_dir().path_join("v18-"+name+".png"))
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report-path="):report_path=arg.trim_prefix("--report-path=")
	game=load("res://main.tscn").instantiate();root.add_child(game);await frames()
	game.game_started=true;game.front_end.hide_title();game.story_system.stage=6;game.story_system.reward_given=true;game.campaign.index=31;game.day_clock.current_period=4
	game.player.set_physics_process(false)
	var spaces: RefCounted=game.campus_life.rooms
	var room_count:=0
	for entry: Dictionary in game.interior_info["entrances"]:
		var id: String=entry["id"]
		check(entry["has_interior"] and game.interior_info["buildings"].has(id),"every mapped building has an actual interior "+id)
		var building: Dictionary=game.interior_info["buildings"][id]
		check(building["floor_count"]==building["floors"].size(),"floor count agrees with reachable floors "+id)
		for floor_data: Dictionary in building["floors"]:
			check(not floor_data["rooms"].is_empty() and FileAccess.file_exists(game.interior_directory.path_join(floor_data["image"])),"floor corridor asset exists "+id+str(floor_data["floor"]))
			for spec: Dictionary in floor_data["rooms"]:
				room_count+=1
				check(int(spec["index"])<floor_data["rooms"].size() and not str(spec["name"]).is_empty(),"every room has stable identity and purpose "+id+str(floor_data["floor"])+str(spec["index"]))
		# One actual room per floor, plus every distinct room of new teaching building.
		for floor_data: Dictionary in building["floors"]:
			await game.change_interior({"building":id,"floor":floor_data["floor"],"kind":"classroom","room":0});await frames()
			var scene: Node2D=game.terrain.current_scene
			check(not game.transition_busy and scene.navigation.walkable(game.player.position),"actual room loads with safe landing "+scene.title)
			for portal: Dictionary in scene.portals:
				check(scene.navigation.walkable(portal["at"]) and not scene.navigation.route(game.player.position,portal["at"]).is_empty(),"actual exit can be walked to "+scene.title+str(portal["side"]))
			check(game.terrain.get_child_count()==1,"only one scene loaded")
			if id in ["B04","B09","B10"]:await shot(id)
		if id=="B13":
			for floor_data: Dictionary in building["floors"]:
				for spec: Dictionary in floor_data["rooms"]:
					await room(id,int(floor_data["floor"]),int(spec["index"]))
					check(game.motion_navigation().walkable(game.player.position),"new teaching room safely loads "+str(floor_data["floor"])+str(spec["index"]))
			await shot("B13")
		if id in spaces.PLANS:
			var context: Dictionary=game.interior_state.duplicate()
			var exit: Dictionary=game.terrain.current_scene.portals[-1];game.player.position=exit["at"];game.execute_interaction(exit)
			while game.transition_busy:await process_frame
			if id in spaces.DIRECT:check(game.interior_state.is_empty(),"new direct room returns to correct outdoor entry "+id)
			else:check(game.interior_state.get("kind")=="corridor","new classroom returns to own corridor")
	# Enter through the real outdoor doors, not just a direct test teleport.
	for entry: Dictionary in game.interior_info["entrances"]:
		var id: String=entry["id"]
		if not id in spaces.PLANS and not id in ["B07","B08"]:continue
		game.teleport_outdoor(game.point(entry["arrival"])*24)
		while game.transition_busy:await process_frame
		await frames()
		var door: Dictionary={}
		for item: Dictionary in game.interactions():
			if item["action"]=="entrance" and item["building"]==id:door=item
		check(not door.is_empty(),"real outdoor entrance is exposed "+id)
		if door.is_empty():continue
		var approach: PackedVector2Array=game.approach_interaction(door["at"])
		check(not approach.is_empty(),"real entrance approachable from outdoor arrival "+id)
		if approach.is_empty():continue
		game.player.position=approach[-1];game.execute_interaction(door)
		while game.transition_busy:await process_frame
		check(game.interior_state.get("building")==id,"actual outdoor door enters correct new building "+id)
		if id in ["B04","B07","B08"]:
			var up: Dictionary={}
			for item: Dictionary in game.interactions():
				if item["action"]=="up":up=item
			check(not up.is_empty(),"two-floor service building has actual upward stairs "+id)
			if not up.is_empty():
				game.player.position=up["at"];game.execute_interaction(up)
				while game.transition_busy:await process_frame
				check(game.interior_state.get("floor")==2 and game.motion_navigation().walkable(game.player.position),"actual stairs reach second floor safely "+id)
	# Morning and ordinary seats must be separate depth-sorted static sprites.
	for sample: Array in [["B01",3,0],["B12",3,0],["B05",3,0],["B13",1,0],["B01",1,1]]:
		game.day_clock.current_period=1;await room(sample[0],sample[1],sample[2])
		var scene: Node2D=game.terrain.current_scene;var textures: Dictionary={};var seated:=0
		for record: Dictionary in scene.npcs.records:
			if not record.get("seated",false):continue
			seated+=1
			var sprite: Sprite2D=record.get("sprite")
			check(sprite!=null and sprite.z_index==10 and not scene.npcs.is_processing(),"seated actor is depth-sorted without AI processing")
			if sprite==null:continue
			var footprint: Rect2=scene.furniture_footprints[int(record["seat_index"])]
			check(sprite.position.y>footprint.end.y and sprite.position.x==footprint.get_center().x,"body sorts after own chair and aligns horizontally")
			check(record["height"]<25 and record["height"]>8,"upper body fits actual chair instead of standing through desk")
			check(sprite.offset.y+sprite.texture.get_height()<0,"waist ends above chair legs")
			textures[sprite.texture.get_instance_id()]=true
		check(seated>0 and textures.size()<seated,"seated textures shared across repeated classmates")
		if sample[0]=="B01":await shot("seats-"+str(sample[1]))
	# A single weak actor uses its own assigned seat, never the first record index.
	game.day_clock.current_period=4;game.campaign.ao_until=game.economy.day_serial+7
	await room("B01",3,0)
	var weak: Dictionary={}
	for record: Dictionary in game.terrain.current_scene.npcs.records:
		if record["character"]=="lao_ao":weak=record
	check(weak.get("seated",false) and weak.get("seat_index")==18 and weak.has("sprite"),"recovering Ao has actual seat18 static pose")
	await shot("recovering-Ao");game.campaign.ao_until=0
	# Sleep is local, cancel-safe, time-based, and does not erase plot sanity.
	await room("B16",2,0);game.player.position=spaces.point_for("sleep")
	check(game.interactions().any(func(row: Dictionary):return row["action"]=="campus_sleep"),"own bed exposes real interaction")
	var slot: int=game.campaign.phase_slot();var money: int=game.economy.money
	answers.assign(["cancel"]);await spaces.open("sleep")
	check(slot==game.campaign.phase_slot() and money==game.economy.money and not game.story_system.running,"cancel rest spends nothing and releases controls")
	for key: String in ["hp","mp","energy","san"]:game.combat_rules.hero[key+"_current"]=1
	var plot: int=game.campaign.index;var sanity: int=game.combat_rules.hero["san_current"]
	var result: Dictionary=await spaces.sleep("nap")
	check(result["ok"] and game.campaign.phase_slot()==slot+1,"real nap spends exactly one chronological period")
	check(game.combat_rules.hero["hp_current"]>1 and game.combat_rules.hero["energy_current"]>1 and game.combat_rules.hero["san_current"]==sanity and game.campaign.index==plot,"nap restores body without bypassing sanity or plot")
	game.day_clock.current_period=4;var day: int=game.economy.day_serial;money=game.economy.money
	result=await spaces.sleep("night")
	check(result["ok"] and game.day_clock.current_period==1 and game.economy.day_serial==day+1,"sleep actually crosses midnight and wakes in morning")
	check(game.economy.money==money+50,"overnight allowance paid once")
	check(game.combat_rules.hero["hp_current"]==game.combat_rules.hero["hp"] and game.combat_rules.hero["energy_current"]==game.combat_rules.hero["energy"] and game.combat_rules.hero["mp_current"]==game.combat_rules.hero["mp"],"overnight fully restores physical and magic resources")
	await room("B16",2,1);game.player.position=spaces.point_for("sleep");slot=game.campaign.phase_slot()
	check(not (await spaces.sleep("nap"))["ok"] and slot==game.campaign.phase_slot(),"cannot sleep in another student's bed")
	# Dining exercises real menu, confirmations, insufficient funds, closed service,
	# packed food, death branch, resource caps, time passage and persistence.
	await room("B07",1,0);game.player.position=spaces.point_for("dine");game.day_clock.current_period=5
	money=game.economy.money;slot=game.campaign.phase_slot()
	answers.assign(["buy/rice_meal","cancel"]);await spaces.open("dine")
	check(game.economy.money==money and game.campaign.phase_slot()==slot,"cancel purchase confirmation never charges or passes time")
	game.economy.money=0;game.combat_rules.hero["energy_current"]=1
	check(not (await spaces.dine("rice_meal",true))["ok"] and slot==game.campaign.phase_slot(),"insufficient funds never consumes time")
	game.economy.money=500;game.combat_rules.hero["hp_current"]=1;game.combat_rules.hero["energy_current"]=1
	answers.assign(["buy/rice_meal","yes"]);await spaces.open("dine")
	check(game.economy.money==468 and game.campaign.phase_slot()==slot+1,"actual dining menu charges correct price and exactly one period")
	check(game.combat_rules.hero["energy_current"]==1+floori(int(game.combat_rules.hero["energy"])*.26)+floori(int(game.combat_rules.hero["energy"])*.1),"meal recovery uses same item ratios plus bounded seated bonus")
	check(not game.story_system.running and not spaces.busy and not game.player.frozen,"dining completes without stuck controls")
	game.day_clock.current_period=4;slot=game.campaign.phase_slot();money=game.economy.money
	check(not (await spaces.dine("rice_meal",true))["ok"] and money==game.economy.money,"closed canteen refuses paid meal without charge")
	game.economy.add_item("bread",2);var bread: int=game.economy.quantity("bread")
	check((await spaces.dine("bread",false))["ok"] and game.economy.quantity("bread")==bread-1 and game.campaign.phase_slot()==slot+1,"packed food works after closing and consumes exactly one")
	game.day_clock.current_period=5;game.relationships.dead["cook_hu"]={};money=game.economy.money
	check(not (await spaces.dine("rice_meal",true))["ok"] and money==game.economy.money,"dead cook cannot sell a meal")
	game.relationships.dead.erase("cook_hu");game.combat_rules.refill_hero();slot=game.campaign.phase_slot()
	check(not (await spaces.dine("rice_meal",true))["ok"] and slot==game.campaign.phase_slot() and money==game.economy.money,"full recovery prevents accidental waste")
	game.player.position=game.terrain.current_scene.landing();check(not (await spaces.dine("rice_meal",true))["ok"],"remote dining rejected")
	await shot("dining")
	var saved_result: Dictionary=game.save_game_slot(4)
	check(saved_result["ok"],"new services save in existing slot format "+str(saved_result))
	if not saved_result["ok"]:game.queue_free();game=null;await frames();quit(1);return
	check(game.validate_snapshot(game.save_store.read_slot(4)["state"])["ok"],"new rooms and service events validate")
	check(game.load_game_slot(4)["ok"],"actual service save reloads")
	while game.transition_busy:await process_frame
	check(game.event_state.get("campus/dined",0)==2 and game.event_state.get("campus/slept",0)==2,"service counts persist without duplicate recovery")
	var file:=FileAccess.open(report_path,FileAccess.WRITE);file.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"mapped_buildings":game.interior_info["entrances"].size(),"rooms":room_count,"method":"Actual rooms, exits, furniture navigation, shared seated sprites, nap and overnight, midnight allowance, paid and packed dining, cancellation/funds/death/full caps, actual save and load; screenshots on desktop, no emulator."},"  "))
	print("CAMPUS_ROOMS_CHECKS ",checks," FAILURES ",failures.size());game.queue_free();game=null;await frames();quit(0 if failures.is_empty() else 1)
