extends "res://tests/sidequest_check.gd"

var autoplay:=true
func _process(delta: float) -> bool:
	return super._process(delta) if autoplay else false
func slot() -> int:return game.day_clock.slot(game.economy.day_serial)
func earliest_index(id: String) -> int:
	var spec: Dictionary=game.task_system.definitions[id]
	var result: int=int(spec.get("side_story",{}).get("min_index",0))
	for prerequisite: String in spec.get("prerequisites",[]):result=maxi(result,earliest_index(prerequisite))
	return result
func mouse(at: Vector2) -> void:
	for down: bool in [true,false]:
		var event:=InputEventMouseButton.new();event.position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		root.push_input(event,true);await process_frame
func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.start_new_game();await transition();game.story_system.stage=6;game.story_system.reward_given=true;game.campaign.index=3
	check(game.task_system.definitions.size()==63,"old task IDs remain plus four optional memoirs")
	for echo: Dictionary in game.campaign.data.get("memo_echoes",[]):
		var at: int=-1
		for n: int in range(game.campaign.data["nodes"].size()):
			if game.campaign.data["nodes"][n]["id"]==echo["event"]:at=n
		check(at>=earliest_index(echo["quest"]),"memo and all prerequisites unlock before callback "+echo["event"])
		var cast: Array=game.campaign.data["nodes"][at]["cast"]
		check(echo["dialogue"].all(func(line: Dictionary):return line["actor"] in cast+["hero","system"]),"callback speakers belong to actual scene cast "+echo["event"])
	for actor: String in game.relationships.COMPANIONS:game.relationships.change(actor,20)
	check(game.side_quests.unlocked(game.task_system.definitions["memo_yang_seat"]),"first memoir opens after Yang awakening")
	check(not game.side_quests.unlocked(game.task_system.definitions["memo_yang_qq"]),"QQ memory requires the seating memory")
	check(game.campaign.memo_echo_lines("yang_frame").is_empty(),"no callback before optional memory completed")
	var before: int=slot();var cash: int=game.economy.money
	answers.assign(["later"]);await game.side_quests.service("yang_zi","memo_yang_seat");answers.clear()
	check(not game.task_system.entries.has("memo_yang_seat") and slot()==before and cash==game.economy.money,"declining memoir neither starts nor advances/rewards")
	game.campaign.index=31
	await finish_story("memo_yang_seat")
	check(slot()==before+4,"four memory steps cost four present periods, never a historical semester")
	check(not game.campaign.memo_echo_lines("yang_hearing").is_empty(),"completed seating memory echoes in hearing")
	await service("yang_zi","memo_yang_qq",true)
	var entry: Dictionary=game.task_system.entries["memo_yang_qq"]
	var old_slot: int=slot();cash=game.economy.money
	answers.assign(["submit","cancel"]);await game.side_quests.perform_step("memo_yang_qq",0);answers.clear()
	check(int(entry["step"])==0 and slot()==old_slot and game.economy.money==cash,"wrong puzzle then cancel costs no time/cash/reward")
	check(entry["puzzles"]["0"]["attempts"]==1,"wrong ordering is retained for resume")
	var saved: Dictionary=game.task_system.snapshot()
	check(game.task_system.valid_snapshot(saved),"unfinished memory puzzle validates for saves")
	game.task_system.restore(JSON.parse_string(JSON.stringify(saved)));entry=game.task_system.entries["memo_yang_qq"]
	check(entry["puzzles"]["0"]["attempts"]==1,"JSON restore retains puzzle attempts")
	game.task_system.entries.erase("memo_yang_qq")
	await finish_story("memo_yang_qq")
	check(not game.campaign.memo_echo_lines("yang_frame").is_empty(),"QQ reconstruction echoes in frame-up without advancing main index")
	await finish_story("memo_yang_industry")
	check(not game.campaign.memo_echo_lines("li_hearing").is_empty(),"reconstructed invention echoes in later hearing")
	await finish_story("memo_fei_newcomers")
	check(game.interior_state["building"]=="B07","last memoir actually takes place in cafeteria")
	check(not game.campaign.memo_echo_lines("preparation").is_empty(),"newcomer promise echoes before finale")
	check(game.campaign.index==31,"optional old stories do not alter the 33 main indices")
	# Every live-actor route is complete above; accepted work may still be read
	# if an actor dies, without resurrecting them or paying affection to a corpse.
	game.task_system.entries.erase("memo_yang_seat");game.task_system.start("memo_yang_seat")
	game.task_system.entries["memo_yang_seat"]["step"]=1
	game.relationships.dead["yang_zi"]={"character":"yang_zi","name":"阳子","scene":{},"day":0,"period":0}
	check(game.side_quests.archive_available("memo_yang_seat"),"accepted memoir has death-safe archive route")
	answers.assign(["other"]);await game.side_quests.archive_service("memo_yang_seat");answers.clear()
	check(game.task_system.entries["memo_yang_seat"]["step"]==2 and not game.relationships.alive("yang_zi"),"archive advances only the real step and leaves actor dead")
	var dead_bond: int=game.relationships.bond("yang_zi")
	await game.side_quests.perform_step("memo_yang_seat",2)
	await game.side_quests.archive_service("memo_yang_seat")
	check(game.task_system.entries["memo_yang_seat"]["status"]=="completed" and game.relationships.bond("yang_zi")==dead_bond,"completed archive pays finite materials but never raises dead owner's affection")
	game.relationships.dead.clear()
	for pair: Array in [["memo_yang_qq",1],["memo_yang_industry",3],["memo_fei_newcomers",2]]:
		var original: Dictionary=game.task_system.snapshot()
		var progress: Dictionary=game.task_system.entries[pair[0]]
		progress["status"]="active";progress["step"]=pair[1]
		var start_slot: int=slot()
		answers.assign(["cancel"]);await game.side_quests.perform_step(pair[0],pair[1]);answers.clear()
		check(progress["step"]==pair[1] and slot()==start_slot,"cancel optional branch leaves current time intact "+pair[0])
		answers.assign(["other"]);await game.side_quests.perform_step(pair[0],pair[1]);answers.clear()
		check(progress.get("decisions",{}).get(str(pair[1]),"")=="other" and slot()==start_slot+1,"alternate authored branch records choice and costs one period "+pair[0])
		game.task_system.restore(original)
	# Gift settlement, per-recipient limits, rejection and independent local NPCs.
	var rel: RefCounted=game.relationships
	for item: String in rel.content["gifts"]["items"]:check(game.economy.catalog.has(item) and not game.economy.catalog[item].get("plot_item",false),"gift is real non-plot inventory: "+item)
	game.economy.add_item("tape",3);game.economy.add_item("water",3);game.economy.add_item("concentration_candy",3);game.economy.add_item("bound_notes",3)
	var li: Dictionary={"character":"lao_li","name":"牢李"};var gou: Dictionary={"character":"gou_ga","name":"勾尬"}
	var amount: int=game.economy.quantity("tape");var bond: int=rel.bond("lao_li")
	var outcome: Dictionary=rel.give_gift(li,"tape")
	check(outcome["ok"] and outcome["gain"]==4 and game.economy.quantity("tape")==amount-1 and rel.bond("lao_li")==bond+4,"liked gift atomically consumes exactly one and grants four")
	amount=game.economy.quantity("water");bond=rel.bond("lao_li")
	check(not rel.give_gift(li,"water")["ok"] and game.economy.quantity("water")==amount and rel.bond("lao_li")==bond,"repeat gift same day consumes/grants nothing")
	check(game.save_game_slot(3)["ok"],"actual game save accepts claimed memoirs and gift cooldown")
	rel.daily.clear()
	check(game.load_game_slot(3)["ok"],"actual game reload accepts gift state")
	await transition()
	check(not rel.give_gift(li,"water")["ok"],"actual save/load cannot reset daily gift allowance")
	var snapshot: Dictionary=rel.snapshot();rel.restore(JSON.parse_string(JSON.stringify(snapshot)))
	check(not rel.give_gift(li,"water")["ok"],"gift cooldown persists across JSON save restore")
	game.economy.next_day()
	check(rel.give_gift(li,"water")["gain"]==1,"ordinary gift grants only one on next real day")
	amount=game.economy.quantity("concentration_candy");bond=rel.bond("gou_ga")
	check(not rel.give_gift(gou,"concentration_candy")["ok"] and game.economy.quantity("concentration_candy")==amount,"Gou refuses candy without consuming it")
	check(not rel.daily.has("gou_ga/gift"),"rejection does not consume daily chance")
	check(rel.give_gift(gou,"bound_notes")["ok"] and rel.bond("gou_ga")==bond,"accepted Gou gift never buys story-only affection")
	game.economy.add_item("seal_shard",1)
	check(not rel.give_gift(li,"seal_shard")["ok"] and game.economy.quantity("seal_shard")>0,"plot item cannot be gifted even by direct method")
	check(not rel.give_gift(li,"missing")["ok"],"unknown inventory rejected")
	for uid: String in ["gift-a","gift-b"]:
		check(rel.give_gift({"character":"student_male","name":"同学","uid":uid},"water")["ok"],"ordinary NPC keeps independent gift identity "+uid)
	check(rel.bond("local/gift-a")==1 and rel.bond("local/gift-b")==1,"ordinary recipient affinity is independent")
	rel.dead["lao_li"]={"character":"lao_li","name":"牢李","scene":{},"day":0,"period":0};amount=game.economy.quantity("tape")
	check(not rel.give_gift(li,"tape")["ok"] and game.economy.quantity("tape")==amount,"dead actor receives no gift")
	rel.dead.clear();rel.affinity["lao_li"]=-40
	game.economy.next_day();check(not rel.give_gift(li,"tape")["ok"],"deep grievance cannot be bought off")
	rel.affinity["lao_li"]=20
	# Actual UI cancellation and paging: do not consume anything on either page.
	for item: String in rel.content["gifts"]["items"]:game.economy.add_item(item,1)
	var bag: Dictionary=game.economy.inventory.duplicate();snapshot=rel.snapshot()
	answers.assign(["next","prev","cancel"]);await rel.gift_menu(li);answers.clear()
	check(game.economy.inventory==bag and rel.snapshot()==snapshot,"gift UI pagination and cancel leave inventory and relationships unchanged")
	answers.assign(["next","item/tape","cancel","cancel"]);await rel.gift_menu(li);answers.clear()
	check(game.economy.inventory==bag,"second confirmation cancel retains item")
	answers.assign(["next","item/tape","give"]);await rel.gift_menu(li);answers.clear()
	check(game.economy.quantity("tape")==int(bag["tape"])-1,"actual gift confirmation UI commits exactly one item")
	# Voice differences depend on affection and story, while fear/anger overrides banter.
	for actor: String in game.npc_catalog.NAMED_IDS:
		game.voice.cursors.clear();rel.affinity[actor]=0;game.campaign.index=3
		var stranger: String=rel.reaction({"character":actor},"phone")[1]["text"]
		game.voice.cursors.clear();rel.affinity[actor]=65
		check(stranger!=rel.reaction({"character":actor},"phone")[1]["text"],"familiarity changes actual interaction voice "+actor)
		game.voice.cursors.clear();game.campaign.index=29
		var close: String=game.voice.reply(actor,"chat");var all: String=close
		for n: int in range(3):all+=game.voice.reply(actor,"chat")
		check(all.contains(game.story_system.data["character_voice"][actor]["finale"][0]["text"]),"final-night voice is present "+actor)
	game.campaign.index=3;game.voice.cursors.clear();rel.affinity["local/gift-a"]=65
	check(rel.reaction({"character":"student_male","uid":"gift-a"},"phone").size()==2,"local NPC voice uses own affinity")
	rel.affinity["fei_yan"]=-40;rel.grievances=[{"actor":"fei_yan","text":"伤害记录"}];rel.dead["yang_zi"]={"character":"yang_zi","name":"阳子","scene":{},"day":0,"period":0}
	check(rel.reaction({"character":"fei_yan"},"flirt")[1]["text"].contains("阳子"),"grief overrides flirty banter and names actual lost actor")
	rel.grievances.clear();rel.dead.clear()
	check(rel.valid(rel.snapshot()),"gift and new interactions preserve existing relationship schema")
	# Full screen mouse/touch advancement, excluding special buttons.
	autoplay=false;game.story_system.begin_sequence()
	game.dialogue_view.begin_script([{"actor":"yang_zi","text":"第一句"},{"actor":"fei_yan","text":"第二句"},{"actor":"lao_li","text":"第三句"},{"actor":"system","text":"第四句"}])
	await process_frame
	await mouse(Vector2(100,80))
	check(game.dialogue_view.script_index==1,"blank screen click advances exactly once")
	var at: Vector2=game.dialogue_view.cancel.get_global_rect().get_center()
	check(not game.dialogue_view.can_advance_at(at),"disabled mandatory cancel button is excluded")
	await mouse(at);check(game.dialogue_view.script_index==1,"clicking disabled special button does not skip dialogue")
	at=game.dialogue_view.confirm.get_global_rect().get_center()
	await mouse(at);check(game.dialogue_view.script_index==2,"confirm button handles itself exactly once")
	for down: bool in [true,false]:
		var touch:=InputEventScreenTouch.new();touch.index=0;touch.position=Vector2(120,90);touch.pressed=down
		root.push_input(touch,true);await process_frame
	check(game.dialogue_view.script_index==3,"Android touch mapping advances exactly one line")
	game.campaign.choose("特殊选项测试",[["close","保留对白"]]);await process_frame
	await mouse(Vector2(100,80))
	check(game.dialogue_view.script_index==3,"visible choice modal blocks blank-screen dialogue advancement")
	game.campaign.selected.emit("close");await process_frame
	await mouse(Vector2(100,80));check(not game.dialogue_view.visible,"last background click completes script")
	check(not game.dialogue_view.can_advance_at(Vector2(100,80)),"background tap inactive outside dialogue")
	game.story_system.end_sequence();autoplay=true
	var output: String=game.package_root.path_join("runtime/class_ten_checks.json")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report-path="):output=arg.trim_prefix("--report-path=")
	var f:=FileAccess.open(output,FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"stories":stories,"method":"Actual NPC and location quest UI, both puzzle boards, cancel/JSON resume/death archive; inventory gift atomicity, cooldown, refusals and paging; affinity/story-specific voices; real mouse and Android-mapped screen touch, excluding special buttons."},"  "))
	print("CLASS_TEN_CHECKS ",checks," FAILURES ",failures.size())
	game.queue_free();game=null;await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
