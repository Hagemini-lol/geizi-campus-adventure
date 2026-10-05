extends SceneTree

var game: Node2D
var checks:=0
var failures: Array[String]=[]
var named_counts: Dictionary={}
func _initialize() -> void:call_deferred("run")
func check(value: bool, message: String) -> void:
	checks+=1
	if not value:failures.append(message);push_error(message)
func frames() -> void:
	await process_frame;await process_frame
func transition() -> void:
	var deadline:=Time.get_ticks_msec()+20000
	while game.transition_busy and Time.get_ticks_msec()<deadline:await process_frame
	check(not game.transition_busy,"scene transition finishes")
	await physics_frame;await frames()
func turn_done() -> void:
	var deadline:=Time.get_ticks_msec()+10000
	while game.battle_view.busy and Time.get_ticks_msec()<deadline:await process_frame
	check(not game.battle_view.busy,"battle turn completes");await frames()
func click(control: Control) -> void:
	if DisplayServer.get_name()=="headless":(control as Button).pressed.emit();await frames();return
	await frames()
	var at:=control.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=at;motion.global_position=at;root.push_input(motion,true)
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=at;event.global_position=at;event.pressed=true
	root.push_input(event,true);await frames();event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()
func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	var folder: String=game.terrain.asset_root.path_join("战斗与刷新预览")
	DirAccess.make_dir_recursive_absolute(folder)
	root.get_texture().get_image().save_png(folder.path_join(name+".png"))
