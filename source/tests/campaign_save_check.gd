extends SceneTree
var game: Node2D
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func settle() -> void:
	var timeout: int=Time.get_ticks_msec()+20000
	while game.transition_busy and Time.get_ticks_msec()<timeout:await process_frame
	check(not game.transition_busy,"load finishes")
	await process_frame
func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.game_started=true;game.front_end.hide_title();game.story_system.stage=6;game.story_system.reward_given=true
	var campaign: Node2D=game.campaign
	for spec: Array in [["B06",1,1],["B15",4,0],["STORY_HOUSE",1,0],["STORY_SEAL",1,0],["B01",3,0]]:
		campaign.index=30;campaign.started_day=0;campaign.ao_until=game.economy.day_serial+7;campaign.flags["BOND_wr"]=25;campaign.flags["F_LI_PARTIAL"]=true
		game.day_clock.current_period=4
		await game.change_interior({"kind":"classroom","building":spec[0],"floor":spec[1],"room":spec[2]})
		check(game.save_game_slot(1).get("ok",false),"write new-area save "+str(spec))
		var before: Dictionary=campaign.snapshot()
		var record: Dictionary=game.save_store.read_slot(1)
		check(game.validate_snapshot(record["state"]).get("ok",false),"full save validates "+str(spec))
		campaign.reset();game.day_clock.current_period=1
		check(game.load_game_slot(1).get("ok",false),"load new-area save "+str(spec));await settle()
		check(campaign.snapshot()==before,"campaign fully restored "+str(spec))
		check(game.interior_state["building"]==spec[0] and game.terrain.get_child_count()==1,"correct single scene restored")
		if spec[0]=="B01":
			var weak:=false
			for npc: Dictionary in game.terrain.current_scene.npcs.records:
				if npc["character"]=="lao_ao":weak=npc.get("weak",false) and npc.get("seated",false)
			check(weak,"loading refreshes weak seated actor from saved story")
	var old: Dictionary=game.save_store.read_slot(1)["state"].duplicate(true)
	old["story"].erase("campaign")
	old["combat"]["hero"]["level"]=10;old["combat"]["hero"]["mp_current"]=2100
	check(game.validate_snapshot(old).get("ok",false),"old MP exponent-2 chapter-one save accepted")
	check(game.queue_restore(old,"兼容检查").get("ok",false),"old save queues");await settle()
	check(campaign.index==0 and campaign.started_day==-1,"old save starts second chapter")
	check(game.combat_rules.hero["mp_current"]==game.combat_rules.hero["mp"],"old oversized MP clamped to current maximum")
	var file:=FileAccess.open(game.package_root.path_join("runtime/campaign_save_checks.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures},"  "))
	print("CAMPAIGN_SAVE_CHECKS ",checks," FAILURES ",failures.size());quit(0 if failures.is_empty() else 1)
