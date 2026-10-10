extends "res://tests/relationship_check.gd"

var autoplay:=true
var output:=""
func _process(delta: float) -> bool:
	return super._process(delta) if autoplay else false
func frames(n: int=3) -> void:
	for i: int in range(n):await process_frame
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report-path="):output=arg.trim_prefix("--report-path=")
	game=load("res://main.tscn").instantiate();root.add_child(game);await frames()
	game.game_started=true;game.front_end.hide_title();game.story_system.stage=6;game.story_system.reward_given=true;game.campaign.index=31
	game.day_clock.current_period=4;game.combat_rules.set_hero_level(20,true)
	var rel: RefCounted=game.relationships;var social: RefCounted=rel.social
	social.grace=999999
	var profiles: Dictionary=rel.content["social"]["profiles"]
	check(profiles.size()==25,"25 personally authored social/combat archetypes")
	var cold: Array[String]=[];var attacks: Array[String]=[]
	for actor: String in profiles:
		var record: Dictionary=person("student_male" if actor=="ordinary" else actor,actor)
		var id: String=rel.identity(record)
		for pair: Array in [[-1,"cold"],[-25,"bitter"],[-60,"hostile"]]:
			rel.affinity[id]=pair[0];social.cursors.clear()
			check(social.response(record)==profiles[actor][pair[1]][0]["text"],"actual threshold chooses personal voice "+actor+"/"+pair[1])
		cold.append(social.say(record,"cold"));attacks.append(social.say(record,"attack"))
		for context: String in ["warning","victory","defeat","escape","after_apology","after_spared"]:check(not social.say(record,context).is_empty(),"authored encounter context "+actor+"/"+context)
		var combat: Dictionary=social.combat_spec(record)
		check(combat["patterns"].size()==2 and combat["patterns"].all(func(row: Dictionary):return row["power"]<=1.0 and not row["counters"].is_empty()),"bounded forecastable personal attacks "+actor)
		var npc_spec: Dictionary=game.combat_rules.data["monsters"]["ink_slime"].duplicate(true)
		npc_spec["multipliers"]={"hp":combat["hp"],"attack":combat["attack"],"defense":1,"magic_resistance":.7}
		game.combat_rules.data["monsters"]["social-balance-probe"]=npc_spec
		for level: int in [0,1,20,60]:
			var hero: Dictionary=game.combat_rules.hero_stats(level)
			for pattern: Dictionary in combat["patterns"]:
				var enemy: Dictionary=game.combat_rules.monster_stats("social-balance-probe",maxi(1,level))
				enemy["attack"]=floori(int(enemy["attack"])*float(pattern["power"]))
				var raw: int=game.combat_rules.damage(enemy,hero,pattern["kind"])
				var guarded: int=game.combat_rules.damage(enemy,hero,pattern["kind"],.5)
				check(raw>0 and raw<int(hero["hp"])*.5 and guarded<=raw,"personal attack survives at least two hits unarmored and guard respects damage floor "+actor+"/"+str(level)+"/"+str(pattern["name"]))
		game.combat_rules.data["monsters"].erase("social-balance-probe")
	var unique_cold: Dictionary={};var unique_attack: Dictionary={}
	for text: String in cold:unique_cold[text]=true
	for text: String in attacks:unique_attack[text]=true
	check(unique_cold.size()==25 and unique_attack.size()==25,"all archetypes have distinct low-bond and attack language")
	rel.affinity.clear();rel.daily.clear();social.moments.clear()
	# Every named classmate gets real confession/date/end UI and post-event dialogue.
	for actor: String in rel.COMPANIONS+["gou_ga"]:
		rel.romances.clear();rel.affinity[actor]=100;social.cursors.clear()
		var record: Dictionary=person(actor)
		answers.assign(["confess"]);await rel.romance(record)
		check(rel.romances.get(actor)=="together" and social.moments[actor]["event"]=="confessed","confession UI remembers accepted relationship "+actor)
		var line: String=rel.reaction(record,"chat")[1]["text"]
		check(line==profiles[actor]["after_confess"][0]["text"],"next real chat acknowledges confession "+actor)
		var before: int=game.monster_world.period_serial
		answers.assign(["revisit"]);await rel.romance(record)
		check(social.moments[actor]["event"]=="date" and game.monster_world.period_serial==before+1,"date remembers event and consumes one actual period "+actor)
		check(rel.reaction(record,"chat")[1]["text"]==profiles[actor]["after_date"][0]["text"],"chat reacts to completed date "+actor)
		rel.affinity[actor]=5
		check(rel.romance_available(record) and social.response_context(record)=="lover_hurt","strained lover can still discuss ending, without unconditional sweetness "+actor)
		answers.assign(["end"]);await rel.romance(record)
		check(rel.romances[actor]=="friends" and social.moments[actor]["event"]=="breakup","low-bond breakup remains reachable "+actor)
		social.cursors.clear();rel.affinity[actor]=65
		check(rel.reaction(record,"chat")[1]["text"]==profiles[actor]["after_breakup"][0]["text"],"post-breakup chat is character-specific "+actor)
		var bond: int=rel.bond(actor);rel.daily.erase(actor+"/flirt");rel.reaction(record,"flirt")
		check(rel.bond(actor)==bond,"post-breakup refusal grants no hidden flirt reward "+actor)
	rel.romances.clear();social.moments.clear();rel.affinity.clear();rel.daily.clear()
	var ordinary: Dictionary=person("student_male","first");var other: Dictionary=person("student_male","second")
	rel.affinity[rel.identity(ordinary)]=85;answers.assign(["confess"]);await rel.romance(ordinary)
	check(social.response_context(ordinary)=="after_confess" and social.response_context(other).is_empty(),"ordinary NPC event memory belongs to individual identity")
	var legacy: Dictionary=rel.snapshot();legacy.erase("moments");check(rel.valid(legacy),"pre-update saves without moments remain valid")
	rel.restore(legacy);check(social.response_context(ordinary)=="after_confess","legacy established romance derives post-confession voice without replay or reward")
	var invalid: Dictionary=rel.snapshot();invalid["moments"]={"bad":{"event":"unknown","day":0}}
	check(not rel.valid(invalid),"unknown relationship event rejected")
	invalid["moments"]["bad"]={"event":"confessed","day":-1};check(not rel.valid(invalid),"invalid memory date rejected")
	rel.restore({});social.grace=999999
	# Actual NPC roster, standing geometry and automatic warning -> combat.
	game.day_clock.current_period=4
	await room("B01");await frames();social.grace=999999
	var manager: Node2D=game.terrain.current_scene.npcs;manager.set_process(false)
	var target: Dictionary={}
	for record: Dictionary in manager.records:
		if record["character"] in rel.COMPANIONS and not record.get("seated",false) and not record.get("weak",false):target=record;break
	check(not target.is_empty(),"actual free-roaming classmate is available for hostility fixture")
	if target.is_empty():game.queue_free();game=null;await frames();quit(1);return
	var id: String=rel.identity(target);rel.affinity[id]=-60
	check(social.hostile(target),"extreme affinity alone can cause individual hostility")
	var probe: Dictionary=target.duplicate();probe["seated"]=true;check(not social.hostile(probe),"seated classroom actors never attack from baked chairs")
	probe=target.duplicate();probe["weak"]=true;check(not social.hostile(probe),"weak/resting actors do not attack")
	probe=person("lao_ao");rel.affinity["lao_ao"]=-100;game.campaign.ao_until=game.economy.day_serial+7
	check(not social.hostile(probe),"Ao seven-day recovery prevents hostility")
	game.campaign.ao_until=0;rel.affinity.erase("lao_ao")
	var nav: RefCounted=manager.scene.navigation
	for direction: Vector2 in [Vector2.DOWN,Vector2.UP,Vector2.LEFT,Vector2.RIGHT]:
		var at: Vector2=target["at"]+direction*15
		if nav.walkable(at) and nav.segment_clear(target["at"],at):game.player.position=at;break
	check(target["at"].distance_to(game.player.position)<=32 and nav.segment_clear(target["at"],game.player.position),"fixture stands in a nearby clear aisle")
	var safe_position: Vector2=game.player.position
	social.reset(0);target["path"]=PackedVector2Array();target["wait"]=0.0
	manager._process(.01)
	check(not target["path"].is_empty() and target["path"][-1].distance_to(game.player.position)<4,"hostile walking actor plans toward protagonist instead of wandering")
	var previous: Vector2=target["at"];var clear:=true
	for at: Vector2 in target["path"]:
		clear=clear and nav.walkable(at) and nav.segment_clear(previous,at);previous=at
	check(clear,"hostile chase path obeys existing furniture collision geometry")
	var wall_found:=false;var wall_from:=Vector2.ZERO;var wall_to:=Vector2.ZERO
	for obstacle: Rect2 in nav.obstacles:
		var box: Rect2=obstacle.grow(nav.CLEARANCE)
		for signs: Vector2 in [Vector2(1,1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)]:
			var corner: Vector2=Vector2(box.position.x if signs.x>0 else box.end.x,box.position.y if signs.y>0 else box.end.y)
			for radius: int in [8,12,16,20]:
				var a: Vector2=corner+Vector2(-signs.x,signs.y*radius);var b: Vector2=corner+Vector2(signs.x*radius,-signs.y)
				if nav.walkable(a) and nav.walkable(b) and not nav.segment_clear(a,b):wall_found=true;wall_from=a;wall_to=b;break
			if wall_found:break
		if wall_found:break
	check(wall_found,"geometry fixture finds nearby walkable points separated by a desk")
	if wall_found:
		var original: Array[Dictionary]=manager.records.duplicate()
		probe=target.duplicate();probe["uid"]="wall-probe";probe["at"]=wall_from;manager.records.assign([probe]);game.player.position=wall_to
		social.reset(0);social.tick(.5)
		check(social.pending_uid.is_empty() and not game.battle_view.visible,"furniture blocks proactive encounter through an obstacle")
		manager.records.assign(original);game.player.position=safe_position
	social.reset(0);social.tick(.5)
	check(social.pending_uid==target["uid"] and not game.battle_view.visible,"warning precedes automatic encounter")
	game.toggle_menu();social.tick(3);check(not game.battle_view.visible and social.pending_uid.is_empty(),"menu cancels pending threat, never opens battle over modal")
	game.close_menu();await frames();social.reset(0);social.tick(.5)
	game.player.position+=Vector2(100,0);social.scan_left=0;social.tick(.5)
	check(social.pending_uid.is_empty() and not game.battle_view.visible,"walking out of warning range prevents encounter")
	game.player.position=safe_position;social.reset(0);social.tick(.5)
	check(social.pending_uid==target["uid"],"clear aisle is rearmed before automatic process check")
	var xp: int=game.combat_rules.hero["experience"];var money: int=game.economy.money;var inventory: Dictionary=game.economy.inventory.duplicate()
	autoplay=false
	await create_timer(3.3).timeout
	check(game.battle_view.visible and game.battle_view.hostile_npc and not game.battle_view.lethal_npc,"actual game process starts nonlethal proactive encounter after warning")
	if not game.battle_view.visible:
		print("THREAT_STATE ",social.pending_uid," left ",social.warning_left," grace ",social.grace," blocked ",social.blocked()," distance ",target["at"].distance_to(game.player.position)," player ",game.player.position," target ",target["at"])
		game.queue_free();game=null;await frames();quit(1);return
	check(int(rel.daily.get(id+"/hostile",-1))==game.economy.day_serial,"encounter claims persistent per-person daily limit")
	var definition: Dictionary=game.combat_rules.data["monsters"][game.battle_view.enemy["id"]].duplicate(true)
	check(not rel.start_battle(target,false,true) and game.combat_rules.data["monsters"][game.battle_view.enemy["id"]]==definition,"second start cannot overwrite or erase active NPC definition")
	var hp: int=game.combat_rules.hero["hp_current"]
	await game.battle_view.perform("guard")
	check(game.combat_rules.hero["hp_current"]<hp and game.battle_view.turn==2,"proactive opponent deals real damage in actual combat")
	check(game.battle_view.history.any(func(line: String):return profiles[target["character"]]["attack"].any(func(row: Dictionary):return line.contains(row["text"]))),"actual enemy action logs personally authored attack language")
	var bond: int=rel.bond(id);game.battle_view.finish("victory")
	check(rel.alive(id) and rel.bond(id)==bond and game.combat_rules.hero["experience"]==xp and game.economy.money==money and game.economy.inventory==inventory,"repelling attacker neither kills nor farms affinity, XP, money or items")
	game.battle_view.close();await frames();social.tick(1)
	check(not game.battle_view.visible and social.grace>40,"post-encounter grace prevents immediate chain encounters")
	check(not social.available(target),"same actor cannot immediately challenge twice in one day")
	autoplay=true
	check(game.save_game_slot(3)["ok"],"actual save accepts new event memory and hostility cooldown")
	var saved: Dictionary=rel.snapshot();rel.restore({});check(game.load_game_slot(3)["ok"],"actual load accepts new social state")
	while game.transition_busy:await process_frame
	check(rel.snapshot()==saved and not social.available(target),"actual reload preserves memory and daily hostility limit")
	# Exercise the new hostile defeat/escape close branches, using the same
	# real opponent and battle UI rather than duplicating their implementation.
	autoplay=false
	check(rel.start_battle(target,false,true),"actual hostile re-encounter fixture can start for defeat branch")
	game.combat_rules.hero["hp_current"]=0;game.battle_view.finish("defeat")
	check(game.battle_view.history.any(func(line: String):return line.contains(profiles[target["character"]]["victory"][0]["text"])),"opponent victory uses personally authored language")
	game.battle_view.close()
	while game.transition_busy:await process_frame
	check(game.interior_state.is_empty() and game.player.position.distance_to(game.spawn)<4 and game.combat_rules.hero["hp_current"]==game.combat_rules.hero["hp"] and rel.alive(id),"actual hostile defeat exits room, restores hero and preserves NPC life")
	check(social.grace>40,"defeat teleport preserves safe grace")
	check(rel.start_battle(target,false,true),"actual hostile encounter fixture can start for escape branch")
	game.battle_view.finish("escape")
	check(game.battle_view.history.any(func(line: String):return line.contains(profiles[target["character"]]["escape"][0]["text"])),"actual escape uses personally authored language")
	game.battle_view.close();await frames()
	check(social.grace>40 and not game.battle_view.visible and rel.alive(id),"escape cleans transient battle and preserves grace and life")
	autoplay=true
	# Kill-driven route broadens resistance; affinity alone never fabricates deaths.
	check(not rel.massacre() and rel.dead.is_empty(),"extreme dislike does not fabricate murders or final massacre ending")
	for n: int in range(5):rel.kill(person("student_male","victim-"+str(n)))
	check(rel.massacre() and game.campaign.evaluate_ending("open")=="GENOCIDE","actual murders still determine existing massacre ending")
	var staff: Dictionary=person("cook_hu");check(social.hostile(staff),"low-trust civilian actively resists on massacre route")
	rel.affinity["cook_hu"]=20;check(not social.hostile(staff),"trusted actor not arbitrarily forced into hostility")
	rel.affinity["cook_hu"]=-60;check(social.hostile(staff),"very low-bond civilian also hostile outside route trust override")
	rel.dead["cook_hu"]={};check(not social.hostile(staff),"dead NPC never initiates an encounter")
	var report:=FileAccess.open(output,FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"method":"25 authored voices at exact thresholds; real confession/date/breakup UI and post-event chat, legacy and actual save/reload; real current-room NPC warning, modal and distance cancellation, autonomous battle, real guard turn and attack speech, defeat recovery and escape dialogue, daily/grace and no reward/death farming; 200 level/attack damage cases; massacre survivors and resting/dead exclusions."},"  "))
	print("SOCIAL_CHECKS ",checks," FAILURES ",failures.size());game.queue_free();game=null;await frames();quit(0 if failures.is_empty() else 1)
