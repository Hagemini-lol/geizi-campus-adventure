extends SceneTree

const Art=preload("res://sports_art.gd")
var game: Node2D
var repaired: Array[String]=[]
func _initialize() -> void:call_deferred("run")

func render(path: String,bounds: Rect2,pixels: Vector2i) -> Image:
	var image:=Image.load_from_file(path)
	var viewport:=SubViewport.new();viewport.size=pixels;viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var camera:=Camera2D.new();camera.position=bounds.get_center();camera.zoom=Vector2(pixels)/bounds.size;viewport.add_child(camera)
	var sprite:=Sprite2D.new();sprite.centered=false;sprite.texture=ImageTexture.create_from_image(image)
	sprite.position=bounds.position;sprite.scale=bounds.size/Vector2(image.get_size());sprite.z_index=-5;viewport.add_child(sprite)
	viewport.add_child(Art.new())
	await process_frame;await RenderingServer.frame_post_draw
	var result:=viewport.get_texture().get_image();viewport.free();return result

func run() -> void:
	game=(load("res://main.tscn") as PackedScene).instantiate();root.add_child(game);await process_frame
	if not game.load_error.is_empty():quit(1);return
	game.hide();game.player.set_physics_process(false)
	var base: String=game.terrain.asset_root
	var static_info: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(base.path_join("静态区块/清单.json")))
	for entry: Dictionary in static_info["regions"]:
		var a: Array=entry["visual_bounds"];var bounds:=Rect2(a[0]*24,a[1]*24,a[2]*24,a[3]*24)
		if not Art.relevant(bounds):continue
		var path: String=base.path_join(entry["image"])
		var result: Image=await render(path,bounds,Vector2i(entry["pixels"][0],entry["pixels"][1]))
		if result.save_png(path)!=OK:quit(1);return
		repaired.append(path.trim_prefix(game.package_root+"/"));print("SPORT_STATIC ",entry["id"])
	var folder: String=base.path_join("静态区块/高清切片")
	var hd: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("清单.json")))
	var count:=0
	for key: String in hd["tiles"]:
		var entry: Dictionary=hd["tiles"][key];var a: Array=entry["world_pixels"]
		var bounds:=Rect2(a[0],a[1],a[2],a[3])
		if not Art.relevant(bounds):continue
		var result: Image=await render(folder.path_join(entry["images"]["4"]),bounds,Vector2i(1032,1032))
		for quality: int in [4,2,1]:
			var output: Image=result.duplicate()
			if quality!=4:output.resize(258*quality,258*quality,Image.INTERPOLATE_LANCZOS)
			var path: String=folder.path_join(entry["images"][str(quality)])
			if output.save_png(path)!=OK:quit(1);return
			repaired.append(path.trim_prefix(game.package_root+"/"))
		count+=1
		if count%30==0:print("SPORT_HD ",count)
	var file:=FileAccess.open(game.package_root.path_join("runtime/stadium_repair.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"hd_tiles":count,"files":repaired,"track_m":[150,250],"pitch_m":[120,180],"goal_width_m":7.32,"centre_circle_diameter_m":18.3,"original_assets_edited":false},"  "));file.close()
	print("SPORT_REPAIR_COMPLETE ",count," tiles / ",repaired.size()," images");quit()
