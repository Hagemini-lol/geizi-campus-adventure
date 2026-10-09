extends SceneTree
var game: Node2D
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks+=1
	if not ok:failures.append(text);push_error(text)
func count(id: String) -> int:return int(game.sounds.played.get(id,0))
func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.start_new_game()
	while game.transition_busy:await process_frame
	var sounds: Node=game.sounds
	var spec: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(sounds.directory.path_join("音效索引.json")))
	for cue: Dictionary in spec["cues"]:
		var clip: AudioStreamWAV=sounds.stream(cue["id"])
		check(clip!=null and clip.get_length()>0 and clip.get_length()<=1.0,"short cue decodes: "+cue["id"])
		check(clip.mix_rate==22050 and not clip.stereo and clip.format==AudioStreamWAV.FORMAT_16_BITS,"small mono PCM cue: "+cue["id"])
		check(clip==sounds.stream(cue["id"]),"cached sound resource: "+cue["id"])
	check(sounds.stream("../invalid")==null and sounds.stream("missing")==null,"missing/path traversal sound rejected")
	game.play_ui_click();var first:=count("ui_confirm")
	for i: int in range(40):game.play_ui_click()
	check(count("ui_confirm")==first,"rapid confirmation clicks are limited")
	var deadline:=Time.get_ticks_msec()+80
	while Time.get_ticks_msec()<deadline:await process_frame
	game.play_ui_click();check(count("ui_confirm")==first+1,"confirmation works after cooldown")
	for cue: Dictionary in spec["cues"]:sounds.play(cue["id"])
	check(sounds.voices.size()==6 and sounds.get_child_count()==6,"sound effects use fixed six-voice pool")
	for voice: AudioStreamPlayer in sounds.voices:check(voice.bus=="SFX" and voice.volume_db==-12,"all effects obey SFX slider with mixing headroom")
	game.preferences.preview_volume("sfx",0);check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")),"mute affects new sounds immediately")
	game.preferences.preview_volume("sfx",80)
	await create_timer(.1).timeout
	game.story_system.stage=6;game.story_system.reward_given=true;game.campaign.index=31
	game.combat_rules.set_hero_level(40,true);game.combat_rules.equip("special_uniform");game.combat_rules.equip("tech_amulet");game.combat_rules.refill_hero()
	for id: String in game.combat_rules.data["skills"]:game.combat_rules.learn(id)
	var stats: Dictionary=game.combat_rules.monster_stats("gou_ga_boss",45)
	check(game.battle_view.start({"monster":{"id":"gou_ga_boss","uid":"sound-boss","level":45,"hp":stats["hp"]}},"sound-test"),"actual boss combat starts")
	var before:=count("attack_swing");await game.battle_view.perform("physical")
	check(count("attack_swing")>before and count("impact")>0,"actual physical attack and hit trigger separate cues")
	before=count("fire");await game.battle_view.perform("fire_low")
	check(count("fire")>before,"actual fire spell triggers fire sound")
	before=count("guard");await game.battle_view.perform("guard")
	check(count("guard")>before,"actual defense triggers guard sound")
	check(count("boss_thread")>0,"Gouga attack triggers characteristic thread sound")
	game.battle_view.finish("escape");game.battle_view.close()
	sounds.stop_all();check(sounds.voices.all(func(v: AudioStreamPlayer):return not v.playing),"stopping sound releases all voices")
	var report: Dictionary={"checks":checks,"passed":failures.is_empty(),"failures":failures,"cues":spec["cues"].size(),"max_voices":6,"bus":"SFX","actual_combat_triggers":true,"checks_scope":"PCM/resource decoding, pool/cooldown/volume behavior and actual combat cues; does not substitute for human listening preference."}
	var f:=FileAccess.open(game.package_root.path_join("runtime/sound_checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "))
	print("SOUND_CHECK ",checks," FAILURES ",failures.size());game.queue_free();game=null;await process_frame;quit(0 if failures.is_empty() else 1)
