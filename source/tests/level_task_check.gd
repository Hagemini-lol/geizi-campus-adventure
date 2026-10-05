extends SceneTree

var game: Node2D
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func frames() -> void:await process_frame;await process_frame
func transition() -> void:
	var deadline:=Time.get_ticks_msec()+20000
	while game.transition_busy and Time.get_ticks_msec()<deadline:await process_frame
	check(not game.transition_busy,"scene transition completes");await physics_frame;await frames()
func click(control: Control) -> void:
	var at:=control.get_global_rect().get_center()
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=at;event.global_position=at;event.pressed=true
	root.push_input(event,true);await frames();event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()
func right_click() -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_RIGHT;event.position=Vector2(900,600);event.pressed=true
	root.push_input(event,true);await frames();event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()
func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	var folder: String=game.package_root.path_join("runtime/等级与任务预览");DirAccess.make_dir_recursive_absolute(folder)
	root.get_texture().get_image().save_png(folder.path_join(name+".png"))
func fixture_tasks() -> void:
	game.task_system.definitions["test_main"]={"id":"test_main","type":"main","title":"测试主线接口","steps":[{"hint":"测试事件累计","event":"test_event","count":2},{"hint":"测试手动推进"}]}
	game.task_system.definitions["test_side"]={"id":"test_side","type":"side","title":"测试支线接口","auto_start":true,"prerequisites":["test_main"],"steps":[{"hint":"测试后续事件","event":"test_after"}]}
	game.task_system.definitions["test_class"]={"id":"test_class","type":"side","title":"测试上课事件接口","steps":[{"hint":"测试上课通知","event":"classes_attended"}]}
	game.task_system.definitions["test_battle"]={"id":"test_battle","type":"side","title":"测试战斗事件接口","steps":[{"hint":"测试胜利通知","event":"monsters_defeated"}]}
