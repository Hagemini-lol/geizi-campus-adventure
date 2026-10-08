extends SceneTree

var game: Node2D
var checks:=0
var failures: Array[String]=[]
var answer:=""
var panel_id:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _process(_delta: float) -> bool:
	if game==null:return false
	if game.dialogue_view.visible:game.dialogue_view.accept()
	if is_instance_valid(game.campaign.panel) and game.campaign.panel.get_instance_id()!=panel_id:
		panel_id=game.campaign.panel.get_instance_id();game.campaign.selected.emit(answer)
	return false
func room(building: String, floor_value: int=3, index: int=0) -> void:
	await game.change_interior({"building":building,"floor":floor_value,"kind":"classroom","room":index})
	await process_frame
func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.game_started=true;game.front_end.hide_title();game.gameplay_hud.show();game.story_system.stage=6;game.story_system.reward_given=true
	var campaign: Node2D=game.campaign
	game.day_clock.current_period=4
	# The active cast has one scheduled location, never copies across classrooms.
	for i: int in range(campaign.data["nodes"].size()):
		campaign.index=i
		var counts: Dictionary={}
		for building: String in ["B01","B05","B12"]:
			for id: String in campaign.classmates_for({"building":building,"floor":3,"room":0}):counts[id]=int(counts.get(id,0))+1
		for id: String in counts:check(counts[id]<=1,"unique scheduled classmate %d/%s" % [i,id])
		check(campaign.scheduled_location("wen_cong")=="B15:1:0","director stays in administration office")
	campaign.index=30;campaign.ao_until=game.economy.day_serial+7
	await room("B01")
	var scene: Node2D=game.terrain.current_scene
	var resting: Dictionary={}
	for record: Dictionary in scene.npcs.records:
		if record["character"]=="lao_ao":resting=record
	check(not resting.is_empty() and resting.get("seated",false),"weak Ao remains seated and visible")
	for record: Dictionary in scene.npcs.movers:check(record["character"]!="lao_ao","weak Ao cannot wander")
	scene.npcs.set_process(false)
	game.refresh_player_freeze()
	for step: int in range(450):
		scene.npcs._process(.04)
		for record: Dictionary in scene.npcs.movers:
			check(scene.navigation.walkable(record["at"]) and record["range"].has_point(record["at"]),"NPC remains in classroom and avoids furniture")
	var positions: Array=[]
	for record: Dictionary in scene.npcs.movers:positions.append(record["at"])
	game.story_system.begin_sequence()
	for i: int in range(30):scene.npcs._process(.1)
	for i: int in range(scene.npcs.movers.size()):check(scene.npcs.movers[i]["at"]==positions[i],"NPC pauses through dialogue and black transition")
	game.story_system.end_sequence()
	game.day_clock.current_period=1;game.sync_classroom_period();await process_frame
	check(scene.npcs.movers.is_empty(),"all classmates seated during morning class")
	check(scene.npcs.records.size()==32,"31 classmates plus teacher, player seat empty")
	for record: Dictionary in scene.npcs.records:
		if not record.get("teacher",false):check(record.get("seated",false) and record.get("seat_index",-1)!=scene.HERO_SEAT_INDEX,"class occupants sit in assigned seats")
	game.day_clock.current_period=4;game.economy.day_serial=campaign.ao_until;game.sync_classroom_period();await process_frame
	var recovered:=false
	for record: Dictionary in scene.npcs.movers:recovered=recovered or record["character"]=="lao_ao"
	check(recovered,"Ao resumes moving after seven days")
	campaign.index=12;await room("B06",1,0)
	check(game.terrain.current_scene.npcs!=null,"wr appears in library")
	campaign.index=13;game.sync_classroom_period()
	check(game.terrain.current_scene.npcs==null,"wr old sprite removed when story relocates her")
	await room("B06",1,1)
	check(game.terrain.current_scene.npcs!=null,"wr appears only at current basement event")
	await room("B02",1,0)
	check(game.terrain.current_scene.npcs==null,"laboratory contains no persistent NPCs")
	# Exercise services, not just flags injected by the full story traversal.
	campaign.index=29;campaign.last_slot=-1;campaign.ao_until=0
	for actor: String in ["lao_chou","lao_li","la_jiao"]:
		answer="li";await campaign.npc_service(actor)
	check(campaign.flags["F_LI_CLEAR"],"late evidence genuinely repairs Li case")
	check(game.economy.quantity("insulation_bracer")==1,"case reward awarded once")
	for actor: String in ["lao_chou","lao_li","fei_yan"]:
		answer="yang";await campaign.npc_service(actor)
	check(campaign.flags["F_YANG_CLEAR"],"late evidence genuinely repairs Yang case")
	answer="truth";await campaign.npc_service("lao_chou")
	check(not campaign.flags["F_TRUTH"],"one truth source insufficient")
	await campaign.npc_service("wr")
	check(campaign.flags["F_TRUTH"],"two independent truth sources unlock truth")
	check(campaign.valid_snapshot(campaign.snapshot()),"evidence and dynamic flags save correctly")
	var previous: int=game.economy.quantity("seal_shard")
	await campaign.npc_service("wr")
	check(game.economy.quantity("seal_shard")==previous,"same-day repeated service cannot duplicate rewards")
	# Replay deterministic plans through real battle UI with the same attainable loadout.
	var balance: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(game.package_root.path_join("runtime/expansion_checks.json")))
	var battles:=0
	for spec: Dictionary in balance["actual_ui_battle_cases"]:
		if not spec["id"] in ["book_eater_queen","dry_branch_ancient","gou_ga_boss"]:continue
		if spec["id"]=="gou_ga_boss" and int(spec["hero_level"])!=35:continue
		campaign.index=13 if spec["id"]=="book_eater_queen" else 17 if spec["id"]=="dry_branch_ancient" else 31
		campaign.flags["FINAL_ROUTE"]="H"
		campaign.support_id=spec["companion"]
		var rules: RefCounted=game.combat_rules
		rules.reset_hero();rules.set_hero_level(spec["hero_level"],true)
		rules.equip("tech_amulet" if spec["gear"]!="chapter_one" else "basic_amulet");rules.equip("patrol_uniform" if spec["gear"]!="chapter_one" else "special_uniform");rules.refill_hero()
		for id: String in rules.data["skills"]:
			if int(rules.data["skills"][id].get("level",1))<=int(spec["hero_level"]):rules.learn(id)
		var monster: Dictionary={"uid":"balance/"+str(battles),"id":spec["id"],"level":spec["enemy_level"],"hp":rules.monster_stats(spec["id"],spec["enemy_level"])["hp"]}
		check(game.battle_view.start({"monster":monster},"balance"),"actual battle opens")
		for action: String in spec["path"]:await game.battle_view.perform(action)
		check(game.battle_view.result=="victory","real UI wins at recommended level: "+str(spec))
		check(int(rules.hero["hp_current"])>0,"victory retains positive HP")
		game.battle_view.close();await process_frame;battles+=1
	var file:=FileAccess.open(game.package_root.path_join("runtime/campaign_behavior_checks.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"actual_boss_battles":battles,"motion_steps":450},"  "))
	print("CAMPAIGN_BEHAVIOR_CHECKS ",checks," FAILURES ",failures.size());quit(0 if failures.is_empty() else 1)
