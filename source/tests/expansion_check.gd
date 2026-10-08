extends SceneTree

var game: Node2D
var checks:=0
var failures: Array[String]=[]
var cases: Array=[]
var auto_dialog:=true
var last_panel:=0
var capture_mode:=false

func _initialize() -> void:
	capture_mode="--capture" in OS.get_cmdline_user_args()
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func _process(_delta: float) -> bool:
	if game==null:return false
	if auto_dialog and game.dialogue_view!=null and game.dialogue_view.visible:game.dialogue_view.accept()
	return false
func shot(name: String) -> void:
	if not capture_mode:return
	for i: int in range(3):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("D:/Godot/校园自由漫游/runtime/expansion_"+name+".png")

func fight(id: String, level: int, enemy_level: int, use_burst: bool=true) -> void:
	while game.transition_busy:await process_frame
	var rules: RefCounted=game.combat_rules
	rules.reset_hero();rules.set_hero_level(level,true);rules.equip("basic_amulet");rules.equip("special_uniform");rules.refill_hero()
	var gear:="chapter_one"
	if id=="gou_ga_boss":
		rules.equip("tech_amulet");rules.equip("patrol_uniform");rules.refill_hero();gear="250g_and_2ink"
	for skill: String in rules.data["skills"]:
		if skill=="clarity" and id=="book_eater_queen":continue
		if skill in ["wind_step","resonance_break"] and id in ["book_eater_queen","dry_branch_ancient"]:continue
		if int(rules.data["skills"][skill].get("level",1))<=level:rules.learn(skill)
	game.campaign.support_id="lao_shuo" if id=="gou_ga_boss" else "fei_yan"
	game.campaign.index=31 if id=="gou_ga_boss" else 13 if id=="book_eater_queen" else 17 if id=="dry_branch_ancient" else 27
	game.campaign.flags["FINAL_ROUTE"]="H"
	# No scripted transform damage in boss balance cases: prove the full fight.
	if id=="empty_uniform_leader":game.campaign.index=26
	var stats: Dictionary=rules.monster_stats(id,enemy_level)
	var monster: Dictionary={"uid":"check-"+id,"id":id,"level":enemy_level,"hp":stats["hp"]}
	var started: bool=game.battle_view.start({"monster":monster},"test")
	check(started,"start "+id)
	if not started:return
	var view: Control=game.battle_view
	check(not view.enemy_motion.frames.is_empty(),"real animation atlas "+id)
	check(view.intent_label.text.contains("预告"),"telegraph visible "+id)
	await shot(id+"_start")
	var path: Array=[]
	for t: int in range(1,46):
		if not view.result.is_empty():break
		var action:="guard"
		var counters: Array=view.tactics.intent.get("counters",["light"])
		var element: String=counters[0] if not counters.is_empty() else "light"
		# Deterministic strategy: react to telegraphs, heal when needed, recover
		# MP under cover, then spend higher tiers in openings. No dodge luck.
		if float(rules.hero["hp_current"])/int(rules.hero["hp"])<.55 and available(view,"second_wind"):action="second_wind"
		elif int(rules.hero["mp_current"])<rules.spell_cost("low") and available(view,"mana_cycle"):action="mana_cycle"
		elif int(rules.hero["mp_current"])<rules.spell_cost("low") and available(view,"wind_step"):action="wind_step"
		elif int(rules.hero["mp_current"])<rules.spell_cost("low"):action="rest"
		elif available(view,"resonance_break") and id!="book_eater_queen" and t%3==1:action="resonance_break"
		else:
			var best_damage:=-1
			for tier: String in (["super","high","medium","low"] if use_burst and id=="gou_ga_boss" else ["low"]):
				for candidate_element: String in counters:
					var candidate:=candidate_element+"_"+tier
					if not available(view,candidate):continue
					var projected: int=rules.damage(rules.hero,view.enemy,"magic",0,candidate_element,float(rules.data["magic_tiers"][tier]["multiplier"]))
					if projected>best_damage:best_damage=projected;action=candidate
		path.append(action)
		await view.perform(action)
		if int(view.tactics.state["phase"])==2 and capture_mode:await shot(id+"_phase2")
	var won: bool=view.result=="victory"
	check(won,"win without mid-battle refill or luck %s hero %d enemy %d path %s" % [id,level,enemy_level,str(path)])
	cases.append({"id":id,"hero_level":level,"enemy_level":enemy_level,"gear":gear,"companion":game.campaign.support_id,"won":won,"turns":path.size(),"path":path,"hp":rules.hero["hp_current"],"max_hp":rules.hero["hp"],"phase":view.tactics.state["phase"]})
	await shot(id+"_end")
	if view.result.is_empty():view.finish("escape")
	view.close();await process_frame
	while game.transition_busy:await process_frame

func available(view: Control, id: String) -> bool:
	if not view.action_map.has(id) or int(view.cooldowns.get(id,0))>view.turn:return false
	var action: Dictionary=view.action_map[id]
	var hero: Dictionary=game.combat_rules.hero
	return int(hero["mp_current"])>=int(action.get("mp_cost",0)) and int(hero["energy_current"])>=int(action.get("energy_cost",0))

