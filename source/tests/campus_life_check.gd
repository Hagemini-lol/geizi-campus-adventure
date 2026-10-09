extends SceneTree
var game: Node2D
var checks:=0
var failures: Array[String]=[]
var answers: Array[String]=[]
var panel_id:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks+=1
	if not ok:failures.append(text);push_error(text)
func _process(_delta: float) -> bool:
	if game==null:return false
	if game.dialogue_view.visible:game.dialogue_view.accept()
	if game==null:return false
	if is_instance_valid(game.campaign.panel) and panel_id!=game.campaign.panel.get_instance_id() and not answers.is_empty():
		panel_id=game.campaign.panel.get_instance_id();game.campaign.selected.emit(answers.pop_front())
	return false
func visit(value: String) -> void:
	var parts:=value.split(":")
	await game.change_interior({"building":parts[0],"floor":int(parts[1]),"kind":"corridor" if parts[2]=="corridor" else "classroom","room":-1 if parts[2]=="corridor" else int(parts[2])})
	await process_frame
func actor_visit(id: String) -> void:
	for n: int in range(6):
		if not game.campus_life.location(id).is_empty():break
		game.advance_world_period()
	await visit(game.campus_life.location(id))
	check(game.terrain.current_scene.npcs.records.any(func(r: Dictionary):return r["character"]==id),"staff exists at scheduled location: "+id)
