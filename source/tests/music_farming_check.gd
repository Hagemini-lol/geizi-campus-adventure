extends SceneTree
var game: Node2D
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.music.set_process(false)
	check(game.music.tracks.size()==6,"six public music tracks with provenance load")
	for id: String in game.music.tracks:
		var clip: AudioStream=game.music.stream(id)
		check(clip!=null and clip.get_length()>30 and clip.loop,"real compressed loopable music "+id)
		check(game.music.tracks[id]["license"]=="CC0 1.0","redistribution license documented "+id)
		check(game.music.switch_to(id),"each music switches "+id)
		await create_timer(.75).timeout
		check(game.music.voices[1-game.music.active].stream==null,"old compressed stream released "+id)
		var changes: int=game.music.changes;game.music.switch_to(id)
		check(game.music.changes==changes,"same music never restarts "+id)
	game.game_started=true;game.front_end.hide_title();game.story_system.stage=6;game.story_system.reward_given=true;game.campaign.index=31
	for period: int in range(6):
		game.day_clock.current_period=period;check(game.music.desired()==("day" if period in [1,5,2] else "night"),"clock selects appropriate BGM "+str(period))
	game.story_system.running=true;game.music.story_tone="tension";check(game.music.desired()=="tension","tense story music wins over exploration")
	game.music.story_tone="heroic";check(game.music.desired()=="heroic","heroic plot music")
	game.story_system.running=false;game.music.story_tone=""
	game.combat_rules.set_hero_level(35,true)
	for zone: Dictionary in game.farming.ZONES:
		var context: Dictionary={"building":zone["building"],"floor":zone["floor"],"kind":"classroom","room":zone["room"]}
		game.campaign.done.erase(zone["after"]);check(game.farming.rule(context).is_empty(),"farming locked until narrative resolution "+zone["building"])
		game.campaign.done.append(zone["after"])
		await game.change_interior(context);await process_frame;await process_frame
		check(game.monster_world.zone_rule(context).get("farming",false),"actual farming room enables "+zone["building"])
		check(game.terrain.current_scene.npcs==null or game.terrain.current_scene.npcs.records.is_empty(),"farming never shares room with ordinary NPCs "+zone["building"])
		var monsters: Array=game.monster_world.activate(context)
		check(not monsters.is_empty(),"actual farming spawns monsters "+zone["building"])
		for monster: Dictionary in monsters:
			check(monster["id"] in zone["normal"]+zone["elite"] and game.combat_rules.data["monsters"][monster["id"]]["rarity"]!="boss","location-specific pool without bosses")
		if monsters.is_empty():continue
		var serial: int=game.monster_world.period_serial
		game.battle_view.start({"monster":monsters[0]},game.monster_world.zone_key(context))
		check(game.music.desired()=="battle","actual ordinary battle BGM")
		game.battle_view.finish("victory");game.battle_view.close();await process_frame
		check(game.monster_world.period_serial==serial+1,"clearing takes exactly one period "+zone["building"])
		check(game.monster_world.activate(context).size() in [1,2],"continuous refill respects two monster cap "+zone["building"])
		var saved: Dictionary=game.monster_world.snapshot()
		check(game.monster_world.valid_snapshot(JSON.parse_string(JSON.stringify(saved))),"farming JSON save valid "+zone["building"])
		game.monster_world.activate(context);check(saved==game.monster_world.snapshot(),"re-enter does not reroll "+zone["building"])
	game.music.stop_all();check(game.music.voices.all(func(v: AudioStreamPlayer):return v.stream==null),"stop releases both streams")
	var f:=FileAccess.open(game.package_root.path_join("runtime/music_farming_checks.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures},"  "))
	print("MUSIC_FARMING_CHECKS ",checks," FAILURES ",failures.size());game.queue_free();game=null;await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
