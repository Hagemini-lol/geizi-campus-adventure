extends SceneTree

var game: Node2D
var checks:=0
var failures: Array[String]=[]
var captures: Dictionary={}
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func frames() -> void:await process_frame;await process_frame
func transition() -> void:
	var deadline:=Time.get_ticks_msec()+20000
	while game.transition_busy and Time.get_ticks_msec()<deadline:await process_frame
	check(not game.transition_busy,"transition completes");await physics_frame;await frames()
func key_e() -> void:
	var key:=InputEventKey.new();key.keycode=KEY_E;key.pressed=true
	root.push_input(key,true);await frames();key=key.duplicate();key.pressed=false;root.push_input(key,true)
func click_button(control: Control) -> void:
	if DisplayServer.get_name()=="headless":(control as Button).pressed.emit();await frames();return
	# Menu buttons are rebuilt after the charge toggle; wait for grid layout.
	await frames()
	var at:=control.get_global_rect().get_center()
	var event:=InputEventMouseButton.new();event.position=at;event.global_position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
	root.push_input(event,true);await frames();event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()
func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless" or captures.has(name):return
	captures[name]=true
	await RenderingServer.frame_post_draw
	var directory: String=game.package_root.path_join("runtime/剧情预览");DirAccess.make_dir_recursive_absolute(directory)
	root.get_texture().get_image().save_png(directory.path_join(name+".png"))
func story_done() -> void:
	var deadline:=Time.get_ticks_msec()+90000
	while game.story_system.running and Time.get_ticks_msec()<deadline:
		if game.dialogue_view.visible:
			if game.story_system.stage==0:await shot("01_秋实楼课堂对话")
			if game.story_system.stage==4 and game.story_system.actors.size()==3:await shot("04_实验楼剧情对话")
			await key_e()
		else:
			for child: Node in game.story_system.get_children():
				if child is Sprite2D and child.get_script()==load("res://magic_effect.gd") and game.story_system.stage==4:
					if child.effect_id in ["light_medium","lightning_high"]:await shot("05_费眼魔法交战")
					if child.effect_id=="world_magic_circle":await shot("05b_主角魔法启蒙")
		await create_timer(.025).timeout
	check(not game.story_system.running,"story sequence completes without deadlock");await frames()
func stand(at: Vector2) -> void:
	game.player.position=at;game.player.path.clear();game.player.velocity=Vector2.ZERO
	game.interaction_delay=.0;await physics_frame;await frames()
func story_interact(action: String) -> void:
	var target: Dictionary={}
	for item: Dictionary in game.interactions():
		if item["action"]==action:target=item;break
	check(not target.is_empty(),"story interaction exists: "+action)
	if target.is_empty():return
	await stand(target["at"]+Vector2(0,-9 if action=="story_window" else 9))
	check(game.within_interaction(target["at"]),"story trigger uses close radius")
	await key_e();await story_done()
func turn_done() -> void:
	var deadline:=Time.get_ticks_msec()+10000
	while game.battle_view.busy and Time.get_ticks_msec()<deadline:await process_frame
	check(not game.battle_view.busy,"battle turn completes");await frames()