func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.game_started=true;game.front_end.hide_title();game.gameplay_hud.show();game.story_system.stage=6;game.story_system.reward_given=true
	check(game.load_error.is_empty(),"game loads")
	var count:=0
	for node: Dictionary in game.campaign.data["nodes"]:
		check(node.get("dialogue",[]).size()>=5,"lead-in "+node["id"])
		check(not node.get("after_dialogue",[]).is_empty(),"aftermath "+node["id"])
		count+=node["dialogue"].size()+node["after_dialogue"].size()
	check(count>=290,"full expanded campaign")
	check(game.campaign.data["nodes"][31]["battle"]==["gou_ga_boss"],"Gouga is final boss")
	# Old event indices are untouched; earned new skills are migrated on load.
	var saved: Dictionary=game.campaign.snapshot();saved["done"]=["elite_lesson","book_queen","yang_hearing","rune"]
	game.campaign.restore(saved)
	for id: String in ["second_wind","clarity","wind_step","resonance_break"]:check(id in game.combat_rules.hero["skills"],"old-save milestone "+id)
	# Tactics survive retreat, including phase and turn; the grace turn cannot
	# be reset by fleeing. All boss skills have visible elemental responses.
	var tactical:=preload("res://tactical_combat.gd").new()
	tactical.setup(game.combat_rules.data["monsters"]["gou_ga_boss"])
	var enemy: Dictionary=game.combat_rules.monster_stats("gou_ga_boss",45);enemy["hp_current"]=int(enemy["hp"])/2
	tactical.begin_turn(enemy,1)
	check(tactical.change_phase(enemy) and tactical.staggered,"phase gives grace action")
	var resumed:=preload("res://tactical_combat.gd").new();resumed.setup(game.combat_rules.data["monsters"]["gou_ga_boss"],tactical.snapshot())
	check(not resumed.change_phase(enemy) and int(resumed.state["phase"])==2,"no second grace on retreat")
	for id: String in ["book_eater_queen","dry_branch_ancient","empty_uniform_leader","gou_ga_boss"]:
		var spec: Dictionary=game.combat_rules.data["monsters"][id]
		for pattern: Dictionary in spec["tactics"]["patterns"]:
			check(not pattern["counters"].is_empty() and not pattern["hint"].is_empty(),"counterable "+pattern["name"])
	for spec: Array in [["book_eater_queen",5,8],["dry_branch_ancient",8,10],["empty_uniform_leader",12,15],["gou_ga_boss",35,45],["gou_ga_boss",45,55],["gou_ga_boss",60,70]]:
		await fight(spec[0],spec[1],spec[2])
	await check_actions()
	var f:=FileAccess.open(game.package_root.path_join("runtime/expansion_checks.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"dialogue_lines":count,"actual_ui_battle_cases":cases,"method":"Actual battle_view.perform; chapter-one gear for minibosses; purchasable tech amulet/patrol uniform (250g+2ink) and Lao Shuo for final boss. Deterministic telegraph strategy, no battle refills, no random dodge, full-health bosses, chapter-gated new skills. All tests use isolated save/settings paths."},"  "))
	print("EXPANSION_CHECKS ",checks," FAILURES ",failures.size());quit(0 if failures.is_empty() else 1)

func check_actions() -> void:
	var rules: RefCounted=game.combat_rules
	rules.reset_hero();rules.set_hero_level(35,true);rules.equip("basic_amulet");rules.equip("special_uniform");rules.refill_hero()
	for id: String in rules.data["skills"]:rules.learn(id)
	var enemy: Dictionary=rules.monster_stats("gou_ga_boss",45)
	game.campaign.index=31
	var monster: Dictionary={"uid":"actions","id":"gou_ga_boss","level":45,"hp":enemy["hp"]}
	game.battle_view.start({"monster":monster},"test")
	var v: Control=game.battle_view
	rules.hero["hp_current"]=int(rules.hero["hp"])*2/3
	var hp: int=rules.hero["hp_current"]
	await v.perform("wind_step")
	check(rules.hero["hp_current"]==hp and v.ailments.is_empty(),"wind_step guaranteed dodge and no status")
	v.ailments={"封蓝":v.turn+2,"易伤":v.turn+2};v.update_ui()
	await v.perform("clarity")
	check(v.ailments.is_empty() and v.clarity_turns==1,"clarity clears both and prevents reapply")
	var max_hp: int=rules.hero["hp"]
	rules.hero["hp_current"]=max_hp/2;hp=rules.hero["hp_current"]
	v.tactics.staggered=true # Heal in an actual break opening.
	await v.perform("second_wind")
	check(rules.hero["hp_current"]>hp and int(v.cooldowns["second_wind"])>v.turn,"healing useful and cooldown enforced")
	var damaged_hp: int=rules.hero["hp_current"]
	await v.perform("second_wind")
	check(rules.hero["hp_current"]==damaged_hp,"cannot spam cooldown skill")
	# Test charged release: exactly one MP payment and a real waiting turn.
	v.cooldowns.clear();rules.refill_hero();v.ailments.clear();v.clarity_turns=10;v.update_ui()
	var mp: int=rules.hero["mp_current"]
	v.charge_toggle.button_pressed=true;v.update_ui();var cost: int=v.action_map["fire_low"]["mp_cost"]
	await v.perform("fire_low")
	check(not v.pending_spell.is_empty() and rules.hero["mp_current"]==mp-cost,"charge waits and pays double MP once")
	mp=rules.hero["mp_current"];await v.perform("release_spell")
	check(v.pending_spell.is_empty() and rules.hero["mp_current"]==mp,"release does not repay MP")
	v.finish("escape");var snapshot: Dictionary=monster.duplicate(true);v.close();await process_frame
	game.battle_view.start({"monster":snapshot},"test")
	check(game.battle_view.turn==int(snapshot["tactics_state"]["turn"]),"retreat retains turn and tactic state")
	game.battle_view.finish("escape");game.battle_view.close()
