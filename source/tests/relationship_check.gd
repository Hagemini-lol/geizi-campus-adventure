extends SceneTree

var game: Node2D
var checks:=0
var failures: Array[String]=[]
var answers: Array[String]=[]
var panel_id:=0
var start_time:=0
func _initialize() -> void:start_time=Time.get_ticks_msec();call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func _process(_delta: float) -> bool:
	if Time.get_ticks_msec()-start_time>200000:push_error("RELATIONSHIP_CHECK_TIMEOUT");quit(1)
	if game==null:return false
	if game.dialogue_view.visible:game.dialogue_view.accept()
	if is_instance_valid(game.campaign.panel) and game.campaign.panel.get_instance_id()!=panel_id:
		panel_id=game.campaign.panel.get_instance_id()
		if answers.is_empty():push_error("Unexpected relationship choice");quit(1)
		else:game.campaign.selected.emit(answers.pop_front())
	return false
func person(id: String, uid: String="test") -> Dictionary:return {"character":id,"uid":uid,"name":game.npc_catalog.characters[id]["display_name"],"at":Vector2(50,150)}
func room(building: String, floor_value: int=3, index: int=0) -> void:
	await game.change_interior({"building":building,"floor":floor_value,"kind":"classroom","room":index})
	await process_frame;await process_frame
