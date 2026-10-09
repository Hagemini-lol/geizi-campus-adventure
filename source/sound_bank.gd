extends Node

const MAX_VOICES:=6
var directory: String
var streams: Dictionary={}
var voices: Array[AudioStreamPlayer]=[]
var last_played: Dictionary={}
var played: Dictionary={}
var serial:=0

func configure(root: String) -> void:
	directory=root.path_join("资源/原创音效/v1.5")
	for i: int in range(MAX_VOICES):
		var voice:=AudioStreamPlayer.new();voice.bus="SFX";voice.volume_db=-12;add_child(voice);voices.append(voice)

func stream(id: String) -> AudioStreamWAV:
	if streams.has(id):return streams[id]
	if id.contains("/") or id.contains("\\") or id.contains("."):return null
	var path:=directory.path_join(id+".wav")
	if not FileAccess.file_exists(path):return null
	var result:=AudioStreamWAV.load_from_buffer(FileAccess.get_file_as_bytes(path))
	if result!=null:streams[id]=result
	return result

func play(id: String) -> void:
	var now:=Time.get_ticks_msec()
	if now-int(last_played.get(id,-10000))<(70 if id=="ui_confirm" else 45):return
	var clip:=stream(id)
	if clip==null:return
	last_played[id]=now;played[id]=int(played.get(id,0))+1
	var target: AudioStreamPlayer=null
	for voice: AudioStreamPlayer in voices:
		if not voice.playing:target=voice;break
	if target==null:target=voices[serial%MAX_VOICES]
	serial+=1;target.stop();target.stream=clip;target.play()

func effect(id: String) -> void:
	if id.begins_with("frost"):play("ice")
	elif id.contains("barrier"):play("barrier")
	elif id.contains("explosion"):play("story_rumble")
	elif id.contains("circle"):play("story_reveal")
	else:
		for element: String in ["lightning","fire","ice","wind","light","dark"]:
			if id.begins_with(element):play(element);return

func stop_all() -> void:
	for voice: AudioStreamPlayer in voices:voice.stop()
