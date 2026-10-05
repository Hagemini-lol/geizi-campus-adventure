extends SceneTree
var game: Node2D

func _initialize() -> void: call_deferred("capture")

func capture() -> void:
	game=(load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.player.set_physics_process(false)
	# The camera is centered for map inspection; hide the teleported test hero.
	game.player.hide()
	game.debug_geometry=true
	var out: String=game.package_root.get_base_dir().path_join("地图重绘预览/贴图碰撞检查")
	DirAccess.make_dir_recursive_absolute(out)
	var sheet:=Image.create(1280,800,false,Image.FORMAT_RGBA8)
	for index: int in range(20):
		game.load_district(index)
		var region: Dictionary=game.model["regions"][index]
		var a: Array=region.get("visual_bounds",region["world_bounds"])
		var box:=Rect2(a[0]*24,a[1]*24,a[2]*24,a[3]*24)
		game.player.position=box.get_center()
		game.player.camera.zoom=Vector2.ONE*minf(1160/box.size.x,610/box.size.y)
		game.player.camera.reset_smoothing()
		for i: int in range(4): await physics_frame
		await RenderingServer.frame_post_draw
		var frame:=root.get_texture().get_image()
		frame.save_png(out.path_join(str(game.model["regions"][index]["id"])+".png"))
		frame.resize(640,400,Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(frame,Rect2i(0,0,640,400),Vector2i((index%2)*640,((index%4)/2)*400))
		if index%4==3: sheet.save_png(out.path_join("检查总览_"+str(index/4)+".png"))
	print("TEXTURE_AUDIT_CAPTURES ",out)
	quit()
