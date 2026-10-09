extends SceneTree
var game: Node2D
var checks:=0
var failures: Array[String]=[]
var fixture_dir: String
const REPORT_DIR:="D:/Godot/校园自由漫游/runtime"
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func normalized(value: Variant) -> Variant:
	# JSON reads numbers as floats; compare both values after the same decoding.
	return JSON.parse_string(JSON.stringify(value))
func settle() -> void:
	var deadline:=Time.get_ticks_msec()+20000
	while game.transition_busy and Time.get_ticks_msec()<deadline:await process_frame
	check(not game.transition_busy,"transition completes")
	await physics_frame;await process_frame;await process_frame
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--fixture-dir="):fixture_dir=arg.trim_prefix("--fixture-dir=")
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	check(game.load_error.is_empty(),"updated game boots")
	if "--reader" in OS.get_cmdline_user_args():
		check(game.load_game_slot(1).get("ok",false),"continued checkpoint survives process restart")
		await settle()
		var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(REPORT_DIR.path_join("update-save-expected.json")))
		check(normalized(game.story_system.snapshot())==expected["story"],"story unchanged after restart")
		check(normalized(game.combat_rules.hero)==expected["hero"],"hero unchanged after restart")
		check(normalized(game.economy.snapshot())==expected["economy"],"inventory and money unchanged after restart")
		check(game.save_game_slot(2).get("ok",false),"resumed game can save again")
	else:
		var files:=DirAccess.get_files_at(fixture_dir)
		check(files.size()>=5,"historical checkpoint corpus present")
		for name: String in files:
			var path:=fixture_dir.path_join(name)
			var original:=FileAccess.get_sha256(path)
			var record: Dictionary=game.save_store.read_file(path)
			check(record.get("ok",false),"legacy record checksum accepted "+name)
			if not record.get("ok",false):continue
			var state: Dictionary=record["state"]
			check(game.queue_restore(state,"更新兼容检查").get("ok",false),"legacy checkpoint loads "+name)
			await settle()
			check(game.game_started and not game.player.frozen,"controls restored "+name)
			if state.has("combat"):check(int(game.combat_rules.hero["level"])==int(state["combat"]["hero"]["level"]),"saved level preserved "+name)
			if state.has("story"):check(game.story_system.stage==int(state["story"]["stage"]),"saved chapter preserved "+name)
			if state.has("economy"):check(normalized(game.economy.snapshot())==state["economy"],"old inventory money and day preserved "+name)
			if state.has("combat"):
				var saved_hero: Dictionary=state["combat"]["hero"]
				for key: String in ["experience","equipment","skills"]:
					if not saved_hero.has(key):continue
					if key=="skills":
						var earned: Array=[]
						for event_id: String in game.campaign.data.get("skill_milestones",{}):
							if event_id in game.campaign.done:earned.append_array(game.campaign.data["skill_milestones"][event_id])
						check(saved_hero[key].all(func(id: String):return id in game.combat_rules.hero["skills"]),"all old learned skills preserved "+name)
						check(game.combat_rules.hero["skills"].all(func(id: String):return id in saved_hero["skills"] or id in earned),"only already earned chapter skills added "+name)
					else:check(normalized(game.combat_rules.hero[key])==saved_hero[key],"old hero "+key+" preserved "+name)
			if state.get("story",{}).has("campaign"):
				var original_campaign: Dictionary=state["story"]["campaign"].duplicate(true)
				if original_campaign.get("saved_enemy",{}).get("id","")=="gate_entity":original_campaign["saved_enemy"]["id"]="gou_ga_boss"
				# v1.5 inserts lunch into each day while preserving old clock positions.
				if int(original_campaign.get("slot_cycle",5))==5:
					var old_slot: int=int(original_campaign["last_slot"])
					if old_slot>=0:original_campaign["last_slot"]=int(old_slot/5)*6+old_slot%5+(1 if old_slot%5>=2 else 0)
				original_campaign["slot_cycle"]=6
				original_campaign=normalized(original_campaign)
				if normalized(game.campaign.snapshot())!=original_campaign:
					for field: String in original_campaign:
						if normalized(game.campaign.snapshot().get(field))!=original_campaign[field]:print("LEGACY_DIFF ",name," ",field," expected=",original_campaign[field]," actual=",game.campaign.snapshot().get(field))
				check(normalized(game.campaign.snapshot())==original_campaign,"old campaign flags and evidence preserved "+name)
			game.interaction_delay=1000
			var before: Vector2=game.player.position
			var routed:=false
			for offset: Vector2 in [Vector2(0,10),Vector2(10,0),Vector2(-10,0),Vector2(0,-10)]:
				if not game.interior_state.is_empty() or game.navigation.region_at(before+offset)==game.terrain.current_id:
					if game.request_path(before+offset):routed=true;break
			check(routed,"continued checkpoint has free movement "+name)
			var deadline:=Time.get_ticks_msec()+3000
			while not game.player.path.is_empty() and Time.get_ticks_msec()<deadline:await physics_frame
			check(game.player.position.distance_to(before)>1,"hero actually moves after load "+name)
			game.advance_time_period();await settle()
			check(game.save_game_slot(1).get("ok",false),"continued checkpoint saves "+name)
			var expected: Dictionary={"story":game.story_system.snapshot(),"hero":game.combat_rules.hero.duplicate(true),"economy":game.economy.snapshot()}
			check(game.load_game_slot(1).get("ok",false),"continued checkpoint reloads "+name);await settle()
			check(game.story_system.snapshot()==expected["story"] and game.combat_rules.hero==expected["hero"] and game.economy.snapshot()==expected["economy"],"progress inventory and stats round trip "+name)
			check(FileAccess.get_sha256(path)==original,"legacy file never rewritten "+name)
		# Verify fallback recovery with an intentionally damaged TEST primary file.
		check(game.save_game_slot(1).get("ok",false),"second save creates recovery backup")
		var backup: Dictionary=game.save_store.read_file(game.save_store.slot_path(1)+".bak")
		check(backup.get("ok",false),"backup valid")
		FileAccess.open(game.save_store.slot_path(1),FileAccess.WRITE).store_string("damaged test primary")
		check(game.save_store.read_slot(1).get("backup",false),"damaged primary falls back to backup")
		check(game.load_game_slot(1).get("ok",false),"backup checkpoint loads");await settle()
		check(game.save_game_slot(1).get("ok",false),"backup checkpoint can be saved normally")
		FileAccess.open(REPORT_DIR.path_join("update-save-expected.json"),FileAccess.WRITE).store_string(JSON.stringify({"story":game.story_system.snapshot(),"hero":game.combat_rules.hero,"economy":game.economy.snapshot()}))
	var reader: bool="--reader" in OS.get_cmdline_user_args()
	FileAccess.open(REPORT_DIR.path_join("update_save_checks"+("_restart" if reader else "")+".json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures,"reader":reader},"  "))
	print("UPDATE_SAVE_CHECK ",checks," failures ",failures);quit(0 if failures.is_empty() else 1)
