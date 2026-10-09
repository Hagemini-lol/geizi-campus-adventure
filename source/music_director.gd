extends Node

# Two compressed streams during a crossfade; no per-frame file reads or PCM cache.
var game: Node2D
var directory: String
var tracks: Dictionary={}
var voices: Array[AudioStreamPlayer]=[]
var current:=""
var active:=0
var elapsed:=0.0
var transition: Tween
var story_tone:=""
var positions: Dictionary={}
var changes:=0

func configure(root: String) -> void:
	directory=root.path_join("资源/公开配乐/v1.5")
	var path:=directory.path_join("曲目与来源.json")
	if FileAccess.file_exists(path):
		var spec: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
		if spec is Dictionary:
			for track: Dictionary in spec.get("tracks",[]):tracks[track["id"]]=track
	for i: int in range(2):
		var voice:=AudioStreamPlayer.new();voice.bus="Music";voice.volume_db=-80;add_child(voice);voices.append(voice)

func desired() -> String:
	if not game.game_started:return ""
	if game.battle_view!=null and game.battle_view.visible:
		return "final_boss" if str(game.battle_view.enemy.get("id","")).begins_with("gou_ga") else "heroic" if game.battle_view.enemy.get("rarity","")=="boss" else "battle"
	if game.story_system!=null and game.story_system.running and story_tone in ["tension","heroic"]:return story_tone
	if game.campaign!=null and not game.campaign.ending.is_empty():return "heroic" if game.campaign.ending.begins_with("GE") else "night"
	return "day" if game.day_clock.current_period in [1,5,2] else "night"

func stream(id: String) -> AudioStream:
	if not tracks.has(id):return null
	var file: String=tracks[id]["file"]
	if file.contains("/") or file.contains("\\"):return null
	var bytes:=FileAccess.get_file_as_bytes(directory.path_join(file))
	var result: AudioStream
	if file.ends_with(".ogg"):result=AudioStreamOggVorbis.load_from_buffer(bytes)
	elif file.ends_with(".mp3"):result=AudioStreamMP3.load_from_buffer(bytes)
	if result!=null:result.loop=true
	return result

func switch_to(id: String) -> bool:
	if id==current:return true
	var clip: AudioStream=stream(id) if not id.is_empty() else null
	if not id.is_empty() and clip==null:return false
	if transition!=null and transition.is_valid():transition.kill()
	var outgoing: AudioStreamPlayer=voices[active]
	if not current.is_empty() and outgoing.playing:positions[current]=outgoing.get_playback_position()
	active=1-active;var incoming: AudioStreamPlayer=voices[active]
	incoming.stop();incoming.stream=clip;incoming.volume_db=-80
	if clip!=null:incoming.play(fmod(float(positions.get(id,0)),maxf(.01,clip.get_length())) if id in ["day","night"] else 0)
	current=id;changes+=1
	transition=create_tween().set_parallel(true)
	transition.tween_property(outgoing,"volume_db",-80,.65)
	transition.tween_property(incoming,"volume_db",-17 if game.dialogue_view!=null and game.dialogue_view.visible else -13,.65)
	transition.chain().tween_callback(func():outgoing.stop();outgoing.stream=null)
	return true

func _process(delta: float) -> void:
	if game==null or voices.is_empty():return
	elapsed+=delta
	if elapsed<.2:return
	elapsed=0
	switch_to(desired())
	# Settings retain their Music bus control. Speech/pause reduces music only.
	if transition==null or not transition.is_running():
		var target: float=-24 if game.paused else -17 if game.dialogue_view!=null and game.dialogue_view.visible else -13
		voices[active].volume_db=target

func stop_all() -> void:
	if transition!=null and transition.is_valid():transition.kill()
	for voice: AudioStreamPlayer in voices:voice.stop();voice.stream=null
	current=""
