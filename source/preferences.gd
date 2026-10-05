extends RefCounted

const RESOLUTIONS: Array[Vector2i]=[Vector2i(1280,800),Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(3840,2160)]
const FPS_VALUES: Array[int]=[30,60,120,0]
var path: String
var values: Dictionary={"resolution":0,"fullscreen":false,"vsync":true,"fps":60,"master":80.0,"music":70.0,"sfx":80.0}

func configure(file_path: String) -> void:
	path=file_path
	for bus: String in ["Music","SFX"]:
		if AudioServer.get_bus_index(bus)<0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
			AudioServer.set_bus_send(AudioServer.bus_count-1,"Master")
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if parsed is Dictionary:values=normalise(parsed)
	apply(values,false)

func normalise(candidate: Dictionary) -> Dictionary:
	var result:=values.duplicate()
	for key: String in values:
		if not candidate.has(key):continue
		if key in ["fullscreen","vsync"]:
			if candidate[key] is bool:result[key]=candidate[key]
		elif candidate[key] is float or candidate[key] is int:
			if is_finite(float(candidate[key])):result[key]=candidate[key]
	result["resolution"]=clampi(int(result["resolution"]),0,RESOLUTIONS.size()-1)
	result["fps"]=int(result["fps"]) if int(result["fps"]) in FPS_VALUES else 60
	for key: String in ["master","music","sfx"]:result[key]=clampf(float(result[key]),0,100)
	return result

func preview_volume(key: String, percent: float) -> void:
	var name: String={"master":"Master","music":"Music","sfx":"SFX"}.get(key,"")
	if name.is_empty():return
	var index:=AudioServer.get_bus_index(name)
	AudioServer.set_bus_mute(index,percent<=0)
	AudioServer.set_bus_volume_db(index,linear_to_db(maxf(percent/100.0,.0001)))

func apply(candidate: Dictionary, persist: bool=true) -> bool:
	values=normalise(candidate)
	for key: String in ["master","music","sfx"]:preview_volume(key,float(values[key]))
	Engine.max_fps=int(values["fps"])
	if DisplayServer.get_name()!="headless" and not OS.has_feature("android"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if values["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED)
		if not values["fullscreen"]:
			DisplayServer.window_set_size(RESOLUTIONS[int(values["resolution"])])
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values["vsync"] else DisplayServer.VSYNC_DISABLED)
	if not persist:return true
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir())!=OK:return false
	var file:=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:return false
	file.store_string(JSON.stringify(values,"  "))
	file.flush();file.close()
	# ConfigFile replacement is independent of gameplay saves.
	if FileAccess.file_exists(path) and DirAccess.remove_absolute(path)!=OK:return false
	return DirAccess.rename_absolute(path+".tmp",path)==OK
