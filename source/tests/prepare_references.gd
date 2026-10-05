extends SceneTree
const Space = preload("res://map_space.gd")

func _initialize() -> void:
	var directory := "D:/Godot/地图重绘预览"
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("区块清单.json")))
	var source := Image.load_from_file("D:/Godot/Projects/赵慕gei的牙林冒险/assets/maps/outdoor/campus_named_v2.png")
	source.convert(Image.FORMAT_RGBA8)
	DirAccess.make_dir_recursive_absolute(directory.path_join("参考裁片"))
	for region: Dictionary in manifest["regions"]:
		var a: Array = region["source_bounds"]
		var box := Rect2(a[0],a[1],a[2],a[3])
		var world := Space.box_to_world(box)
		var factor := 1200.0 / maxf(world.size.x, world.size.y)
		var output_size := Vector2i((world.size * factor).ceil())
		var output := Image.create(output_size.x,output_size.y,false,Image.FORMAT_RGBA8)
		for x: int in range(Space.SOURCE_X.size()-1):
			for y: int in range(Space.SOURCE_Y.size()-1):
				var source_cell := Rect2(Vector2(Space.SOURCE_X[x],Space.SOURCE_Y[y]),Vector2(Space.SOURCE_X[x+1]-Space.SOURCE_X[x],Space.SOURCE_Y[y+1]-Space.SOURCE_Y[y]))
				if not source_cell.intersects(box): continue
				var clip := source_cell.intersection(box)
				var clip_world := Space.box_to_world(clip)
				var start := Vector2i(((clip_world.position-world.position)*factor).round())
				var end := Vector2i(((clip_world.end-world.position)*factor).round())
				var piece := source.get_region(Rect2i(clip))
				piece.resize(maxi(1,end.x-start.x),maxi(1,end.y-start.y),Image.INTERPOLATE_NEAREST)
				output.blit_rect(piece,Rect2i(Vector2i.ZERO,piece.get_size()),start)
		output.save_png(directory.path_join(region["reference"]))
	print("REFERENCE_ONLY: 20 calibrated input crops, not final HD redraws")
	quit()
