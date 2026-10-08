extends SceneTree
var game: Node2D
var checks:=0
var failures: Array[String]=[]
var answer:=""
var panel_id:=0
var game_root:="D:/Godot/校园自由漫游"
var fixture:=""
var bundle: Dictionary={}
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func _process(_delta: float) -> bool:
	if game==null:return false
	if game.dialogue_view.visible:game.dialogue_view.accept()
	if game==null:return false
	if is_instance_valid(game.campaign.panel) and game.campaign.panel.get_instance_id()!=panel_id:
		panel_id=game.campaign.panel.get_instance_id();game.campaign.selected.emit(answer)
	return false
func write(path: String,value: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(value));f.close()
func boot() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.start_new_game()
	while game.transition_busy:await process_frame
	game.story_system.stage=6;game.story_system.reward_given=true;game.campaign.index=3
func dispose() -> void:
	game.queue_free();game=null;await process_frame;await process_frame
func enabled(value: bool) -> void:
	var manifest: Dictionary=bundle["manifest"].duplicate(true);manifest["enabled"]=value
	write(fixture.path_join("campus_example/manifest.json"),manifest)
func run() -> void:
	bundle=JSON.parse_string(FileAccess.get_file_as_string("res://mod_example.json"))
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mods-dir="):fixture=arg.trim_prefix("--mods-dir=")
	if fixture.is_empty():push_error("mod test requires isolated --mods-dir");quit(2);return
	write(fixture.path_join("campus_example/content.json"),bundle["content"])
	enabled(false)
	var loader:=preload("res://mod_loader.gd").new();loader.configure(game_root)
	check(loader.validate("campus_example",bundle["content"]).is_empty(),"example pack validates")
	check(loader.install_bundle("{}").begins_with("导入失败"),"malformed import rejected")
	check(loader.install_bundle("x".repeat(2097153)).begins_with("导入失败"),"oversized import rejected")
	var bad: Dictionary=bundle["content"].duplicate(true)
	bad["items"][0]["id"]="water";check(not loader.validate("campus_example",bad).is_empty(),"core overwrite rejected")
	bad=bundle["content"].duplicate(true);bad["items"][0]["restore_ratio"]["energy"]=2
	check(not loader.validate("campus_example",bad).is_empty(),"invalid recovery ratio rejected")
	bad=bundle["content"].duplicate(true);bad["quests"][0]["side_story"].erase("intro")
	check(not loader.validate("campus_example",bad).is_empty(),"missing dialogue contract rejected")
	bad=bundle["content"].duplicate(true);bad["quests"][0]["steps"][0]["location"]="../../outside"
	check(not loader.validate("campus_example",bad).is_empty(),"invalid location rejected")
	bad=bundle["content"].duplicate(true);bad["monsters"][0]["hp_scale"]=99
	check(not loader.validate("campus_example",bad).is_empty(),"unbounded enemy stats rejected")
	bad=bundle["content"].duplicate(true);bad["quests"][0]["side_story"]["reward"]["items"]={"missing:thing":1}
	check(not loader.validate("campus_example",bad).is_empty(),"unknown reward rejected")
	bad=bundle["content"].duplicate(true);bad["quests"][0]["prerequisites"]=["campus_example:second"]
	var second: Dictionary=bad["quests"][0].duplicate(true);second["id"]="campus_example:second";second["prerequisites"]=["campus_example:note"];bad["quests"].append(second)
	check(not loader.validate("campus_example",bad).is_empty(),"cyclic prerequisites rejected")
	check(loader.install_bundle(JSON.stringify(bundle)).contains("已安装"),"opt-in JSON installation writes validated pack")
	loader.configure(game_root)
	check("campus_example" in loader.loaded,"enabled pack actually loaded")
	check(not loader.install_bundle(JSON.stringify(bundle)).contains("已安装"),"loaded pack not silently overwritten")
	var broken_manifest: Dictionary=bundle["manifest"].duplicate(true);broken_manifest["id"]="broken";broken_manifest["order"]=200
	write(fixture.path_join("broken/manifest.json"),broken_manifest)
	write(fixture.path_join("broken/content.json"),{"items":[{"id":"broken:partial","name":"no commit","restore":{}}],"quests":["bad"]})
	var escape: Dictionary=broken_manifest.duplicate(true);escape["id"]="escape";escape["content"]="../content.json"
	write(fixture.path_join("escape/manifest.json"),escape)
	loader.configure(game_root)
	check("campus_example" in loader.loaded and not "broken" in loader.loaded and loader.issues.size()==2,"bad neighbours isolated, path escape rejected")
	check(not loader.merged["economy"]["items"].any(func(x: Dictionary):return x["id"]=="broken:partial"),"invalid pack commits no partial item")
	await boot()
	check(game.mods.loaded==["campus_example"],"production startup uses merged configurations")
	check(game.economy.catalog.has("campus_example:tea") and game.task_system.definitions.has("campus_example:note"),"production item and quest configured")
	check(game.campaign.data["nodes"][8]["dialogue"].any(func(x: Dictionary):return x["text"].contains("示例 Mod")),"event dialogue overlay reached actual campaign")
	check(game.side_quests.options_for("lao_li").any(func(x: Array):return x[0]=="side/campus_example:note"),"mod quest appears in NPC service options")
	answer="accept";await game.side_quests.service("lao_li","campus_example:note")
	var at: Vector2=game.campaign.outdoor_point("S02")
	await game.begin_transition(game.navigation.region_at(at),at)
	var markers: Array=game.side_quests.interactions()
	check(markers.size()==1 and markers[0]["quest"]=="campus_example:note","actual world quest marker exists")
	if markers.is_empty():quit(1);return
	answer="wrong";await game.side_quests.handle(markers[0]);check(game.task_system.entries["campus_example:note"]["step"]==0,"wrong mod puzzle answer makes no progress")
	answer="right";await game.side_quests.handle(markers[0])
	await game.side_quests.service("lao_li","campus_example:note")
	check(game.task_system.entries["campus_example:note"].get("reward_claimed",false) and game.economy.quantity("campus_example:tea")==2,"mod story completes and pays custom consumable once")
	game.combat_rules.hero["energy_current"]=0
	check(game.economy.use("campus_example:tea",game.combat_rules.hero)["ok"] and game.combat_rules.hero["energy_current"]>0,"mod consumable actually restores energy")
	var spec: Dictionary=game.combat_rules.monster_stats("campus_example:ink_drop",1)
	check(spec["hp"]==240 and spec["attack"]==160,"mod monster applies bounded stat multipliers")
	game.monster_world.next_uid=78;game.monster_world.zones["B02/1/corridor/-1"]={"last_period":0,"monsters":[{"uid":"77","id":"campus_example:ink_drop","level":1,"hp":240}]}
	check(game.save_game_slot(3)["ok"],"actual save with mod reward and monster written")
	await dispose();enabled(false);await boot()
	check(game.mods.loaded.is_empty(),"disabled pack not loaded")
	check(game.load_game_slot(3)["ok"],"removing pack does not invalidate actual save")
	while game.transition_busy:await process_frame
	check(game.economy.quantity("campus_example:tea")==1 and game.task_system.entries["campus_example:note"]["reward_claimed"],"removed mod inventory and progress remain dormant")
	check(game.monster_world.activate({"building":"B02","floor":1,"kind":"corridor","room":-1}).is_empty(),"unavailable monster safely hidden")
	check(game.save_game_slot(3)["ok"],"save remains writable without pack")
	await dispose();enabled(true);await boot()
	check(game.load_game_slot(3)["ok"],"actual save reloads after pack reinstalled")
	while game.transition_busy:await process_frame
	check(not game.side_quests.claim("campus_example:note"),"reinstall cannot duplicate claimed reward")
	check(game.monster_world.activate({"building":"B02","floor":1,"kind":"corridor","room":-1}).size()==1,"dormant monster restored after reinstall")
	var f:=FileAccess.open(game_root.path_join("runtime/mod_checks.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"api":1,"method":"Real startup merges, NPC options, world marker, puzzle, custom item use, monster stats, actual save/load across disable/reinstall, atomic invalid-pack isolation and import bounds."},"  "));f.close()
	print("MOD_CHECKS ",checks," FAILURES ",failures.size())
	await dispose();quit(0 if failures.is_empty() else 1)
