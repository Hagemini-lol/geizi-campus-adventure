extends SceneTree
var game: Node2D
var checks:=0
var failures: Array[String]=[]
var desired_choice:=""
var auto_dialog:=true
var selection_sent:=false
var last_panel_id:=0
var puzzle_answers: Array[String]=[]

func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _process(_delta: float) -> bool:
	if game==null:return false
	if game.dialogue_view!=null and game.dialogue_view.visible and auto_dialog:game.dialogue_view.accept()
	if game.campaign!=null and is_instance_valid(game.campaign.panel) and game.campaign.panel.get_instance_id()!=last_panel_id:
		last_panel_id=game.campaign.panel.get_instance_id()
		var answer: String=puzzle_answers.pop_front() if not puzzle_answers.is_empty() else desired_choice
		var buttons: Array=game.campaign.panel.find_children("*","Button",true,false)
		var valid:=false
		for button: Button in buttons:
			if button.get_meta("campaign_option","")==answer:valid=true
		if not valid and not buttons.is_empty():answer=buttons[0].get_meta("campaign_option","")
		game.campaign.selected.emit(answer)
	return false

func go(location: String) -> void:
	var parts:=location.split(":")
	if parts.size()==1:
		var at: Vector2=game.campaign.outdoor_point(location)
		await game.begin_transition(game.navigation.region_at(at),at)
	else:
		var context: Dictionary={"building":parts[0],"floor":int(parts[1]),"kind":"corridor" if parts[2]=="corridor" else "classroom"}
		if context["kind"]=="classroom":context["room"]=int(parts[2])
		await game.change_interior(context)
	await process_frame
	check(game.load_error.is_empty(),"load "+location)
	check(game.campaign.location_matches(location),"location match "+location)
	var at: Vector2=game.campaign.marker_point()
	check(game.motion_navigation().walkable(at),"walkable marker "+location)
	game.player.position=at

func bridge_quest(id: String) -> void:
	var q: Dictionary=game.task_system.definitions[id]
	desired_choice="accept"
	await game.side_quests.service(q["side_story"]["owner"],id)
	check(game.task_system.entries.get(id,{}).get("status")=="active","chapter investigation accepted "+id)
	for n: int in range(q["steps"].size()):
		var step: Dictionary=q["steps"][n]
		var location: String=step.get("location",game.campaign.scheduled_location(step.get("actor","")))
		var parts:=location.split(":")
		if parts.size()==1:await game.begin_transition(game.navigation.region_at(game.campaign.outdoor_point(location)),game.campaign.outdoor_point(location))
		else:await game.change_interior({"building":parts[0],"floor":int(parts[1]),"kind":"corridor" if parts[2]=="corridor" else "classroom","room":-1 if parts[2]=="corridor" else int(parts[2])})
		while game.transition_busy:await process_frame
		desired_choice="right"
		puzzle_answers.assign(preload("res://tests/puzzle_solver.gd").actions(step["puzzle"]) if step.has("puzzle") else [])
		await game.side_quests.perform_step(id,n)
		check(game.task_system.entries[id]["step"]==n+1,"chapter investigation advances "+id+"/"+str(n))
	check(game.task_system.entries[id].get("reward_claimed",false),"chapter investigation claimed once "+id)