func run() -> void:
	game=(load("res://main.tscn") as PackedScene).instantiate();root.add_child(game);await frames()
	check(game.load_error.is_empty(),"game boots with new task configuration");if not game.load_error.is_empty():quit(1);return
	game.start_new_game();await transition()
	var rules: RefCounted=game.combat_rules
	check(rules.maximum_level()==60 and rules.maximum_monster_level()==70,"hero cap 60 and boss support to 70")
	for level: int in range(61):
		var stats: Dictionary=rules.hero_stats(level)
		check(stats["level"]==level,"every legal hero level retained")
		check(stats["hp"]==floori(1000+120*pow(level,1.2)) and stats["attack"]==100+100*level,"HP and attack growth through level 60")
		check(stats["mp"]==100+20*level*level and stats["energy"]==200+100*level,"MP and energy growth through level 60")
		check(stats["san"]==floori(100+50*pow(level,.8)) and stats["magic_resistance"]==floori(10*level+10*pow(level,1.2)),"SAN and magic resistance flooring")
		check(stats["defense"]==floori(10+2*pow(level,.4)) and rules.experience_required(level)==floori(100*pow(level,1.5)),"defense and XP thresholds through level 60")
	check(rules.hero_stats(999)["level"]==60 and rules.hero_stats(-1)["level"]==0,"out-of-range hero level clamped")
	rules.data["character_profiles"]["test"]={"stats":{"attack":{"base":100,"growth":100}}}
	check(rules.character_stats("test",60)["attack"]==6100,"future character profile supports level 60");rules.data["character_profiles"].erase("test")
	rules.reset_hero();var zero: Dictionary=rules.grant_kill_experience(200)
	check(zero["gained"]==0 and int(rules.hero["level"])==1,"level-zero kill promotion retained")
	rules.set_hero_level(10,true);rules.hero["experience"]=rules.experience_required(10)-1
	rules.grant_kill_experience(1);check(int(rules.hero["level"])==11,"level 10 can advance to 11")
	rules.set_hero_level(59,true);rules.hero["experience"]=rules.experience_required(59)-1
	rules.grant_kill_experience(1);check(int(rules.hero["level"])==60,"level 59 advances to 60")
	var before: int=rules.hero["experience"];var award: Dictionary=rules.grant_kill_experience(200)
	check(int(rules.hero["level"])==60 and award["levels"]==0 and int(rules.hero["experience"])==before+12000,"level 60 cap retains earned experience")
	var snapshot: Dictionary={"hero":rules.hero.duplicate(true)}
	check(rules.valid_snapshot(snapshot),"valid level 60 save accepted");snapshot["hero"]["level"]=61
	check(not rules.valid_snapshot(snapshot),"level 61 hero save rejected")
	for id: String in rules.data["monsters"]:
		for level: int in [1,55,60,65,70]:
			var monster: Dictionary=rules.monster_stats(id,level)
			check(monster["level"]==level and monster["hp"]==floori((100+100*level)*float(rules.data["monsters"][id]["multipliers"]["hp"])),"high level monster stats remain integer and scalable")
	var world: RefCounted=game.MonsterWorld.new();world.configure(rules);world.rng.seed=123456
	var context: Dictionary={"building":"B02","floor":3,"kind":"classroom","room":0};var key: String=world.zone_key(context)
	var rule: Dictionary=world.zone_rule(context);var boss_offsets: Dictionary={}
	for hero_level: int in [0,1,5,6,10,30,59,60]:
		rules.set_hero_level(hero_level,true)
		check(world.spawn_level("normal")==maxi(1,hero_level-5) and world.spawn_level("elite")==maxi(1,hero_level),"ordinary -5 and elite same level including zero/minimum")
		for i: int in range(40):
			var level: int=world.spawn_level("boss");check(level>=hero_level+5 and level<=hero_level+10,"future boss +5 to +10 without clipping at hero cap")
			boss_offsets[level-hero_level]=true
		world.zones[key]={"monsters":[],"last_period":0}
		world.add_monster(key,rule,"normal");world.add_monster(key,rule,"elite")
		var monsters: Array=world.zones[key]["monsters"]
		check(monsters.size()==2 and monsters[0]["level"]==maxi(1,hero_level-5) and monsters[1]["level"]==maxi(1,hero_level),"real spawn records use rarity-relative level")
		check(world.valid_snapshot(world.snapshot()),"relative level spawn save is valid")
	check(boss_offsets.size()==6,"all six boss offsets supported")
	var saved_monsters: Array=world.zones[key]["monsters"].duplicate(true)
	rules.set_hero_level(20,true);world.activate(context)
	check(world.zones[key]["monsters"]==saved_monsters,"existing monster levels and HP retained after hero level changes")
	world.zones[key]["monsters"]=[];world.advance(context)
	check(world.zones[key]["monsters"][0]["level"]==15,"time-period refill uses updated hero level")
	var boss_spec: Dictionary=rules.data["monsters"]["dry_branch"].duplicate(true);boss_spec["rarity"]="boss";rules.data["monsters"]["test_boss"]=boss_spec
	rules.set_hero_level(60,true);world.zones[key]["monsters"]=[];world.add_monster(key,rule,"boss")
	check(world.zones[key]["monsters"][0]["level"] in range(65,71) and world.valid_snapshot(world.snapshot()),"future boss registry can spawn and save 65-70 level creature")
	rules.data["monsters"].erase("test_boss")
	check(world.spawn_level("normal",{"level_mode":"fixed","level":70})==70,"explicit future event fixed-level mode supported")
	rules.set_hero_level(10,true);await right_click();game.menu_view.select_tab("status");await frames()
	check(game.menu_view.visible and game.player.frozen,"actual right-click opens menu")
	check(not game.menu_view.status_label.text.contains("已满级"),"level 10 no longer shown as max level")
	check(game.menu_view.task_label.text.contains("gei子") and game.menu_view.task_label.text.contains("下一步") and not game.menu_view.task_label.text.contains("主线"),"default task guidance without new plot")
	check(game.menu_view.task_label.get_parent()==game.menu_view.status_label.get_parent() and game.menu_view.task_label.get_index()>game.menu_view.status_label.get_index(),"tasks displayed below status information")
	check(game.menu_view.task_label.get_global_rect().position.y>game.menu_view.status_label.get_global_rect().end.y,"task panel follows state visually")
	await shot("右键菜单_自由探索任务");game.close_menu()
	rules.set_hero_level(60,true);await right_click();game.menu_view.select_tab("status");await frames()
	check(game.menu_view.status_label.text.contains("等级 60") and game.menu_view.status_label.text.contains("已满级"),"level 60 state shown correctly")
	await shot("右键菜单_60级")
	fixture_tasks();check(not game.task_system.start("test_side"),"side task gated by prerequisites")
	check(game.task_system.start("test_main"),"main task can start explicitly")
	game.record_game_event("test_event");check(game.task_system.entries["test_main"]["progress"]==1,"event increments task progress")
	check(game.menu_view.task_label.text.contains("【主线】") and game.menu_view.task_label.text.contains("1/2") and not game.menu_view.task_label.text.contains("【探索】"),"visible menu updates task hint and progress without reopening")
	game.record_game_event("unrelated");check(game.task_system.entries["test_main"]["progress"]==1,"unrelated events do not advance task")
	game.close_menu();game.player.path.clear()
	check(game.save_game_slot(4).get("ok",false),"level 60 and task progress save successfully")
	var state: Dictionary=game.save_store.read_slot(4)["state"]
	game.record_game_event("test_event");check(game.task_system.entries["test_main"]["step"]==1,"event target advances to next hint")
	game.load_game_slot(4);await transition()
	check(int(rules.hero["level"])==60 and game.task_system.entries["test_main"]["progress"]==1 and int(game.event_state["test_event"])==1,"read restores level and unfinished task/event progress")
	var bad: Dictionary=state.duplicate(true);bad["quests"]["entries"]["test_main"]["step"]=99
	check(not game.validate_snapshot(bad)["ok"],"corrupt task step rejected")
	var legacy: Dictionary=state.duplicate(true);legacy.erase("quests");legacy["combat"]["hero"]=rules.hero_stats(10)
	legacy["combat"]["hero"]["experience"]=0
	for stat: String in ["hp","mp","energy","san"]:legacy["combat"]["hero"][stat+"_current"]=legacy["combat"]["hero"][stat]
	check(game.queue_restore(legacy,"旧档兼容测试")["ok"],"old save without tasks accepted");await transition()
	check(int(rules.hero["level"])==10 and game.task_system.entries.has("free_exploration") and not game.task_system.entries.has("test_main"),"old save begins exploration guidance and preserves level")
	game.load_game_slot(4);await transition();game.record_game_event("test_event");game.task_system.advance("test_main")
	check(game.task_system.entries["test_main"]["status"]=="completed" and game.task_system.entries["test_side"]["status"]=="active","manual advancement unlocks dependent side task")
	game.record_game_event("test_after");check(game.task_system.entries["test_side"]["status"]=="completed","side task event completion")
	check(not game.task_system.start("test_main") and not game.task_system.advance("test_main"),"completed tasks cannot be duplicated")
	check(game.task_system.valid_snapshot({"version":1,"entries":{"future_removed":{"status":"active","step":0,"progress":0}}}),"removed definitions can retain dormant save progress")
	game.task_system.start("test_class");game.day_clock.current_period=1
	game.change_interior({"building":"B12","floor":3,"kind":"classroom","room":0});await transition()
	game.lesson_view.open();game.lesson_view.start_lesson();await transition()
	check(game.task_system.entries["test_class"]["status"]=="completed","actual class completion publishes task event")
	game.task_system.start("test_battle");game.monster_world.reset();game.change_interior(context);await transition()
	var monsters: Node2D=game.active_monsters();var record: Dictionary=monsters.records[0]
	check(record["monster"]["level"] in [55,60],"actual lab scene uses hero-relative level at 60")
	game.battle_view.start(record,monsters.key);await frames()
	check(game.battle_view.hero_label.text.contains("已满级"),"battle UI uses new cap")
	await shot("60级战斗与怪物等级")
	var deadline:=Time.get_ticks_msec()+15000
	while game.battle_view.result.is_empty() and Time.get_ticks_msec()<deadline:
		game.battle_view.perform("physical")
		while game.battle_view.busy and Time.get_ticks_msec()<deadline:await process_frame
	check(game.battle_view.result=="victory" and game.task_system.entries["test_battle"]["status"]=="completed","real high-level battle works and publishes victory task event")
	game.battle_view.close();await frames();check(rules.hero["level"]==60,"victory respects hero cap")
	game.start_new_game();await transition()
	check(rules.hero["level"]==0 and game.task_system.entries.size()==1 and game.task_system.entries.has("free_exploration"),"new game resets task progress without deleting manual saves")
	game.toggle_menu();game.menu_view.select_tab("status");await frames()
	for resolution: int in [1,3]:
		if DisplayServer.get_name()=="headless":continue
		var values: Dictionary=game.preferences.values.duplicate();values["resolution"]=resolution;game.preferences.apply(values,false);await frames();await frames()
		check(game.menu_view.task_label.get_global_rect().size.x>200 and game.menu_view.task_label.get_global_rect().end.x<root.get_visible_rect().end.x,"task text wraps within resolution")
		await shot("任务菜单_分辨率"+str(resolution))
	check(game.terrain.get_child_count()==1,"one active scene remains")
	var report: Dictionary={"checks":checks,"passed":failures.is_empty(),"failures":failures,"hero_level_cap":60,"monster_level_cap":70,"normal_level_offset":-5,"elite_level_offset":0,"boss_level_offset":[5,10],"default_plot_added":false,"tasks_saved":true,"legacy_save_compatible":true,"task_event_hooks":["classes_attended","monsters_defeated","monster_defeated/<id>"],"task_types":["main","side","guide"]}
	var file:=FileAccess.open(game.package_root.path_join("runtime/level_task_checks.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("LEVEL_TASK_CHECK ",checks," FAILURES ",failures.size());game.queue_free();await frames();quit(0 if failures.is_empty() else 1)