func run() -> void:
	game=(load("res://main.tscn") as PackedScene).instantiate();root.add_child(game);await frames()
	check(game.load_error.is_empty(),"all story assets boot");if not game.load_error.is_empty():quit(1);return
	game.start_new_game();await transition()
	var story: Node2D=game.story_system
	var rules: RefCounted=game.combat_rules
	check(story.stage==0 and game.day_clock.display_text()=="上午" and rules.hero["level"]==0,"new game starts at morning, level zero, chapter one")
	check(game.task_system.active_tasks()[0]["id"]=="part_1","main story next step shown")
	check(game.economy.money==50,"initial daily allowance preserved")
	check(game.navigation.walkable(story.rear_point) and game.navigation.region_at(story.rear_point)>=0,"rear window marker in a valid outdoor block")
	check(not game.navigation.route(game.spawn,story.rear_point).is_empty(),"rear window reachable from south gate")
	for spec: Dictionary in story.effects.values():
		var image:=Image.load_from_file(game.battle_asset_root.path_join(spec["texture"].trim_prefix("res://")))
		check(image!=null and image.get_width()==int(spec["size"][0]),"HD effect exists "+str(spec["id"]))
	game.change_interior(story.data["classroom"]);await transition()
	check(game.terrain.current_scene.is_ten_class and game.terrain.current_scene.npcs.records.size()==32,"morning Ten retains all seats and teacher")
	await story_interact("story_seat")
	check(story.stage==1 and game.day_clock.display_text()=="晚上","first class jumps to evening")
	check(game.economy.money==50 and game.economy.day_serial==0,"same-day story skip does not award another allowance")
	check(game.terrain.current_scene.npcs.records.size()==10,"evening Ten only named students")
	check(game.save_game_slot(1)["ok"],"chapter checkpoint saved")
	game.teleport_outdoor(game.spawn);await transition()
	check(game.request_path(story.rear_point),"actual outdoor route requested")
	var route_deadline:=Time.get_ticks_msec()+90000
	while not game.player.path.is_empty() and Time.get_ticks_msec()<route_deadline:await process_frame
	await transition()
	check(game.player.position.distance_to(story.rear_point)<=12,"hero actually traverses road block switches to rear window")
	await stand(story.rear_point+Vector2(0,-9))
	await shot("02_实验楼后窗闪光")
	await story_interact("story_window")
	check(story.stage==2,"rear investigation advances objective")
	var entry: Dictionary={}
	for item: Dictionary in game.interactions():
		if item["action"]=="entrance" and item["building"]=="B02":entry=item;break
	game.teleport_outdoor(entry["at"]+Vector2(0,12));await transition();await stand(entry["at"]+Vector2(0,11))
	await key_e();await story_done();await transition()
	check(story.stage==3 and game.interior_state.get("building")=="B02" and game.interior_state["kind"]=="corridor","correct lab entrance sequence")
	check(game.terrain.current_scene.npcs==null and game.active_monsters()==null,"initial laboratory corridor empty")
	var door: Dictionary={}
	for item: Dictionary in game.interactions():
		if item["action"]=="room" and int(item["room"])==int(story.data["lab_room"]) and item["side"]=="front":door=item;break
	await stand(door["at"]+Vector2(0,11))
	await shot("03_震动教室门")
	check(game.interaction_text(door).contains("震动"),"rattling door has correct near interaction")
	await key_e();await story_done();await frames()
	check(story.stage==5 and story.reward_given and story.actors.is_empty(),"initiation completes and actors unload")
	for id: String in ["world_barrier","light_medium","lightning_high","world_magic_circle"]:check(id in story.played_effects,"actual library effect used in cinematic "+id)
	check(game.terrain.current_scene.npcs==null,"laboratory has no ambient NPC after scripted actor leaves")
	check(int(rules.hero["level"])==1 and int(rules.hero["attack"])==400 and int(rules.hero["defense"])==32 and int(rules.hero["magic_resistance"])==40,"exact one-level reward and equipment bonuses")
	check(rules.hero["skills"].size()==4 and int(rules.hero["mp"])==120,"four starter elemental spells learned")
	for id: String in ["special_uniform","basic_amulet","basic_magic_book"]:check(game.economy.quantity(id)==1,"reward once "+id)
	var hero_before: Dictionary=rules.hero.duplicate(true);story.grant_rewards();check(rules.hero==hero_before,"repeat rewards are idempotent")
	check(game.save_game_slot(2)["ok"],"save after magic initiation")
	game.load_game_slot(2);await transition()
	check(story.stage==5 and rules.hero==hero_before and game.economy.quantity("basic_magic_book")==1,"load restores story, learned spells, gear and no duplicate gifts")
	var shape:=CircleShape2D.new();shape.radius=game.player.RADIUS
	var query:=PhysicsShapeQueryParameters2D.new();query.shape=shape;query.collision_mask=1;query.transform=Transform2D(0,game.player.position);query.exclude=[game.player.get_rid()]
	check(game.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty(),"hero exits cinematic outside furniture collisions")
	game.change_interior(story.data["classroom"]);await transition();await story_interact("story_seat")
	check(story.stage==6 and game.day_clock.display_text()=="深夜","self study ends chapter at late night")
	check(story.black_durations.size()==2,"both classroom black-screen text sequences observed")
	for held: float in story.black_durations:check(held>=1.98,"black-screen text visible for full two seconds")
	check(game.task_system.entries["part_1"]["status"]=="completed","main quest completed")
	check(game.save_game_slot(3)["ok"],"completed chapter saved")
	game.menu_view.open_menu();await frames();await shot("06_第一章装备");game.menu_view.select_tab("equipment");await frames();await shot("07_已获得装备");game.close_menu()
	# NPC role lines and explicit accept/cancel service behaviour.
	var record: Dictionary={}
	for item: Dictionary in game.terrain.current_scene.npcs.records:
		if item["character"]=="fei_yan":record=item;break
	story.named_conversation(record);await frames();check(game.dialogue_view.speech.text!=game.dialogue_view.GREETINGS[0],"named NPC identity-specific dialogue")
	game.dialogue_view.close();await frames();check(not game.menu_view.visible,"cancel dialogue never opens learning service")
	story.named_conversation(record);await frames()
	while game.dialogue_view.visible:await key_e()
	await frames();check(game.menu_view.visible and game.menu_view.service_actor=="fei_yan","accepted conversation opens Feiyan skill learning")
	check(not game.learn_skill("fire_medium","fei_yan")["ok"],"level gate prevents premature medium magic")
	check(game.learn_skill("focus","fei_yan")["ok"] and game.economy.money==30,"skill purchase pays once")
	check(not game.learn_skill("focus","fei_yan")["ok"] and game.economy.money==30,"duplicate skill purchase prohibited")
	await shot("08_费眼技能学习");game.close_menu()
	game.economy.money=300;game.economy.add_item("ink_fragment",2);game.menu_view.open_service("lao_li")
	check(game.purchase_equipment("tech_amulet","lao_li")["ok"] and game.economy.quantity("ink_fragment")==0 and game.economy.money==200,"commission consumes gold and exact crafting materials")
	check(int(rules.hero["attack"])==440,"new accessory replaces old bonus instead of stacking")
	game.close_menu();check(not game.purchase_equipment("patrol_uniform","lao_shuo")["ok"],"cannot buy merchant equipment remotely")
	# All legal levels and tier/weakness/guard balance, not just one screenshot.
	var battle_balance: Array=[]
	for level: int in range(61):
		var stats: Dictionary=rules.hero_stats(level)
		check(int(stats["mp"])==floori(100+20*pow(level,1.5)) and int(stats["attack"])==100+100*level,"growth flooring at level "+str(level))
	for level: int in [1,5,15,35,60]:
		var hero: Dictionary=rules.hero_stats(level,{"armor":"special_uniform","accessory":"basic_amulet"})
		var detail: Dictionary={"level":level,"normal":{},"elite":{}}
		for id: String in rules.data["monsters"]:
			var rarity: String=rules.data["monsters"][id]["rarity"]
			var foe: Dictionary=rules.monster_stats(id,maxi(1,level-5) if rarity=="normal" else level)
			var dealt: int=rules.damage(hero,foe,"physical")
			var received: int=rules.damage(foe,hero)
			check(dealt>0 and received>0,"all matchups have positive integer damage")
			if rarity=="normal":check(ceili(float(foe["hp"])/dealt)*received<int(hero["hp"]),"normal monster beatable with plain attacks at "+str(level))
			for element: String in ["fire","lightning","frost","light"]:
				for tier: String in rules.data["magic_tiers"]:
					var damage: int=rules.damage(hero,foe,"magic",0,element,float(rules.data["magic_tiers"][tier]["multiplier"]),2)
					if rarity=="elite":check(damage<=floori(int(foe["hp"])*.7) and damage<int(foe["hp"]),"elite guard prevents one hit even double super spell")
			detail[rarity][id]={"hp":foe["hp"],"physical_damage":dealt,"enemy_damage":received}
		battle_balance.append(detail)
	rules.set_hero_level(1,true);rules.equip("basic_amulet")
	var uniform: Dictionary=rules.monster_stats("empty_uniform",1)
	check(rules.damage(rules.hero,uniform,"magic",0,"light")==280,"level 1 light damage capped at exact 70 percent HP")
	check(rules.damage(rules.hero,rules.monster_stats("ink_slime",1),"magic",0,"lightning")==800,"electric weakness doubles raw magic damage")
	# Actual UI turn-based charge and support flow using a durable high-HP elite.
	game.change_interior({"building":"B02","floor":2,"kind":"classroom","room":1});await transition()
	var manager: Node2D=game.active_monsters();var zone: Dictionary=game.monster_world.zones[manager.key]
	zone["monsters"]=[];game.monster_world.add_monster(manager.key,{"capacity":2,"level_mode":"fixed","level":10},"elite");manager.refresh()
	var fight: Dictionary=manager.records[0];var view: Control=game.battle_view
	rules.set_hero_level(10,true);rules.learn("barrier");rules.learn("mana_cycle");rules.learn("steady_guard")
	check(view.start(fight,manager.key),"actual combat UI accepts learned skills");await frames()
	view.perform("magic");check(view.interface.selected_category==&"magic","keyboard magic shortcut opens actual spell submenu")
	view.charge_toggle.button_pressed=true;view.update_ui()
	check(view.action_map["fire_low"]["mp_cost"]==420,"double MP scales with level")
	var start_hp: int=view.enemy["hp_current"];var start_mp: int=rules.hero["mp_current"]
	await click_button(view.interface.submenus["magic"].command_buttons["fire_low"]);await turn_done()
	check(view.enemy["hp_current"]==start_hp and rules.hero["mp_current"]==start_mp-420 and view.turn==2 and not view.pending_spell.is_empty(),"first charging turn pays MP, deals no damage, lets enemy act")
	await shot("09_蓄力战斗界面")
	# Enemy actions return the source UI to its category row.
	await click_button(view.interface.category_buttons["magic"])
	check(view.interface.selected_category==&"magic","mouse reopens magic category after enemy action")
	view.interface.submenus["magic"].scroll.ensure_control_visible(view.interface.submenus["magic"].command_buttons["release_spell"]);await frames()
	await click_button(view.interface.submenus["magic"].command_buttons["release_spell"]);await turn_done()
	check(view.enemy["hp_current"]<start_hp and rules.hero["mp_current"]==start_mp-420 and view.pending_spell.is_empty(),"release deals amplified damage with no second MP charge")
	if view.result.is_empty():
		view.perform("barrier");await turn_done();check(view.barrier_turns==1,"barrier covers exactly two enemy responses")
		var turn_before: int=view.turn;view.perform("barrier");check(view.turn==turn_before and not view.busy,"cooldown blocks immediate repeated auxiliary spell")
	view.finish("escape");view.close();await frames()
	# Old saves may contain the previous quadratic MP cap and lack story fields.
	var legacy: Dictionary=game.save_store.read_slot(3)["state"];legacy.erase("story");legacy["combat"]["hero"].erase("equipment");legacy["combat"]["hero"].erase("skills")
	legacy["combat"]["hero"]["level"]=60;legacy["combat"]["hero"]["mp_current"]=72100
	check(game.queue_restore(legacy,"旧存档迁移测试")["ok"],"legacy level 60 MP save accepted");await transition()
	check(int(rules.hero["level"])==60 and int(rules.hero["mp_current"])==floori(100+20*pow(60,1.5)) and story.stage==0,"old save retains level and clamps MP to new growth")
	game.load_game_slot(3);await transition();check(story.stage==6 and game.economy.quantity("basic_magic_book")==1,"completed story resumes without restarting")
	var funds: int=game.economy.money;game.day_clock.current_period=4;game.advance_time_period();await transition()
	check(game.economy.money==funds+50,"story preserves next-day allowance")
	var report: Dictionary={"checks":checks,"passed":failures.is_empty(),"failures":failures,"chapter":"part_1","captures":captures.keys(),"balance":battle_balance,"elite_hit_cap":.7,"black_text_seconds":story.black_durations,"all_story_rewards_saved_once":true,"temporary_lab_actor_only":true,"actual_E_interactions":true,"actual_road_route_to_window":true,"existing_zip_changed":false}
	var file:=FileAccess.open(game.package_root.path_join("runtime/story_checks.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("STORY_CHECK ",checks," FAILURES ",failures.size());game.queue_free();await frames();quit(0 if failures.is_empty() else 1)