func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.game_started=true;game.front_end.hide_title();game.story_system.stage=6;game.story_system.reward_given=true;game.campaign.index=31
	game.day_clock.current_period=4;game.combat_rules.set_hero_level(35,true)
	var social: RefCounted=game.relationships
	check(social.content.get("gou_stories",[]).size()==5,"five authored Gouga relationship stories load")
	for actor: String in social.COMPANIONS+["gou_ga"]+social.ADULTS+game.npc_catalog.ORDINARY_IDS:
		check(game.npc_catalog.dialogue_portrait(actor)!=null,"every interactable role has valid portrait "+actor)
		check(not social.reaction(person(actor),"chat").is_empty(),"every role has conversation "+actor)
		check(not social.reaction(person(actor),"flirt").is_empty(),"every role has appropriate flirt response "+actor)
	check(social.bond("gou_ga")==0,"Gouga cannot gain bond through ordinary chat/flirt")
	# Personal sequels require genuine affinity; accepted quests remain playable.
	var sequel: Dictionary=game.task_system.definitions["side_fei_rehearsal"]
	game.task_system.start("side_fei_precision");game.task_system.complete("side_fei_precision")
	social.affinity["fei_yan"]=7
	check(not game.side_quests.unlocked(sequel),"personal sequel locked one point below affinity threshold")
	social.change("fei_yan",1);check(game.side_quests.unlocked(sequel),"personal sequel unlocks at exact threshold")
	game.task_system.start("side_fei_rehearsal");social.change("fei_yan",-100)
	check(game.side_quests.unlocked(sequel),"accepted side story does not softlock if affinity falls")
	game.campaign.adjust({"BOND_gou_ga":100});check(social.bond("gou_ga")==0,"old plot talk cannot bypass Gouga story-only gain")
	check(not social.gou_ready(social.next_gou_story()),"Gouga story locks before actual chapter milestone")
	var total:=0
	for row: Dictionary in social.content["gou_stories"]:
		game.campaign.done.append(row["after"])
		for flag: String in row["flags"]:game.campaign.flags[flag]=row["flags"][flag]
		game.campaign.flags["GOU_UNDERSTAND"]=4;game.economy.inventory["seal_shard"]=4
		check(social.gou_ready(row),"specific plot prerequisites unlock "+row["id"])
		var slot: int=game.monster_world.period_serial
		answers.assign(["cancel"]);await social.gou_story()
		check(social.bond("gou_ga")==total and game.monster_world.period_serial==slot,"cancel neither awards bond nor advances time "+row["id"])
		answers.assign([row["correct"]]);await social.gou_story();total+=int(row["gain"])
		check(social.bond("gou_ga")==total and game.monster_world.period_serial==slot+1,"story gain and one period only "+row["id"])
	check(social.next_gou_story().is_empty() and total==100,"all five stories end at exactly 100, cannot repeat")
	check(social.final_relief()==30 and social.redemption_ready(),"complete bond gives capped 30 percent relief and redemption conditions")
	check(game.campaign.evaluate_ending("open")=="REDEMPTION","actual ending evaluator selects redemption")
	check(game.campaign.evaluate_ending("seal")!="REDEMPTION","sealing does not accidentally redeem")
	for actor: String in social.COMPANIONS+["gou_ga"]:
		if actor!="gou_ga":social.change(actor,200)
		check(social.romance_available(person(actor)),"all named classmates including Gouga have unlocked romance "+actor)
	for actor: String in social.ADULTS:
		social.change(actor,100);check(not social.romance_available(person(actor)),"staff boundaries retained "+actor)
	social.change("wr",-50);check(not social.romance_available(person("wr")),"romance locks below threshold")
	social.change("wr",50);answers.assign(["confess"]);await social.romance(person("wr"))
	check(social.romances.get("wr")=="together","explicit confession starts relationship")
	answers.assign(["confess"]);await social.romance(person("gou_ga"))
	check(not social.romances.has("gou_ga"),"second relationship needs honest resolution of first")
	answers.assign(["end"]);await social.romance(person("wr"))
	answers.assign(["confess"]);await social.romance(person("gou_ga"))
	check(social.romances.get("gou_ga")=="together","Gouga romance independent of redemption")
	var social_save: Dictionary=JSON.parse_string(JSON.stringify(social.snapshot()))
	check(social.valid(social_save),"romance and story milestones survive JSON validation")
	social.restore(social_save);check(social.redemption_ready() and social.romances.get("gou_ga")=="together","JSON restore preserves redemption and relationship")
	var invalid: Dictionary=social_save.duplicate(true);invalid["affinity"]["gou_ga"]=101
	check(not social.valid(invalid),"invalid out-of-range affinity rejected")
	invalid=social_save.duplicate(true);invalid["romances"]["wr"]="invalid";check(not social.valid(invalid),"invalid relationship state rejected")
	# Battle changes use per-encounter copies, preserve balance definitions and save withdrawals.
	await room("B01")
	var stats: Dictionary=game.combat_rules.monster_stats("gou_ga_boss",40)
	var base: Dictionary=game.combat_rules.data["monsters"]["gou_ga_boss"]["tactics"].duplicate(true)
	game.battle_view.start({"monster":{"uid":"relief-test","id":"gou_ga_boss","level":40,"hp":stats["hp"]}},"test")
	check(is_equal_approx(game.battle_view.tactics.intent["power"],base["patterns"][0]["power"]*.7),"actual final battle power reduced by affinity")
	check(game.battle_view.tactics.spec["break_limit"]==1,"very high bond makes counter stagger easier")
	check(game.combat_rules.data["monsters"]["gou_ga_boss"]["tactics"]==base,"final battle never mutates base monster definition")
	game.battle_view.finish("escape");game.battle_view.close();await process_frame
	var experience: int=game.combat_rules.hero["experience"]
	var friend:=person("lao_li")
	check(social.start_battle(friend,false),"NPC duel starts in real battle UI")
	var hp: int=game.battle_view.enemy["hp_current"];game.campaign.ally_support(game.battle_view)
	check(game.battle_view.enemy["hp_current"]==hp,"companions never join violence against other NPCs")
	game.battle_view.finish("victory");game.battle_view.close();await process_frame
	check(social.alive("lao_li") and game.combat_rules.hero["experience"]==experience,"duel non-lethal and gives no farmable experience")
	check(social.start_battle(friend,true),"lethal NPC battle starts")
	game.battle_view.finish("victory");game.battle_view.close();await process_frame
	check(not social.alive("lao_li") and social.bond("fei_yan")==60,"murder permanently removes character and costs companions 40 bond")
	check(not game.campaign.scheduled_location("lao_li").length(),"dead NPC has no scheduled location")
	check(not social.redemption_ready(),"death prevents perfect rescue ending")
	check(social.adapt_lines([{"actor":"lao_li","text":"旧证词"}])[0]["actor"]=="system","dead speakers become clearly labelled records")
	game.sync_classroom_period();await process_frame
	check(game.terrain.current_scene.npcs.records.filter(func(r: Dictionary):return r["character"]=="lao_li").is_empty(),"dead classmate absent after NPC refresh")
	var one:=person("student_male","room-one");var two:=person("student_male","room-two")
	social.kill(one);check(not social.record_alive(one) and social.record_alive(two),"ordinary NPC death individual, not entire sprite type")
	for actor: String in ["lao_chou","lao_ao","lao_shuo"]:social.kill(person(actor))
	check(social.massacre() and game.campaign.evaluate_ending("open")=="GENOCIDE","many murders lock massacre route")
	game.campaign.ending="GENOCIDE"
	check(game.campaign.valid_snapshot(JSON.parse_string(JSON.stringify(game.campaign.snapshot()))),"negative bonds and massacre ending are valid campaign saves")
	check(social.valid(JSON.parse_string(JSON.stringify(social.snapshot()))),"death/grievance data validates after JSON roundtrip")
	check(game.side_quests.archive_available("chapter_signal"),"dead chapter giver exposes legacy investigation")
	answers.assign(["accept"]);await game.side_quests.archive_service("chapter_signal")
	check(game.task_system.entries.get("chapter_signal",{}).get("status","")=="active","dead giver's chapter investigation accepted through archive")
	# The next actor-only step is an actual archived conversation, not free completion.
	var active_id: String="chapter_signal"
	var spec: Dictionary=game.task_system.definitions[active_id]
	for n: int in range(spec["steps"].size()):
		if spec["steps"][n].get("actor","")=="lao_li":
			game.task_system.entries[active_id]["step"]=n
			check(game.side_quests.archive_available(active_id),"dead step actor can be consulted as records")
			await game.side_quests.archive_service(active_id)
			check(int(game.task_system.entries[active_id]["step"])==n+1 or game.task_system.entries[active_id]["status"]=="completed","archived step performs original task event once")
			break
	# Dead mentors cannot block mandatory medium magic or the initial awakening.
	social.kill(person("fei_yan"));game.menu_view.open_archive("fei_yan");game.economy.money=10000
	check(game.learn_skill("fire_medium","fei_yan").get("ok",false),"dead mentor's retained notes allow paid self-study")
	game.close_menu();game.story_system.stage=3;game.story_system.reward_given=false
	await game.story_system.initiation_sequence()
	check(game.story_system.stage==5 and game.story_system.reward_given and game.story_system.actors.is_empty(),"dead Feiyan initiation grants necessary progression without resurrecting actor")
	game.story_system.stage=6;game.campaign.ending="GENOCIDE"
	await room("B01")
	while game.dialogue_view.visible:await process_frame
	var saved_social: Dictionary=social.snapshot()
	check(game.save_game_slot(3).get("ok",false),"actual save accepts dead/romance/negative affinity state")
	social.restore({});check(game.load_game_slot(3).get("ok",false),"actual game load accepts relationship state")
	while game.transition_busy:await process_frame
	await process_frame;check(social.snapshot()==saved_social,"actual game reload restores all relationship and death state")
	check(game.terrain.current_scene.npcs.records.filter(func(r: Dictionary):return r["character"] in ["fei_yan","lao_li","lao_chou","lao_ao","lao_shuo"]).is_empty(),"no dead NPCs return after actual scene reload")
	var report:=FileAccess.open(game.package_root.path_join("runtime/relationship_checks.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures},"  "))
	print("RELATIONSHIP_CHECKS ",checks," FAILURES ",failures.size())
	game.queue_free();game=null;await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
