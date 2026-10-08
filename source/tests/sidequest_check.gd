extends SceneTree

var game: Node2D
var checks:=0
var failures: Array[String]=[]
var answers: Array[String]=[]
var last_panel:=0
var stories: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,text: String) -> void:
	checks+=1
	if not ok:failures.append(text);push_error(text)
func _process(_delta: float) -> bool:
	if game==null:return false
	if game.dialogue_view!=null and game.dialogue_view.visible:game.dialogue_view.accept()
	if game==null:return false # Accepting the last line can finish and free the test game.
	if game.campaign!=null and game.campaign.panel!=null and game.campaign.panel.get_instance_id()!=last_panel and not answers.is_empty():
		for button: Node in game.campaign.panel.find_children("*","Button",true,false):
			if str(button.get_meta("campaign_option",""))==answers[0]:
				last_panel=game.campaign.panel.get_instance_id();answers.pop_front();button.pressed.emit();break
	return false
func transition() -> void:
	while game.transition_busy:await process_frame
	await process_frame
func visit(location: String) -> void:
	var parts:=location.split(":")
	if parts.size()==1:game.teleport_outdoor(game.campaign.outdoor_point(location))
	else:game.change_interior({"building":parts[0],"floor":int(parts[1]),"kind":"corridor" if parts[2]=="corridor" else "classroom","room":-1 if parts[2]=="corridor" else int(parts[2])})
	await transition()
func service(owner: String, id: String, accept: bool=false, extra: Array=[]) -> void:
	answers.assign(["side/"+id,"accept"] if accept else ["side/"+id]+extra if not extra.is_empty() else ["side/"+id,"right"])
	await game.campaign.npc_service(owner)
	answers.clear()
	await transition()
func finish_story(id: String, test_wrong: bool=false) -> void:
	print("SIDE_STORY_TEST ",id)
	var q: Dictionary=game.task_system.definitions[id];var owner: String=q["side_story"]["owner"]
	for material: String in ["water","ink_fragment"]:game.economy.add_item(material,5)
	await service(owner,id,true)
	check(game.task_system.entries.get(id,{}).get("status","")=="active","NPC menu accepts "+id)
	for n: int in range(q["steps"].size()):
		var step: Dictionary=q["steps"][n]
		if not str(step["event"]).begins_with("side/"):
			var enemy_id: String=str(step["event"]).trim_prefix("monster_defeated/")
			var spell: String="light_low" if enemy_id=="empty_uniform" else "fire_low" if enemy_id=="book_eater" else "lightning_low"
			var r: RefCounted=game.combat_rules;r.set_hero_level(15,true);r.learn(spell)
			for repeat: int in range(int(step.get("count",1))):
				var monster: Dictionary={"uid":"side-battle-"+str(repeat),"id":enemy_id,"level":1,"hp":r.monster_stats(enemy_id,1)["hp"]}
				game.battle_view.start({"monster":monster},"test")
				for turn: int in range(4):
					if not game.battle_view.result.is_empty():break
					await game.battle_view.perform(spell)
				check(game.battle_view.result=="victory","side combat objective requires actual victory")
				game.battle_view.close();await transition()
			continue
		var money: int=game.economy.money
		var day: int=game.economy.day_serial
		if step.has("location"):
			await visit(step["location"])
			var markers: Array=game.campaign.extra_interactions().filter(func(item: Dictionary):return item.get("action","")=="side_quest" and id in item.get("quests",[]))
			check(not markers.is_empty(),"real scene exposes side marker "+id+"/"+str(n))
			if markers.is_empty():continue
			check(game.interaction_text(markers[0]).contains("支线"),"keyboard/touch interaction describes side marker "+id)
			check(game.motion_navigation().walkable(markers[0]["at"]),"side marker reachable "+id)
			if test_wrong and step.has("correct"):
				answers.assign([id,"wrong"] if markers[0]["quests"].size()>1 else ["wrong"])
				await game.side_quests.handle(markers[0])
				check(game.task_system.entries[id]["step"]==n and game.economy.money==money,"wrong answer awards nothing "+id)
			var actions: Array=preload("res://tests/puzzle_solver.gd").actions(step["puzzle"]) if step.has("puzzle") else ["right"]
			answers.assign(([id] if markers[0]["quests"].size()>1 else [])+actions)
			await game.side_quests.handle(markers[0]);answers.clear()
		else:await service(step["actor"],id,false,preload("res://tests/puzzle_solver.gd").actions(step["puzzle"]) if step.has("puzzle") else [])
		await transition()
		check(int(game.task_system.entries[id]["step"])==n+1,"step recorded "+id+"/"+str(n))
		if n==q["steps"].size()-1:check(game.economy.money-money==int(q["side_story"]["reward"]["g"])+(game.economy.day_serial-day)*int(game.economy.data["daily_allowance"]),"exact cash settlement plus separately earned daily allowance "+id)
	check(game.task_system.entries[id].get("reward_claimed",false),"reward claimed "+id)
	var money: int=game.economy.money;var inventory: Dictionary=game.economy.inventory.duplicate(true)
	check(not game.side_quests.claim(id) and game.economy.money==money,"claim cannot pay twice "+id)
	await service(owner,id)
	check(game.economy.money==money and game.economy.inventory==inventory,"epilogue cannot duplicate rewards "+id)
	stories.append({"id":id,"steps":q["steps"].size(),"claimed":true,"g":q["side_story"]["reward"]["g"]})
