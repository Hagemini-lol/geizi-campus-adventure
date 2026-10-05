extends RefCounted

var data: Dictionary={}
var assignments: Array[Dictionary]=[]

func configure(path: String) -> bool:
	var value: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary:return false
	data=value
	return data.get("assets") is Dictionary and data.get("staff_ids") is Array

func apply(info: Dictionary, package_root: String) -> void:
	assignments.clear()
	for key: String in data["assets"]:
		var path: String=data["assets"][key]
		info["assets"][key]=path if path.is_absolute_path() else package_root.path_join(path).simplify_path()
	for id: String in data["building_ids"]:
		if not info["buildings"].has(id):continue
		var building: Dictionary=info["buildings"][id]
		for floor_data: Dictionary in building["floors"]:
			var rooms: Array=floor_data["rooms"]
			var far_right: Dictionary=rooms[-1]
			var nearest: Dictionary={}
			var distance:=INF
			var stairs:=float(building["stairs_center_x"])/24.0
			for room: Dictionary in rooms:
				if room["class10"] or room==far_right:continue
				var span: Array=room["span"]
				var gap:=maxf(0,maxf(float(span[0])-stairs,stairs-float(span[1])))
				if gap<distance:distance=gap;nearest=room
			mark(far_right,"right","office_white",id,floor_data)
			if not nearest.is_empty():mark(nearest,"stairs","office_wood",id,floor_data)

func mark(room: Dictionary, location: String, asset: String, building: String, floor_data: Dictionary) -> void:
	room["office"]=true;room["office_asset"]=asset;room["office_location"]=location
	room["classroom_name"]=room["name"]
	room["name"]="办公室（"+("最右侧" if location=="right" else "楼梯旁")+"）"
	assignments.append({"building":building,"floor":floor_data.get("floor",0),"room":room["index"],"location":location,"asset":asset})