func run() -> void:
	game=(load("res://main.tscn") as PackedScene).instantiate();root.add_child(game)
	await frames();game.start_new_game();await transition()
	var rules: RefCounted=game.combat_rules
	for level: int in range(11):
		var stats: Dictionary=rules.hero_stats(level)
		check(stats["hp"]==floori(1000+120*pow(level,1.2)),"hero hp floor level "+str(level))
		check(stats["mp"]==100+20*level*level and stats["energy"]==200+100*level,"hero mp/energy growth")
		check(stats["san"]==floori(100+50*pow(level,.8)),"hero san growth")
		check(stats["defense"]==floori(10+2*pow(level,.4)) and stats["magic_resistance"]==floori(10*level+10*pow(level,1.2)),"hero defenses growth")
		check(stats["attack"]==100+100*level and stats["penetration"]==0,"hero attack latest growth")
		for id: String in rules.data["monsters"]:
			if level==0:continue
			var monster: Dictionary=rules.monster_stats(id,level)
			var spec: Dictionary=rules.data["monsters"][id]
			for pair: Array in [["hp",100+100*level],["attack",100+100*level],["defense",10],["magic_resistance",20]]:check(monster[pair[0]]==floori(pair[1]*float(spec["multipliers"][pair[0]])),"monster integer stats "+id)
			var physical:=floori(stats["attack"]*float(level)/level*(100.0-monster["defense"])/100*(1.0-float(monster["physical_reduction"])))
			var magic:=floori(stats["attack"]*float(level)/level*(1.0-float(monster["magic_reduction"]))-monster["magic_resistance"])
			check(rules.damage(stats,monster)==maxi(stats["attack"]/10,physical),"physical damage formula")
			check(rules.damage(stats,monster,"magic")==maxi(stats["attack"]/10,magic),"magic damage formula")
	var zero: Dictionary=rules.hero_stats(0)
	for level: int in range(11):check(rules.experience_required(level)==floori(100*pow(level,1.5)),"experience threshold flooring")
	var xp: Dictionary=rules.grant_kill_experience(200)
	check(xp["gained"]==0 and rules.hero["level"]==1 and rules.hero["experience"]==0,"zero level kill promotes to one without XP")
	check(rules.hero["hp_current"]==1120 and rules.hero["attack"]==200,"level-up grows stats and resources")
	xp=rules.grant_kill_experience(200)
	check(xp["gained"]==200 and rules.hero["level"]==2 and rules.hero["experience"]==100,"kill XP uses current hero level and maximum enemy HP")
	xp=rules.grant_kill_experience(2000)
	check(xp["gained"]==4000 and int(xp["levels"])>1,"multi-level progression carries remaining XP")
	rules.set_hero_level(10,true);var xp_before: int=rules.hero["experience"]
	xp=rules.grant_kill_experience(200)
	check(rules.hero["level"]==10 and rules.hero["experience"]==xp_before+2000 and xp["levels"]==0,"maximum level ten is enforced")
	rules.reset_hero()
	var ink: Dictionary=rules.monster_stats("ink_slime",1)
	check(rules.damage(zero,ink)==10 and rules.damage(zero,ink,"magic")==10,"level zero attack has minimum damage")
	check(rules.damage(ink,zero)==180,"level zero defender safe denominator")
	var extreme:=ink.duplicate();extreme["defense"]=10000;extreme["magic_resistance"]=100000
	check(rules.damage(zero,extreme)==10 and rules.damage(zero,extreme,"magic")==10,"minimum after all mitigation")
	# Only ten named movers exist in each ten class.
	for building: String in ["B12","B05","B01"]:
		game.change_interior({"building":building,"floor":3,"kind":"classroom","room":0});await transition()
		var manager: Node2D=game.terrain.current_scene.npcs
		check(manager.records.size()==10 and manager.movers.size()==10,"only ten named students "+building)
		var seen: Dictionary={}
		for mover: Dictionary in manager.movers:
			seen[mover["character"]]=true;named_counts[mover["character"]]=int(named_counts.get(mover["character"],0))+1
			check(mover["frames"].size()==4 and mover["range"].has_point(mover["at"]),"named mover four directions and bounded spawn")
			check(not manager.approach(mover["uid"],game.player.position).is_empty(),"named NPC reachable")
		check(seen.size()==10 and manager.WALK_SPEED==12.0,"all names unique, slow motion")
		game.player.frozen=false
		for sample: int in range(100):manager._process(.05)
		for mover: Dictionary in manager.movers:check(mover["range"].has_point(mover["at"]) and game.terrain.current_scene.navigation.walkable(mover["at"]),"named movement constrained to class")
		check(manager.path_plans>0,"named movers plan paths")
		await shot(building+"_十名特殊NPC")
	for id: String in game.npc_catalog.NAMED_IDS:check(named_counts.get(id)==3,"each named NPC has exactly three class copies")
	game.change_interior({"building":"B12","floor":2,"kind":"classroom","room":0});await transition()
	check(game.terrain.current_scene.npcs.movers.is_empty(),"named NPC movement only ten class")
	# All 28 laboratory zones, architectural caps and walkable positions.
	for floor_index: int in range(1,5):
		for room: int in range(-1,6):
			var context: Dictionary={"building":"B02","floor":floor_index,"kind":"corridor" if room<0 else "classroom"}
			if room>=0:context["room"]=room
			game.change_interior(context);await transition()
			var scene: Node2D=game.terrain.current_scene
			check(scene.npcs==null,"laboratory has no NPC "+str(context))
			var monsters: Node2D=game.active_monsters()
			check(monsters!=null and monsters.records.size()==1,"initial one monster for each lab zone")
			for count: int in range(6):game.monster_world.advance(context)
			game.sync_monsters()
			check(monsters.records.size()==(3 if room<0 else 2),"strict room/corridor cap")
			for record: Dictionary in monsters.records:
				check(scene.navigation.walkable(record["at"]) and record["sprite"].texture!=null,"monster has real art and walkable position")
				check(not monsters.approach(record["uid"],game.player.position).is_empty(),"monster reachable")
	check(game.monster_world.zones.size()==28,"all laboratory zones supported")
	var context: Dictionary={"building":"B02","floor":1,"kind":"corridor"}
	game.change_interior(context);await transition()
	var uid: String=game.active_monsters().records[0]["uid"]
	game.monster_world.remove(game.monster_world.zone_key(context),uid);game.sync_monsters()
	var before: int=game.active_monsters().records.size()
	game.change_interior({"building":"B02","floor":1,"kind":"classroom","room":0});await transition()
	game.change_interior(context);await transition()
	check(game.active_monsters().records.size()==before,"reentry does not reroll or spawn")
	var serial: int=game.monster_world.period_serial
	game.time_skip_ready_at_ms=0;game.fast_forward_time();await transition()
	check(game.monster_world.period_serial==serial+1 and game.active_monsters().records.size()==3,"actual time fast-forward refreshes active scene")
	game.set_monster_region(context,{"enabled":false});check(game.active_monsters().records.is_empty(),"event can disable region")
	game.set_monster_region(context,{"enabled":true,"capacity":1,"bounds":[200,90,240,65]})
	check(game.active_monsters().records.size()==1,"event changes active region size/capacity")
	check(Rect2(200,90,240,65).has_point(game.active_monsters().records[0]["at"]),"region relocation uses updated bounds")
	game.set_monster_region(context,{"capacity":3})
	await shot("实验楼走廊刷新区")
	# Probability sample, using the actual spawn selector.
	var ordinary:=0;var elite:=0
	for sample: int in range(2000):
		game.monster_world.zones.erase("sample/1/corridor/-1")
		game.monster_world.overrides["sample/1/corridor/-1"]={"enabled":true,"capacity":1,"initial_count":1,"level":1}
		var list: Array=game.monster_world.activate({"building":"sample","floor":1,"kind":"corridor"})
		if rules.data["monsters"][list[0]["id"]]["rarity"]=="elite":elite+=1
		else:ordinary+=1
	check(absf(float(elite)/2000-.2)<.05,"initial rarity distribution 0.8/0.2")
	var timed_elites:=0
	for sample: int in range(2000):
		var key: String="sample/1/corridor/-1"
		game.monster_world.overrides[key]={"enabled":true,"capacity":3,"initial_count":0,"level":1}
		game.monster_world.zones[key]={"monsters":[],"last_period":game.monster_world.period_serial}
		game.monster_world.advance({"building":"sample","floor":1,"kind":"corridor"})
		var list: Array=game.monster_world.zones[key]["monsters"]
		check(not list.is_empty() and rules.data["monsters"][list[0]["id"]]["rarity"]=="normal","each time period creates one ordinary monster")
		if list.size()==2:timed_elites+=1;check(rules.data["monsters"][list[1]["id"]]["rarity"]=="elite","period extra monster elite")
	check(absf(float(timed_elites)/2000-.2)<.05,"period elite probability 0.2")
	game.monster_world.zones.erase("sample/1/corridor/-1");game.monster_world.overrides.erase("sample/1/corridor/-1")
	# Save and reload includes hero and population; old snapshots remain supported.
	rules.set_hero_level(3,true);rules.hero["hp_current"]=700;rules.hero["experience"]=75
	var saved: Dictionary=game.save_game_slot(1);check(saved["ok"],"combat save writes")
	var state: Dictionary=game.save_store.read_slot(1)["state"]
	check(game.validate_snapshot(state)["ok"],"combat save validates")
	var invalid:=state.duplicate(true);invalid["combat"]["hero"]["level"]=-1
	check(not game.validate_snapshot(invalid)["ok"],"invalid hero rejected")
	invalid=state.duplicate(true);invalid["combat"]["world"]["zones"].values()[0]["monsters"][0]["hp"]=-20
	check(not game.validate_snapshot(invalid)["ok"],"invalid monster rejected")
	rules.reset_hero();game.monster_world.reset()
	game.load_game_slot(1);await transition()
	check(rules.hero["level"]==3 and rules.hero["hp_current"]==700 and rules.hero["experience"]==75 and game.monster_world.zones.size()==28,"save restores hero XP and all populations")
	# Real original battle interface instantiated through the read-only adapter.
	var manager: Node2D=game.active_monsters()
	var record: Dictionary=manager.records[0]
	check(game.battle_view.start(record,manager.key),"battle opens with original UI")
	await frames()
	var view: Control=game.battle_view
	check(view.interface.category_buttons.size()==6 and view.interface.submenus.size()==6,"six original battle UI categories")
	check(view.interface.ally_slot.portrait_view.texture!=null and view.interface.enemy_slot.portrait_view.texture!=null,"real hero and monster portraits loaded")
	check(game.player.frozen and not game.gameplay_hud.visible and game.time_skip_button.disabled,"world frozen under battle")
	check(not game.save_game_slot(2)["ok"] and not game.advance_time_from_event(),"no saves or time changes during battle")
	game.toggle_menu();game.toggle_map();check(not game.menu_view.visible and not game.map_view.visible,"map/menu cannot overlay battle")
	await shot("原战斗UI_实装")
	view.perform("escape");await frames();check(view.escape_confirmation.visible,"escape requires confirm")
	var unchanged_turn: int=view.turn;view.perform("physical");check(view.turn==unchanged_turn and not view.busy,"modal confirmation blocks battle action")
	view.escape_confirmation.hide();view.finish("escape");view.close();await frames()
	check(not view.visible and not game.player.frozen and game.active_monsters().records.size()==1,"escape retains monster and resumes world")
	# Guaranteed win with a real ordinary attack and no enemy response on death.
	rules.set_hero_level(10,true)
	manager=game.active_monsters();record=manager.records[0];record["monster"]["hp"]=1
	view.start(record,manager.key);await frames()
	var hp: int=rules.hero["hp_current"]
	await click(view.interface.category_buttons["attack"]);await frames()
	check(view.interface.selected_category==&"attack","original category clickable")
	await shot("战斗攻击子菜单")
	await click(view.interface.submenus["attack"].command_buttons["physical"]);await turn_done()
	check(view.result=="victory" and rules.hero["hp_current"]==hp,"lethal attack wins before enemy response")
	await shot("战斗胜利")
	view.close();await frames();check(game.active_monsters().records.is_empty(),"defeated monster removed from map")
	# A level zero victory invokes XP settlement only once.
	game.monster_world.advance(game.interior_state);game.sync_monsters();manager=game.active_monsters();record=manager.records[0]
	rules.reset_hero();record["monster"]["hp"]=1;view.start(record,manager.key);await frames();view.perform("physical");await turn_done()
	check(view.result=="victory" and rules.hero["level"]==1 and rules.hero["experience"]==0,"real victory settles zero-level promotion")
	view.finish("victory");check(rules.hero["level"]==1 and rules.hero["experience"]==0,"victory settlement cannot be repeated")
	view.close();await frames()
	# Check MP/energy payment, resource restoration, and defeat recovery.
	game.monster_world.advance(game.interior_state);game.sync_monsters();manager=game.active_monsters()
	record=manager.records[0];record["monster"]["hp"]=rules.monster_stats(record["monster"]["id"],1)["hp"]
	rules.reset_hero();view.start(record,manager.key);await frames()
	view.perform("magic");await turn_done()
	check(rules.hero["mp_current"]==90,"magic MP cost")
	view.perform("guard");await turn_done()
	check(view.turn==3 and rules.hero["energy_current"]==200,"guard action and capped energy restoration")
	rules.hero["energy_current"]=0;rules.hero["mp_current"]=0
	view.perform("physical");check(not view.busy,"insufficient resource rejects action")
	view.perform("rest");await turn_done()
	check(rules.hero["energy_current"]==50 and rules.hero["mp_current"]==20,"rest recovers MP and energy")
	rules.hero["hp_current"]=1;view.perform("guard");await turn_done()
	check(view.result=="defeat","defeat path")
	view.close();await transition()
	check(game.interior_state.is_empty() and rules.hero["hp_current"]==1000,"defeat restores and returns south gate")
	var report: Dictionary={"checks":checks,"failures":failures,"named_copies":named_counts,"initial_normal_sample":ordinary,"initial_elite_sample":elite,"period_elite_sample":timed_elites,"pack":ProjectSettings.globalize_path("res://")}
	var file:=FileAccess.open(game.package_root.path_join("战斗与刷新验证报告.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("COMBAT_CHECK ",checks," failures=",failures.size())
	game.queue_free();await frames();quit(0 if failures.is_empty() else 1)