func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.start_new_game()
	while game.transition_busy:await process_frame
	var clock: RefCounted=game.day_clock
	for day: int in range(12):
		for period: int in range(5):
			check(game.DayClock.migrate_slot(day*5+period,5)==day*6+[0,1,3,4,5][period],"legacy story slot retains chronology")
	var old: Dictionary=game.campaign.snapshot();old.erase("slot_cycle");old["last_slot"]=9
	game.campaign.restore(old);check(game.campaign.last_slot==11,"old late-night lock migrates without reopening same event")
	var modern: Dictionary=game.campaign.snapshot();game.campaign.restore(JSON.parse_string(JSON.stringify(modern)))
	check(game.campaign.snapshot()==modern,"modern story slot survives JSON round trip")
	modern["slot_cycle"]=6.5;check(not game.campaign.valid_snapshot(modern),"invalid slot cycle rejected")
	game.campaign.reset()
	game.day_clock.current_period=4
	var money: int=game.economy.money
	await game.story_system.black_scene("跨日剧情测试",1)
	check(game.economy.day_serial==1 and game.economy.money==money+50 and clock.current_period==1,"story black screen crosses midnight forward and pays once")
	game.advance_world_to(1);check(game.economy.money==money+50,"same target does not pay twice")
	game.story_system.stage=6;game.story_system.reward_given=true;game.campaign.index=31
	var lunch_days:=0;var office_days:=0
	for day: int in range(60):
		game.economy.day_serial=day;game.economy.last_allowance_day=day;clock.current_period=5
		var first: String=game.campaign.scheduled_location("lao_li")
		check(first==game.campaign.scheduled_location("lao_li"),"schedule stable within period")
		if first.begins_with("B07") or first.begins_with("B08"):lunch_days+=1
		clock.current_period=1
		if game.campus_life.location("english_teacher")=="B15:1:"+str(game.campus_life.print_room):office_days+=1
	check(lunch_days>10 and lunch_days<50,"students sometimes, not always, lunch in cafeteria")
	check(office_days>5 and office_days<50,"off-duty teacher sometimes visits printing room")
	game.campaign.ao_until=100;clock.current_period=5
	check(game.campaign.scheduled_location("lao_ao")=="B01:3:0","weak Ao never sent out to eat")
	game.campaign.ao_until=0
	for spec: Array in [["B07",1,0],["B08",1,0],["B03",1,0],["B16",2,0],["B15",1,game.campus_life.print_room],["B16",1,0],["B16",1,3]]:
		clock.current_period=5;await visit("%s:%s:%s" % spec)
		var scene: Node2D=game.terrain.current_scene
		check(scene.navigation.walkable(game.player.position),"new interior has safe landing: "+str(spec))
		for portal: Dictionary in scene.portals:
			check(not scene.navigation.route(game.player.position,scene.navigation.safe_landing(portal["at"])).is_empty(),"exit is reachable: "+str(spec))
		for record: Dictionary in scene.npcs.records:
			check(scene.navigation.walkable(record["at"]),"NPC avoids furniture: "+str(spec)+record["character"])
			check(not scene.npcs.approach(record["uid"],game.player.position).is_empty(),"NPC interaction reachable: "+record["character"])
		check(game.save_game_slot(4).get("ok",false),"save new interior")
		var saved: Dictionary=game.save_store.read_slot(4)
		var checked: Dictionary=game.validate_snapshot(saved["state"])
		check(checked.get("ok",false),"new interior save validates: "+str(checked.get("error","")))
		if DisplayServer.get_name()!="headless":
			game.player.camera.position_smoothing_enabled=false;game.player.camera.zoom=Vector2.ONE*1.7;game.player.camera.reset_smoothing()
			await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(game.package_root.path_join("runtime/life-"+str(spec[0])+"-"+str(spec[1])+".png"))
	# Bathroom door, bed gaps and exit must share a navigable connected region.
	await visit("B16:2:0")
	var nav: RefCounted=game.motion_navigation()
	check(not nav.route(game.player.position,nav.safe_landing(Vector2(1235,280)*.3)).is_empty(),"private bathroom doorway is passable")
	check(not nav.walkable(Vector2(390,350)*.3),"beds block passage")
	await visit("B16:3:corridor")
	var before: Dictionary=game.interior_state.duplicate()
	game.campus_life.handle({"action":"room","room":0,"side":"front"})
	check(game.interior_state==before and not game.transition_busy,"boys cannot enter female private bedrooms")
	for key: String in game.economy.recipes:
		var recipe: Dictionary=game.economy.recipes[key]
		var cost:=int(recipe["fee"]);var resale:=0
		for id: String in recipe["ingredients"]:
			game.economy.inventory[id]=int(recipe["ingredients"][id]);cost+=maxi(int(game.economy.catalog[id]["buy_price"]),int(game.economy.catalog[id]["sell_price"]))*int(recipe["ingredients"][id])
		for id: String in recipe["outputs"]:game.economy.inventory[id]=0;resale+=int(game.economy.catalog[id]["sell_price"])*int(recipe["outputs"][id])
		check(resale<=cost,"no buy/craft/sell arbitrage: "+key)
		game.economy.money=500
		check(game.economy.craft(key)["ok"],"valid recipe succeeds: "+key)
		var inventory: Dictionary=game.economy.inventory.duplicate();money=game.economy.money
		check(not game.economy.craft(key)["ok"] and inventory==game.economy.inventory and money==game.economy.money,"missing materials preserve money and ingredients: "+key)
		for id: String in recipe["ingredients"]:game.economy.inventory[id]=int(recipe["ingredients"][id])
		for id: String in recipe["outputs"]:game.economy.inventory[id]=game.economy.STACK_CAP
		inventory=game.economy.inventory.duplicate()
		check(not game.economy.craft(key)["ok"] and inventory==game.economy.inventory,"full output preserves ingredients: "+key)
	game.economy.inventory={};game.economy.money=500
	game.story_system.stage=0;game.campaign.index=0
	for id: String in game.side_quests.quests():
		var spec: Dictionary=game.task_system.definitions[id]
		if not spec["side_story"].get("life_story",false):continue
		var owner: String=spec["side_story"]["owner"]
		await actor_visit(owner)
		var slot: int=game.campaign.phase_slot()
		answers.assign(["side/"+id,"accept"]);await game.campus_life.talk(owner)
		check(game.task_system.entries.get(id,{}).get("status","")=="active","actual staff menu accepts "+id)
		check(slot==game.campaign.phase_slot(),"acceptance does not spend time")
		for n: int in range(spec["steps"].size()):
			var step: Dictionary=spec["steps"][n]
			if step.has("periods"):
				clock.current_period=0;slot=game.campaign.phase_slot()
				await game.side_quests.perform_step(id,n)
				check(slot==game.campaign.phase_slot() and game.task_system.entries[id]["step"]==n,"wrong time keeps objective and time")
				game.advance_world_to(int(step["periods"][0]))
			if step.has("actor"):await actor_visit(step["actor"])
			else:await visit(step["location"])
			slot=game.campaign.phase_slot()
			if step.has("choices"):
				answers.assign(["cancel"]);await game.side_quests.perform_step(id,n)
				check(game.task_system.entries[id]["step"]==n and slot==game.campaign.phase_slot(),"cancel branch does not spend time or complete objective")
				answers.assign(["a"])
			game.story_system.begin_sequence();await game.side_quests.perform_step(id,n);game.story_system.end_sequence()
			check(game.task_system.entries[id]["step"]==n+1 and game.campaign.phase_slot()==slot+1,"successful story step advances exactly one period: "+id+str(n))
		check(game.task_system.entries[id].get("reward_claimed",false),"story pays final reward: "+id)
		money=game.economy.money
		check(not game.side_quests.claim(id) and game.economy.money==money,"staff story never pays twice")
	var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"lunch_sample_days":lunch_days,"print_sample_days":office_days,"staff_stories":9,"story_steps":32}
	var file:=FileAccess.open(game.package_root.path_join("runtime/campus_life_checks.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "))
	print("CAMPUS_LIFE_CHECK ",checks," FAILURES ",failures.size());game.queue_free();game=null;await process_frame;quit(0 if failures.is_empty() else 1)
