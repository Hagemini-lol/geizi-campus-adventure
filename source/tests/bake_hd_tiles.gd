extends SceneTree

const Painter=preload("res://human_scale_details.gd")
const Space=preload("res://map_space.gd")
const TILE_SIZE:=256
const DENSITY:=4
var game: Node2D

class SourceLayer extends Node2D:
	var sources: Array[Dictionary]
	var tile_bounds: Rect2
	func _draw() -> void:
		for source: Dictionary in sources:
			var bounds: Rect2=source["bounds"]
			if not bounds.intersects(tile_bounds):continue
			var texture: Texture2D=source["texture"]
			for a: Array in source["region"]["world_areas"]:
				var owned:=Rect2(a[0]*24,a[1]*24,a[2]*24,a[3]*24)
				if not owned.intersects(tile_bounds):continue
				var box:=owned
				# Keep the same quad and UV mapping in every viewport; clipping
				# a differently sized quad per tile changes GPU pixel rounding.
				draw_texture_rect_region(texture,box,Rect2((box.position-bounds.position)/bounds.size*texture.get_size(),box.size/bounds.size*texture.get_size()))

func _initialize() -> void:call_deferred("bake")

func bake() -> void:
	game=(load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.hide()
	game.player.set_physics_process(false)
	var directory: String=game.terrain.asset_root.path_join("静态区块/高清切片")
	DirAccess.make_dir_recursive_absolute(directory)
	var sources: Array[Dictionary]=[]
	var water: Texture2D
	var water_bounds:=Rect2()
	for region: Dictionary in game.model["regions"]:
		var v: Array=region["world_bounds"]
		var bounds:=Rect2(v[0]*24,v[1]*24,v[2]*24,v[3]*24)
		var image: Image=game.terrain.trim_frame(Image.load_from_file(game.terrain.asset_root.path_join(region["image"])))
		image.generate_mipmaps()
		var texture:=ImageTexture.create_from_image(image)
		sources.append({"region":region,"bounds":bounds,"texture":texture})
		if region["id"]=="G01":water=texture;water_bounds=bounds
	var paint_model: Dictionary=game.model.duplicate(true)
	paint_model["regions"][0]["visual_areas"]=[[0,0,320,360]]
	var entries: Dictionary={}
	var repair_boards: bool="--repair-boards" in OS.get_cmdline_user_args()
	var repair_detail: bool="--repair-detail" in OS.get_cmdline_user_args()
	if repair_boards or repair_detail:
		entries=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("清单.json")))["tiles"]
	var count:=0
	for y: int in range(34):
		for x: int in range(30):
			var key:=str(x)+"_"+str(y)
			# One world pixel of bleed prevents seams at fractional camera positions.
			var bounds:=Rect2(x*TILE_SIZE-1,y*TILE_SIZE-1,TILE_SIZE+2,TILE_SIZE+2)
			if repair_boards:
				var relevant:=false
				for entry: Dictionary in game.interior_info["entrances"]:
					var center:=Vector2(entry["board"][0],entry["board"][1])*24
					if bounds.intersects(Rect2(center-Vector2(24,17),Vector2(48,34))):relevant=true;break
				if not relevant:continue
			if repair_detail:
				var relevant:=false
				for feature: Dictionary in game.data["zones"]:
					if str(feature["id"]) in ["P01","G02","G03","N01","N02"] or feature["kind"]=="building":continue
					var a: Array=feature["footprint"]
					if bounds.intersects(Space.box_to_world(Rect2(a[0],a[1],a[2],a[3])).grow(24)):relevant=true;break
				if not relevant:
					for j: int in range(game.model["solids"].size()):
						if not str(game.model["solid_owners"][j]).begins_with("B"):continue
						var a: Array=game.model["solids"][j]
						var box:=Rect2(a[0]*24,a[1]*24,a[2]*24,a[3]*24)
						if bounds.intersects(box.grow(48)) and not bounds.intersects(box):relevant=true;break
				if not relevant:continue
			var viewport:=SubViewport.new()
			viewport.size=Vector2i.ONE*(TILE_SIZE+2)*DENSITY
			viewport.transparent_bg=true
			viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
			root.add_child(viewport)
			var camera:=Camera2D.new()
			camera.position=bounds.get_center()
			camera.zoom=Vector2.ONE*DENSITY
			viewport.add_child(camera)
			var source_layer:=SourceLayer.new()
			source_layer.sources=sources
			source_layer.tile_bounds=bounds
			source_layer.z_index=-5
			source_layer.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			viewport.add_child(source_layer)
			var painter:=Node2D.new()
			painter.set_script(Painter)
			painter.model=paint_model
			painter.index=0
			painter.map_texture=water
			painter.map_bounds=water_bounds
			painter.bake_bounds=bounds
			for feature: Dictionary in game.data["zones"]:
				var v: Array=feature["footprint"]
				var box:=Space.box_to_world(Rect2(v[0],v[1],v[2],v[3]))
				if feature["id"]=="G01":painter.garden=box
				if str(feature["id"]) in ["P01","G02","G03","N01","N02"] or feature["kind"]=="building":continue
				painter.preserved.append(box)
			for blocker: Dictionary in game.data["blockers"]:
				if blocker["owner"]!="trees":continue
				var v: Array=blocker["rect"]
				painter.planting.append(Space.box_to_world(Rect2(v[0],v[1],v[2],v[3])))
			for j: int in range(game.model["solids"].size()):
				var a: Array=game.model["solids"][j]
				var box:=Rect2(a[0]*24,a[1]*24,a[2]*24,a[3]*24)
				if not box.grow(48).intersects(bounds):continue
				var owner: String=game.model["solid_owners"][j]
				var stories:=2
				for feature: Dictionary in game.data["zones"]:
					if feature["id"]==owner and feature.get("storeys")!=null:stories=int(feature["storeys"])
				painter.parts.append({"box":box,"owner":owner,"stories":stories})
			viewport.add_child(painter)
			await process_frame
			await RenderingServer.frame_post_draw
			var image:=viewport.get_texture().get_image()
			var files: Dictionary={}
			for quality: int in [4,2,1]:
				var output: Image=image.duplicate()
				if quality!=4:output.resize((TILE_SIZE+2)*quality,(TILE_SIZE+2)*quality,Image.INTERPOLATE_LANCZOS)
				var name:=key+"_"+str(quality)+".png"
				if output.save_png(directory.path_join(name))!=OK:quit(1);return
				files[str(quality)]=name
			entries[key]={"images":files,"world_pixels":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]}
			viewport.free()
			count+=1
			if count%30==0:print("HD_TILES ",count," / 1020")
	var file:=FileAccess.open(directory.path_join("清单.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":1,"density":4,"tile_world_pixels":256,"tiles":entries},"  "))
	file.close()
	print("HD_BAKE_COMPLETE 1020 tiles, 3 LODs, 96 source pixels per metre")
	quit()
