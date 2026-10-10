extends SceneTree
var game: Node2D
var checks:=0
var failures: Array[String]=[]
var answers: Array[String]=[]
var panel_id:=0
var capture:=false
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _process(_delta: float) -> bool:
	if game==null:return false
	if game.dialogue_view.visible:game.dialogue_view.accept()
	if game==null:return false
	if is_instance_valid(game.campaign.panel) and game.campaign.panel.get_instance_id()!=panel_id and not answers.is_empty():
		for button: Button in game.campaign.panel.find_children("*","Button",true,false):
			if str(button.get_meta("campaign_option",""))==answers[0]:
				panel_id=game.campaign.panel.get_instance_id();answers.pop_front();button.pressed.emit();break
	return false
func ready_scene() -> void:
	while game.transition_busy:await process_frame
	await process_frame
func run() -> void:
	capture="--capture" in OS.get_cmdline_user_args()
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.start_new_game();await ready_scene();game.story_system.stage=6;game.story_system.reward_given=true;game.campaign.index=31
	var count:=0;var kinds: Dictionary={}
	for id: String in game.side_quests.quests():
		var q: Dictionary=game.task_system.definitions[id]
		for i: int in range(q["steps"].size()):
			var step: Dictionary=q["steps"][i]
			if not step.has("puzzle"):continue
			var spec: Dictionary=step["puzzle"];kinds[spec["kind"]]=true;count+=1
			print("STORY_PUZZLE_TEST ",id,"/",i)
			check(preload("res://puzzle_board.gd").valid_spec(spec),"board schema valid "+id)
			for pre: String in q.get("prerequisites",[]):game.task_system.entries[pre]={"status":"completed","step":game.task_system.definitions[pre]["steps"].size(),"progress":0}
			game.task_system.entries[id]={"status":"active","step":i,"progress":0}
			var location: String=step.get("location",game.campaign.scheduled_location(step.get("actor","")));var p:=location.split(":")
			if p.size()==1:await game.begin_transition(game.navigation.region_at(game.campaign.outdoor_point(location)),game.campaign.outdoor_point(location))
			else:await game.change_interior({"building":p[0],"floor":int(p[1]),"kind":"corridor" if p[2]=="corridor" else "classroom","room":-1 if p[2]=="corridor" else int(p[2])})
			await ready_scene()
			var items: Dictionary=game.economy.inventory.duplicate()
			answers.assign(["submit","move0","cancel"])
			await game.side_quests.perform_step(id,i)
			check(game.task_system.entries[id]["step"]==i,"wrong result/cancel cannot advance "+id)
			check(game.economy.inventory==items,"wrong/cancel consumes no items "+id)
			var state: Dictionary=game.task_system.entries[id]["puzzles"][str(i)]
			check(state["attempts"]==1 and not state["solved"],"wrong attempt recorded "+id)
			check(game.task_system.valid_snapshot(game.task_system.snapshot()),"unfinished puzzle state validates "+id)
			var saved: String=JSON.stringify(state)
			check(game.save_game_slot(4)["ok"],"unfinished puzzle actual save "+id)
			check(game.load_game_slot(4)["ok"],"unfinished puzzle actual load "+id);await ready_scene()
			state=game.task_system.entries[id]["puzzles"][str(i)]
			check(JSON.stringify(state)==saved,"exact unfinished arrangement restored "+id)
			answers.assign(["inspect","0","1","2","back"])
			answers.append_array(preload("res://tests/puzzle_solver.gd").actions(spec,state["values"]))
			await game.side_quests.perform_step(id,i)
			check(game.task_system.entries[id]["step"]==i+1,"real board actions advance story "+id)
			check(game.task_system.entries[id]["puzzles"][str(i)]["solved"] and game.task_system.entries[id]["puzzles"][str(i)]["seen"].size()==3,"clues observed and solve saved "+id)
	check(count==10 and kinds.size()==3,"ten finite puzzles of three different types")
	# A current cast NPC must open the prerequisite quest, not repeatedly
	# redirect to the blocked main event.
	game.campaign.index=4;game.task_system.entries.erase("chapter_signal")
	await game.change_interior({"building":"B12","floor":3,"kind":"classroom","room":0});await ready_scene()
	var actor: Dictionary={}
	for record: Dictionary in game.terrain.current_scene.npcs.records:
		if record["character"]=="lao_li":actor=record
	check(not actor.is_empty(),"blocked chapter owner exists in scheduled room")
	if not actor.is_empty():
		answers.assign(["side/chapter_signal","accept"])
		check(game.campaign.handle({"action":"npc","uid":actor["uid"]}),"actual NPC interaction routed")
		while game.story_system.running:await process_frame
		check(game.task_system.entries.get("chapter_signal",{}).get("status","")=="active","blocked main NPC can accept chapter prerequisite")
	game.campaign.index=31
	var clock:=preload("res://play_clock.gd").new()
	for n: int in range(70):clock.tick(1,"dialogue",true)
	check(is_equal_approx(clock.total(),60),"AFK stops counting after 60 seconds")
	clock.tick(1,"combat",false);check(is_equal_approx(clock.total(),60),"background time excluded")
	clock.activity();clock.tick(1,"menu",true);check(is_equal_approx(clock.total(),61),"active menu planning counts")
	clock.tick(1,"exploration",true,true);check(is_equal_approx(clock.total(),62),"continuous walking counts")
	game.play_clock.restore(clock.snapshot());check(game.save_game_slot(4)["ok"],"active clock written with real game save")
	var saved_clock: Dictionary=game.save_store.read_slot(4)["state"]["playtime"]
	var expected_clock: float=float(saved_clock["exploration"])+float(saved_clock["dialogue"])+float(saved_clock["combat"])+float(saved_clock["menu"])
	game.play_clock.restore({});check(game.load_game_slot(4)["ok"],"active clock game reload accepted");await ready_scene()
	check(game.play_clock.total()>=expected_clock and game.play_clock.total()<expected_clock+1.0,"active time restored rather than reset on load")
	var bad: Dictionary=game.task_system.snapshot();bad["entries"]["side_wr_margin"]["puzzles"]["0"]["values"]=[-1,0,0,0]
	check(not game.task_system.valid_snapshot(bad),"malformed saved board rejected")
	var f:=FileAccess.open(game.package_root.path_join("runtime/puzzle_checks.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"puzzles":count,"kinds":kinds.keys(),"method":"Actual choice UI operations, clue inspection, wrong submission, cancel, exact unfinished state save/load, solve and quest progression for all ten boards; active-time AFK/background/save checks."},"  "));f.close()
	print("PUZZLE_CHECKS ",checks," FAILURES ",failures.size())
	game.queue_free();game=null;await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
