extends SceneTree
var game: Node2D
var failures: Array[String]=[]
var checks:=0
var samples: Array[Dictionary]=[]
var out:="D:/Godot/地图重绘预览/清晰度检查"
func _initialize() -> void:call_deferred("run")
func check(value: bool, name: String) -> void:
	checks+=1
	if not value:failures.append(name);push_error(name)
func frames() -> void:
	await process_frame
	await process_frame
	await process_frame
func shot(name: String) -> void:
	await frames()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join(name+".png"))
func run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	game=(load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await frames()
	game.game_started=true;game.front_end.hide_title();game.player.show()
	game.player.set_physics_process(false)
	game.player.camera.position_smoothing_enabled=false
	check(not game.terrain.hd_manifest.is_empty(),"HD manifest present")
	check(game.terrain.hd_manifest["tiles"].size()==1020,"complete school HD tile coverage")
	for entry: Dictionary in game.terrain.hd_manifest["tiles"].values():
		for quality: String in ["1","2","4"]:
			check(FileAccess.file_exists(game.terrain.asset_root.path_join("静态区块/高清切片").path_join(entry["images"][quality])),"HD cache file exists")
	for index: int in range(20):
		var region: Dictionary=game.model["regions"][index]
		var a: Array=region["world_bounds"]
		game.player.position=Vector2(a[0]+a[2]*.5,a[1]+a[3]*.5)*24
		game.load_district(index)
		game.player.camera.reset_smoothing()
		await frames()
		var layer: Node2D=game.terrain.current_scene.hd_layer
		await layer.wait_for_view()
		check(layer!=null and not layer.tiles.is_empty(),"HD layer visible "+str(region["id"]))
		check(layer.tiles.size()<100,"only viewport neighbourhood loaded "+str(region["id"]))
		check(game.terrain.get_child_count()==1,"one current district")
		for value: Dictionary in layer.tiles.values():
			check(value["node"].texture.atlas.get_image().has_mipmaps(),"HD mipmaps")
			check(value["node"].texture_filter==CanvasItem.TEXTURE_FILTER_PARENT_NODE,"HD inherits mipmap filtering")
	game.player.position=game.Space.project(Vector2(527,1120))
	game.load_district(16)
	game.player.camera.reset_smoothing()
	for zoom: float in [.6,1.5,2.4]:
		game.player.camera.zoom=Vector2.ONE*zoom
		await frames()
		var layer: Node2D=game.terrain.current_scene.hd_layer
		await layer.wait_for_view()
		var expected:=clampi(ceili(zoom-.0001),1,4)
		check(layer.lod==expected,"zoom chooses correct LOD")
		check(layer.active_bytes<100000000,"bounded visible texture memory")
		samples.append({"zoom":zoom,"lod":layer.lod,"tiles":layer.tiles.size(),"hd_texture_bytes":layer.active_bytes,"fallback_texture_bytes":game.terrain.active_texture_bytes})
		await shot("春华楼_"+str(zoom)+"倍镜头")
	var before: Dictionary=game.terrain.current_scene.hd_layer.tiles.duplicate()
	game.player.position.x+=1200
	game.player.camera.force_update_scroll()
	await frames()
	await game.terrain.current_scene.hd_layer.wait_for_view()
	var released:=0
	for value: Dictionary in before.values():
		if not is_instance_valid(value["node"]):released+=1
	check(released>0,"offscreen HD textures freed")
	game.change_interior({"kind":"corridor","building":"B12","floor":3})
	while game.transition_busy:await process_frame
	check(game.terrain.get_child_count()==1 and game.terrain.current_scene.get("hd_layer")==null,"outdoor HD layer unloaded indoors")
	var corridor: Node2D=game.terrain.current_scene
	check(corridor.background.texture.get_width()>=6000 and corridor.background.texture.get_height()>=650,"corridor baked at 3x")
	check((corridor.background.texture.get_size()*corridor.background.scale).distance_to(corridor.dimensions)<.01,"corridor world scale unchanged")
	check(corridor.background.texture.get_image().has_mipmaps(),"corridor mipmaps")
	await shot("三楼走廊_高清")
	for room: int in [0,1]:
		game.change_interior({"kind":"classroom","building":"B12","floor":3,"room":room})
		while game.transition_busy:await process_frame
		check(game.terrain.current_scene.background.texture.get_width()>=1536,"classroom uses original resolution")
		check(game.terrain.current_scene.background.texture.get_image().has_mipmaps(),"classroom mipmaps")
		await shot("十班_高清" if room==0 else "普通教室_高清")
	check(game.player.artwork.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,"hero antialiased mipmaps")
	# Check logical scaling at larger rendering surfaces. Resolution-aware zoom
	# caps prevent baked textures being stretched beyond their useful detail.
	for location: String in ["classroom","corridor","outdoor"]:
		if location=="corridor":
			game.change_interior({"kind":"corridor","building":"B12","floor":3})
		elif location=="outdoor":
			game.begin_transition(16,game.Space.project(Vector2(527,1120)))
		while game.transition_busy:await process_frame
		for dimensions: Vector2i in [Vector2i(1920,1200),Vector2i(3840,2400)]:
			root.size=dimensions
			await frames()
			game.player.camera.zoom=Vector2.ONE*2.4
			await frames()
			var stretch:=root.get_stretch_transform().get_scale().x
			var density: float=4.0 if location=="outdoor" else (3.0 if location=="corridor" else 1.0/game.terrain.current_scene.background.scale.x)
			check(game.player.camera.zoom.x*stretch<=density+.001,"large-window "+location+" zoom cap")
	root.size=Vector2i(1280,800)
	await frames()
	var file:=FileAccess.open(out.path_join("清晰度验证.json"),FileAccess.WRITE)
	var report: Dictionary={"checks":checks,"failures":failures,"passed":failures.is_empty(),"outdoor_density":4,"corridor_density":3,"viewport_samples":samples,"old_tiles_freed":released}
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("CLARITY_CHECK ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