func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.game_started=true;game.front_end.hide_title();game.gameplay_hud.show();game.story_system.stage=6;game.story_system.reward_given=true
	game.task_system.complete("part_1")
	game.combat_rules.set_hero_level(35,true)
	game.economy.money=10000;game.economy.add_item("ink_fragment",50)
	for id: String in game.combat_rules.data["skills"]:game.combat_rules.learn(id)
	var campaign: Node2D=game.campaign
	check(campaign.valid_snapshot(campaign.snapshot()),"fresh campaign state valid")
	var invalid: Dictionary=campaign.snapshot();invalid["flags"]["RP_H"]=-1
	check(not campaign.valid_snapshot(invalid),"reject invalid route points")
	var old: Dictionary={"version":1,"stage":6,"reward_given":true,"leave_permission":false}
	check(game.story_system.valid_snapshot(old),"old chapter-one saves remain valid")
	check(campaign.data["nodes"].size()==33,"all 33 story events configured")
	var choices: Dictionary={"entry":"trust","li_start":"help","li_hearing":"submit","yang_start":"help","yang_hearing":"submit","rune":"32","grid":"safe","exam":"study","route":"H","ending":"seal"}
	for expected: int in range(33):
		var node: Dictionary=campaign.current()
		print("CAMPAIGN_TEST_EVENT ",node["id"])
		check(campaign.index==expected,"ordered event "+str(expected))
		game.economy.day_serial=maxi(game.economy.day_serial,int(node.get("min_day",0)))
		game.economy.last_allowance_day=game.economy.day_serial
		game.day_clock.current_period=int(node["timeWindow"][0]);campaign.last_slot=-1
		if node["id"]=="li_hearing":campaign.evidence["li"]=["lao_chou","lao_li","la_jiao"]
		if node["id"]=="yang_hearing":campaign.evidence["yang"]=["lao_chou","lao_li","fei_yan"]
		if node.has("bridge_quest"):await bridge_quest(node["bridge_quest"])
		game.day_clock.current_period=int(node["timeWindow"][0]);campaign.last_slot=-1
		await go(node["location"])
		check(not campaign.extra_interactions().is_empty(),"main interaction "+node["id"])
		var guard:=0
		while campaign.index==expected and guard<12:
			guard+=1;desired_choice=choices.get(node.get("choice",""),"ask")
			game.combat_rules.refill_hero()
			await campaign.run_event()
			var turns:=0
			while game.battle_view.visible and turns<25:
				turns+=1
				if not game.battle_view.result.is_empty():
					desired_choice="ask";game.battle_view.close();await process_frame;break
				var skill: String="physical"
				var view: Control=game.battle_view
				var hero: Dictionary=game.combat_rules.hero
				var counters: Array=view.tactics.intent.get("counters",[])
				var element: String=counters[0] if not counters.is_empty() else "fire"
				if float(hero["hp_current"])/int(hero["hp"])<.55 and int(view.cooldowns.get("second_wind",0))<=view.turn and int(hero["mp_current"])>=int(view.action_map["second_wind"].get("mp_cost",0)):skill="second_wind"
				elif int(hero["mp_current"])<game.combat_rules.spell_cost("low") and int(view.cooldowns.get("mana_cycle",0))<=view.turn:skill="mana_cycle"
				elif int(hero["mp_current"])<game.combat_rules.spell_cost("low"):skill="rest"
				else:
					for tier: String in ["super","high","medium","low"]:
						var candidate:=element+"_"+tier
						if view.action_map.has(candidate) and int(hero["mp_current"])>=int(view.action_map[candidate].get("mp_cost",0)):skill=candidate;break
				await game.battle_view.perform(skill)
			await process_frame
		check(campaign.index==expected+1,"event completed "+node["id"])
		if campaign.index!=expected+1:break
		check(campaign.valid_snapshot(campaign.snapshot()),"snapshot after "+node["id"])
	check(not campaign.ending.is_empty(),"complete gameplay reaches ending")
	var checkpoint: Dictionary=campaign.snapshot();campaign.restore(checkpoint)
	check(campaign.snapshot()==checkpoint,"campaign save round trip")
	# Decision order and independent route reachability.
	campaign.reset();campaign.flags.merge({"F_CIVILIAN_SAFE":true,"FINAL_ROUTE":"H","RP_H":80,"F_LI_PARTIAL":true,"F_YANG_REMEDIED":true},true)
	check(campaign.evaluate_ending("seal")=="GE-H","human good ending")
	campaign.flags.merge({"FINAL_ROUTE":"D","RP_D":80,"F_DONG_TRIAL":true},true)
	check(campaign.evaluate_ending("seal")=="GE-D","family good ending without other routes")
	campaign.flags.merge({"FINAL_ROUTE":"W","RP_W":80,"F_WR_CONTRACT":true},true)
	check(campaign.evaluate_ending("devour")=="GE-W","witch good ending")
	campaign.flags.merge({"F_TRUTH":true,"GOU_UNDERSTAND":4},true);game.economy.add_item("seal_shard",4)
	check(campaign.evaluate_ending("open")=="TE","true ending with three routes")
	campaign.flags["SAN"]=0;campaign.flags["BETRAY_COUNT"]=2
	check(campaign.evaluate_ending("open",true)=="BE-2","SAN override is first")
	campaign.flags["SAN"]=100
	check(campaign.evaluate_ending("open",true)=="BE-1","final defeat before betrayal")
	check(campaign.evaluate_ending("open")=="BE-4","betrayal before good endings")
	campaign.reset();campaign.flags["F_CIVILIAN_SAFE"]=true
	check(campaign.evaluate_ending("seal")=="NE","no side quests still normal ending")
	campaign.flags["FINAL_ROUTE"]="H";campaign.flags["F_CIVILIAN_SAFE"]=false
	check(campaign.evaluate_ending("seal")=="BE-3","human safety veto")
	for id: String in ["book_eater_queen","dry_branch_ancient","empty_uniform_leader","gate_entity"]:
		var enemy: Dictionary=game.combat_rules.monster_stats(id,10)
		check(game.combat_rules.damage(game.combat_rules.hero,enemy,"magic",0,"fire",100)<=floori(int(enemy["hp"])*.7),"boss shell "+id)
	var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures}
	var file:=FileAccess.open(game.package_root.path_join("runtime/campaign_checks.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("CAMPAIGN_CHECKS ",checks," FAILURES ",failures.size());quit(0 if failures.is_empty() else 1)
