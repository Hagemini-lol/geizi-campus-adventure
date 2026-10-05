extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var info: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("D:/Godot/地图重绘预览/内景/内外对应.json"))
	var room:=preload("res://interior_scene.gd").new()
	room.setup(info,{"kind":"classroom","building":"B12","floor":3,"room":1},"D:/Godot/地图重绘预览/内景")
	var start:=room.landing()
	for portal: Dictionary in room.portals:
		var target: Vector2=portal["at"]
		var path:=room.navigation.route(start,target)
		print("ROOM_PROBE ",{"side":portal["side"],"start":start,"target":target,"start_walkable":room.navigation.walkable(start),"target_walkable":room.navigation.walkable(target),"start_cell":room.navigation.closest_cell(start),"target_cell":room.navigation.closest_cell(target),"route":path})
	room.free()
	quit()
