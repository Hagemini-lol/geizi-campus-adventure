extends SceneTree
var game: Node2D
var checks:=0
var failures: Array[String]=[]
var began:=0
var saw_teachers:=false
var saw_transfer:=false
var saw_flash:=false
var saw_shake:=false
var saved_transfer:=false
func _initialize() -> void:began=Time.get_ticks_msec();call_deferred("run")
func _process(_delta: float) -> bool:
	if Time.get_ticks_msec()-began>90000:push_error("PHONE_CHECK_TIMEOUT");quit(1)
	if game!=null and game.dialogue_view.visible:game.dialogue_view.accept()
	if game!=null and game.phone!=null and game.phone.initiating:
		saw_teachers=saw_teachers or game.story_system.actors.size()==2
		var transfer: Node=game.get_node_or_null("ForbiddenTransfer")
		if transfer!=null:
			saw_transfer=saw_transfer or transfer.get_child_count()==10
			if not saved_transfer:saved_transfer=true;call_deferred("capture_transfer")
		saw_flash=saw_flash or game.fade.modulate.a>.3
		saw_shake=saw_shake or game.player.camera.offset.length()>1
	return false
func capture_transfer() -> void:
	await create_timer(.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(game.package_root.path_join("runtime/v15-forbidden-transfer.png"))
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames() -> void:await process_frame;await process_frame
func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game);await frames()
	game.start_new_game()
	while game.transition_busy:await process_frame
	game.story_system.stage=6;game.story_system.reward_given=true;game.campaign.index=31
	await game.change_interior({"building":"B01","floor":3,"kind":"classroom","room":0});await frames()
	var phone: Control=game.phone;var editor: RefCounted=game.world_editor
	check(phone.launcher.texture_normal!=null and phone.launcher.get_global_rect().position.x>get_root().size.x-100,"existing phone asset reused at upper right")
	phone.launcher.pressed.emit();await frames()
	check(phone.visible and phone.page=="home" and game.player.frozen,"phone launcher opens real modal and freezes world")
	check(phone.body.get_child_count()==5,"home has four app entries with no crowded cheat fields")
	phone.chat("wechat");check(phone.heading.text=="我也要玩瓦洛兰特","WeChat squad group exact requested name")
	phone.send("wechat","care");check(phone.messages["wechat"].size()==4,"squad messages and contextual NPC replies actually recorded")
	phone.chat("qq");check(phone.heading.text=="唠嗑组","QQ class group exact requested name")
	var serial: int=game.monster_world.period_serial
	phone.king_home();phone.match_round=1;phone.match_score=0;phone.king_round()
	for answer: String in ["farm","ward","retreat"]:phone.king_action(answer)
	check(phone.matches==1 and phone.last_score==3 and game.monster_world.period_serial==serial+1,"three-decision offline game takes exactly one world period")
	phone.forbidden();check(phone.page=="warning" and phone.body.get_child(0).text==phone.WARNING,"exact forbidden warning text appears")
	check(not editor.edit("money","","",9999),"editor locked before warning acceptance")
	phone.body.get_child(2).pressed.emit();await frames()
	check(phone.page=="home" and not editor.unlocked,"choosing 算了 does not unlock or run animation")
	phone.forbidden();phone.body.get_child(1).pressed.emit();await frames()
	while phone.initiating:await process_frame
	check(editor.unlocked and editor.used and phone.page=="editor" and phone.visible,"confirm runs transfer and opens actual modifier page")
	check(int(game.event_state.get("forbidden/inherited",0))==1 and game.story_system.actors.is_empty(),"power transfer once and temporary actors released")
	check(saw_teachers and saw_transfer,"both teachers appear and two beams with eight sparks visibly transfer power")
	check(saw_flash and saw_shake,"flash and camera shake occur during transition")
	check(game.get_node_or_null("ForbiddenTransfer")==null and int(game.event_state.get("forbidden/transfer_visual",0))==1,"transfer visuals released after first unlock")
	check(game.combat_rules.hero["attack"]>=500 and game.player.camera.offset==Vector2.ZERO and game.fade.modulate.a==0,"large actual power grant with flash/shake restored")
	phone.close();phone.open();phone.forbidden()
	check(phone.page=="editor" and int(game.event_state.get("forbidden/inherited",0))==1,"later app entry immediately opens editor without warning/animation")
	phone.editor("money");var controls: Dictionary=phone.inputs.values()[0]
	controls["input"].value=54321;controls["button"].pressed.emit()
	check(game.economy.money==54321,"actual nested modifier UI changes money")
	for field: String in editor.HERO_FIELDS:
		check(editor.edit("hero","",field,.5 if field.ends_with("reduction") else 123456),"all hero stat edits accepted "+field)
	check(editor.edit("hero","","hp_current",100000),"current HP editable")
	check(editor.edit("hero","","san_current",100000),"current SAN editable")
	check(editor.edit("affinity","gou_ga","bond",100) and game.relationships.bond("gou_ga")==100,"explicit cheat can override story-only affinity")
	check(not game.relationships.redemption_ready(),"numeric cheats do not silently fabricate missing story milestones")
	check(editor.edit("campaign","GOU_UNDERSTAND","",5),"plot numeric counters editable")
	check(editor.edit("item","water","",99) and game.economy.quantity("water")==99,"item quantities editable")
	check(editor.edit("monster","ink_slime","hp",999999),"monster stats editable")
	check(game.combat_rules.monster_stats("ink_slime",1)["hp"]==999999,"monster rules consume saved overrides")
	check(not editor.edit("hero","","attack",NAN),"nonfinite edit rejected")
	check(editor.valid(JSON.parse_string(JSON.stringify(editor.snapshot()))),"edit state JSON validates")
	check(phone.valid(JSON.parse_string(JSON.stringify(phone.snapshot()))),"phone history JSON validates")
	phone.editor("hero");await frames();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(game.package_root.path_join("runtime/v15-phone-editor.png"))
	phone.close();var stats: Dictionary=game.combat_rules.hero.duplicate(true)
	check(game.save_game_slot(3).get("ok",false),"high edited stats save through actual slot")
	editor.restore({});game.combat_rules.reset_hero()
	var loaded: Dictionary=game.load_game_slot(3);check(loaded.get("ok",false),"high edited stats validate independently of current game's edits: "+str(loaded))
	while game.transition_busy:await process_frame
	check(game.combat_rules.hero==stats and editor.unlocked and phone.matches==1,"power, overrides, first-use flag and minigame survive actual reload")
	phone.open();phone.forbidden();check(phone.page=="editor","reloaded first-use flag skips animation")
	phone.close();game.start_new_game()
	while game.transition_busy:await process_frame
	check(not editor.used and not editor.unlocked and editor.hero.is_empty() and phone.messages["wechat"].is_empty(),"new adventure clears cheats and phone history without editing old save")
	var report:=FileAccess.open(game.package_root.path_join("runtime/phone_checks.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures},"  "))
	print("PHONE_CHECKS ",checks," FAILURES ",failures.size());game.queue_free();game=null;await frames();quit(0 if failures.is_empty() else 1)
