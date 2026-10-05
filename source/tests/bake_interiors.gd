extends SceneTree

class CorridorPainter extends Node2D:
	var info: Dictionary
	var building: Dictionary
	var row: Dictionary
	var base: Texture2D
	var doors: Texture2D
	var font: SystemFont
	func _draw() -> void:
		var width: float=building["width_pixels"]
		var height: float=building["height_pixels"]
		# The blank wall/floor strip is repeated at metre scale, rather than
		# stretching a single corridor and its stairwell across an entire facade.
		var strip:=Rect2(220,0,300,836)
		var x:=0.0
		while x<width:
			var segment:=minf(144,width-x)
			draw_texture_rect_region(base,Rect2(x,0,segment,height),Rect2(strip.position,Vector2(segment/144*300,836)))
			x+=segment
		var middle: float=building["stairs_center_x"]
		draw_texture_rect_region(base,Rect2(middle-72,0,144,height),Rect2(605,0,670,836))
		for room: Dictionary in row["rooms"]:
			for side: String in ["front","rear"]:
				if room[side+"_door_x"]==null: continue
				var door_x:=float(room[side+"_door_x"])*24
				var ten: bool=room["class10"]
				var door_width:=45.6 if ten else 24.0
				var source:=Rect2(588,198,369,620) if ten else Rect2(120,222,268,570)
				draw_texture_rect_region(doors,Rect2(door_x-door_width*.5,72.28-50.4,door_width,50.4),source)
				var title: String=str(room["name"])+(" 后门" if side=="rear" else "")
				var text_width:=font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x
				draw_rect(Rect2(door_x-text_width*.5-4,7,text_width+8,13),Color("26413e"))
				draw_string(font,Vector2(door_x-text_width*.5,17),title,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("fff2ca"))
		var floor_number:=int(row["floor"])
		draw_string(font,Vector2(middle-27,16),str(floor_number)+"楼",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color.WHITE)
		if floor_number==1:
			draw_string(font,Vector2(middle-35,174),"校园出口",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("27443e"))
		# Labels sit beside the stair mouths, so there are no portal glyphs.
		if floor_number<int(building["floor_count"]): draw_string(font,Vector2(middle-15,104),"上楼",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("273c38"))
		if floor_number>1:
			draw_string(font,Vector2(middle-64,104),"下楼",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("273c38"))
			draw_string(font,Vector2(middle+31,104),"下楼",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("273c38"))

func _initialize() -> void: call_deferred("bake")

func bake() -> void:
	var directory:="D:/Godot/地图重绘预览/内景"
	var info: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("内外对应.json")))
	var density:=float(info.get("corridor_image_density",3))
	var doors:=ImageTexture.create_from_image(Image.load_from_file(info["assets"]["doors"]))
	var bases: Array[Texture2D]=[]
	for key: String in ["corridor","top_corridor"]: bases.append(ImageTexture.create_from_image(Image.load_from_file(info["assets"][key])))
	var font:=SystemFont.new()
	font.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"])
	font.oversampling=density
	for id: String in info["buildings"]:
		var building: Dictionary=info["buildings"][id]
		for row: Dictionary in building["floors"]:
			var viewport:=SubViewport.new()
			viewport.size=Vector2i(ceili(building["width_pixels"]*density),ceili(building["height_pixels"]*density))
			viewport.transparent_bg=true
			viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
			root.add_child(viewport)
			var painter:=CorridorPainter.new()
			painter.info=info
			painter.building=building
			painter.row=row
			painter.base=bases[1 if int(row["floor"])==int(building["floor_count"]) else 0]
			painter.doors=doors
			painter.font=font
			painter.scale=Vector2.ONE*density
			viewport.add_child(painter)
			await process_frame
			await RenderingServer.frame_post_draw
			var result:=viewport.get_texture().get_image().save_png(directory.path_join(row["image"]))
			if result!=OK: quit(1); return
			print("INTERIOR_BAKED ",row["image"])
			viewport.free()
	quit()
