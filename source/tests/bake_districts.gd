extends SceneTree

const Painter=preload("res://human_scale_details.gd")
const Space=preload("res://map_space.gd")
const PPM:=24.0
var game: Node2D

func _initialize() -> void: call_deferred("bake")

func bake() -> void:
	game=(load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	if not game.load_error.is_empty(): quit(1); return
	game.hide()
	game.player.set_physics_process(false)
	var asset_root: String=game.terrain.asset_root
	var out:=asset_root.path_join("静态区块")
	DirAccess.make_dir_recursive_absolute(out)
	var entries: Array[Dictionary]=[]
	var road_plan: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(out.path_join("道路分割方案.json")))
	# Each image includes a 14 m shared road apron. Movement ownership remains
	# unique, but both neighbours render the same road and surrounding objects.
	for index: int in range(20):
		var region: Dictionary=game.model["regions"][index]
		var a: Array=region["world_bounds"]
		var planned: Array=road_plan["regions"][index]["visual_bounds"]
		var visual:=Rect2(planned[0],planned[1],planned[2],planned[3])
		region["visual_bounds"]=[visual.position.x,visual.position.y,visual.size.x,visual.size.y]
		region["visual_areas"]=[region["visual_bounds"]]
		var bounds:=Rect2(visual.position*PPM,visual.size*PPM)
		var scale_factor:=minf(1,minf(3072/maxf(bounds.size.x,bounds.size.y),sqrt(3000000/(bounds.size.x*bounds.size.y))))
		var pixels:=Vector2i(ceili(bounds.size.x*scale_factor),ceili(bounds.size.y*scale_factor))
		var viewport:=SubViewport.new()
		viewport.size=pixels
		viewport.transparent_bg=true
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var camera:=Camera2D.new()
		camera.position=bounds.get_center()
		camera.zoom=Vector2(pixels)/bounds.size
		viewport.add_child(camera)
		var texture: Texture2D
		var texture_bounds:=Rect2()
		# Sample neighbouring originals at their original world coordinates;
		# never stretch the current region's source art over the shared apron.
		for neighbour: Dictionary in game.model["regions"]:
			var v: Array=neighbour["world_bounds"]
			var source_bounds:=Rect2(v[0]*PPM,v[1]*PPM,v[2]*PPM,v[3]*PPM)
			if not source_bounds.intersects(bounds): continue
			var raw:=Image.load_from_file(asset_root.path_join(str(neighbour["image"])))
			var source_texture:=ImageTexture.create_from_image(game.terrain.trim_frame(raw))
			if neighbour["id"]=="G01": texture=source_texture; texture_bounds=source_bounds
			for area: Array in neighbour["world_areas"]:
				var owned:=Rect2(area[0]*PPM,area[1]*PPM,area[2]*PPM,area[3]*PPM)
				if not owned.intersects(bounds): continue
				var box:=owned.intersection(bounds)
				var slice:=AtlasTexture.new()
				slice.atlas=source_texture
				slice.region=Rect2((box.position-source_bounds.position)/source_bounds.size*source_texture.get_size(),box.size/source_bounds.size*source_texture.get_size())
				var sprite:=Sprite2D.new()
				sprite.texture=slice
				sprite.centered=false
				sprite.position=box.position
				sprite.scale=box.size/slice.get_size()
				sprite.z_index=-5
				viewport.add_child(sprite)
		var painter:=Node2D.new()
		painter.set_script(Painter)
		painter.model=game.model
		painter.index=index
		painter.map_texture=texture
		painter.map_bounds=texture_bounds
		painter.bake_bounds=bounds
		for feature: Dictionary in game.data["zones"]:
			var v: Array=feature["footprint"]
			var feature_box:=Space.box_to_world(Rect2(v[0],v[1],v[2],v[3]))
			if feature["id"]=="G01" and feature_box.intersects(bounds):
				painter.garden=feature_box
			if str(feature["id"]) in ["P01","G02","G03","N01","N02"] or feature["kind"]=="building": continue
			painter.preserved.append(feature_box)
		for blocker: Dictionary in game.data["blockers"]:
			if blocker["owner"]!="trees": continue
			var v: Array=blocker["rect"]
			painter.planting.append(Space.box_to_world(Rect2(v[0],v[1],v[2],v[3])))
		for j: int in range(game.model["solids"].size()):
			var v: Array=game.model["solids"][j]
			var box:=Rect2(v[0]*PPM,v[1]*PPM,v[2]*PPM,v[3]*PPM)
			if not box.intersects(bounds): continue
			var owner: String=game.model["solid_owners"][j]
			var stories:=2
			for feature: Dictionary in game.data["zones"]:
				if feature["id"]==owner and feature.get("storeys")!=null: stories=int(feature["storeys"])
			painter.parts.append({"box":box,"owner":owner,"stories":stories})
		viewport.add_child(painter)
		await process_frame
		await RenderingServer.frame_post_draw
		var image:=viewport.get_texture().get_image()
		var file:=str(region["id"])+".png"
		var result:=image.save_png(out.path_join(file))
		if result!=OK: push_error("Could not bake "+file); quit(1); return
		entries.append({"id":region["id"],"image":"静态区块/"+file,"pixels":[pixels.x,pixels.y],"rgba_bytes":pixels.x*pixels.y*4,"visual_bounds":region["visual_bounds"],"visual_areas":region["visual_areas"]})
		viewport.free()
		print("BAKED ",region["id"]," ",pixels)
		await process_frame
	var manifest:=FileAccess.open(out.path_join("清单.json"),FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"version":2,"ppm":24,"max_pixels":3000000,"road_overlap_meters":14,"regions":entries},"  "))
	manifest.close()
	quit()