func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.start_new_game();await transition();game.story_system.stage=6;game.story_system.reward_given=true;game.campaign.index=31
	var owners: Dictionary={}
	for id: String in game.side_quests.quests():
		var q: Dictionary=game.task_system.definitions[id]
		if not q["side_story"].get("daily",false):owners[q["side_story"]["owner"]]=true
		await finish_story(id,true)
	check(owners.size()==9,"nine of ten named classmates have personal stories")
	check(game.task_system.valid_snapshot(game.task_system.snapshot()),"side reward state validates")
	check(game.save_game_slot(2)["ok"],"side quests saved in actual game slot")
	var saved: Dictionary=game.task_system.snapshot();var funds: int=game.economy.money
	game.economy.money+=1000
	var loaded: Dictionary=game.load_game_slot(2);check(loaded["ok"],"actual save accepted for load: "+str(loaded));await transition()
	check(game.task_system.snapshot()==saved and game.economy.money==funds,"actual load restores claimed rewards and cash")
	check(not game.side_quests.claim("side_li_radio") and game.economy.money==funds,"load cannot pay already claimed story")
	game.economy.next_day()
	await service("lao_shuo","side_daily_cleanup",true)
	check(game.task_system.entries["side_daily_cleanup"]["status"]=="active" and game.task_system.entries["side_daily_cleanup"]["step"]==0,"daily job restarts on next actual day")
	# Full inventory defers the entire reward, including cash, atomically.
	game.task_system.complete("side_daily_cleanup");game.economy.inventory["water"]=game.economy.STACK_CAP;funds=game.economy.money
	check(not game.side_quests.claim("side_daily_cleanup") and game.economy.money==funds,"full bag retains entire pending reward")
	game.economy.inventory["water"]-=1
	check(game.side_quests.claim("side_daily_cleanup") and game.economy.money==funds+45,"deferred reward claims once after bag sorted")
	var invalid: Dictionary=game.task_system.snapshot();invalid["entries"]["side_li_radio"]["reward_claimed"]="yes"
	check(not game.task_system.valid_snapshot(invalid),"invalid reward save rejected")
	var preserved: Dictionary=game.task_system.snapshot()
	for id: String in ["side_li_radio","side_shuo_load"]:game.task_system.entries.erase(id);game.task_system.start(id)
	await visit("B04")
	var grouped: Array=game.side_quests.interactions().filter(func(item: Dictionary):return item.get("location","")=="B04")
	check(grouped.size()==1 and grouped[0]["quests"].size()==2,"same-location quests share one selectable marker")
	if not grouped.is_empty():
		answers.assign(["side_li_radio"]);await game.side_quests.handle(grouped[0])
		check(game.task_system.entries["side_li_radio"]["step"]==1 and game.task_system.entries["side_shuo_load"]["step"]==0,"group selection advances only selected quest")
	game.task_system.restore(preserved)
	var f:=FileAccess.open(game.package_root.path_join("runtime/sidequest_checks.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"classmates":owners.size(),"stories":stories,"method":"Actual NPC option/acceptance UI, location transitions and reachable quest markers, puzzle wrong/right choices, real battles, cash settlement, follow-up dialogue, save/load, daily gating and atomic overflow handling."},"  "))
	print("SIDEQUEST_CHECKS ",checks," FAILURES ",failures.size())
	game.queue_free();game=null;await process_frame;await process_frame
	quit(0 if failures.is_empty() else 1)
