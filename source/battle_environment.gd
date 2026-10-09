extends Node2D

# One static render per encounter; share outdoor textures and exclude actors/UI.
var room_style:=""
var scene_bounds:=Rect2()
var scene_name:=""
var copied_sprites:=0
var ally_foot:=Vector2(.25,.90)
var enemy_foot:=Vector2(.73,.70)

func capture(game: Node2D, owner_node: Node) -> Texture2D:
	var scene: Node2D=game.terrain.current_scene
	if scene==null:owner_node.add_child(self);scene_name="战斗演练";return null
	var view:=SubViewport.new();view.size=Vector2i(1280,720)
	view.disable_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ONCE
	owner_node.add_child(view);view.add_child(self)
	modulate=game.day_clock.tint(not game.interior_state.is_empty())
	var center: Vector2=game.player.position
	var extent:=Vector2(600,337.5)
	if not game.interior_state.is_empty():
		scene_name=scene.title;room_style=str(scene.get("room_style")) if scene.get("room_style")!=null else ""
		scene_bounds=Rect2(Vector2.ZERO,scene.dimensions);center=scene.dimensions*.5;extent=scene.dimensions
		var clean: Texture2D=scene.background.texture
		if not scene.source_path.is_empty():
			var image:=Image.load_from_file(scene.source_path)
			if image!=null:
				if scene.is_ten_class:image=image.get_region(Rect2i(0,0,1596,912))
				if image.get_width()>1536:image.resize(1536,roundi(image.get_height()*1536.0/image.get_width()),Image.INTERPOLATE_LANCZOS)
				clean=ImageTexture.create_from_image(image)
		var sprite:=Sprite2D.new();sprite.centered=false;sprite.texture=clean
		sprite.scale=scene.dimensions/clean.get_size();sprite.z_index=-5;add_child(sprite);copied_sprites+=1
		# Story rooms contain code-native props outside the clean background.
		if scene.source_path.is_empty():
			for child: Node in scene.get_children():
				if child is Polygon2D:copy_static(child)
				elif child is Sprite2D and child!=scene.background:copy_static(child)
	else:
		scene_name=str(game.model["regions"][game.terrain.current_id]["name"])
		var region: Dictionary=game.model["regions"][game.terrain.current_id]
		var raw: Array=region.get("visual_bounds",region["world_bounds"])
		scene_bounds=Rect2(float(raw[0])*24,float(raw[1])*24,float(raw[2])*24,float(raw[3])*24)
		center.x=clampf(center.x,scene_bounds.position.x+minf(300,scene_bounds.size.x*.5),scene_bounds.end.x-minf(300,scene_bounds.size.x*.5))
		center.y=clampf(center.y,scene_bounds.position.y+minf(169,scene_bounds.size.y*.5),scene_bounds.end.y-minf(169,scene_bounds.size.y*.5))
		for child: Node in scene.get_children():
			if child is Sprite2D:copy_static(child)
			elif child==scene.hd_layer:
				for tile: Node in child.get_children():
					if tile is Sprite2D:copy_static(tile)
			elif child is StaticBody2D:
				for tree: Node in child.get_children():
					if tree is Sprite2D:copy_static(tree)
	var camera:=Camera2D.new();camera.position=center
	# Fit the whole interior: furniture and doors remain recognisable.
	camera.zoom=Vector2.ONE*minf(1280.0/extent.x,720.0/extent.y)
	if not game.interior_state.is_empty():
		var feet: Array[Vector2]=[]
		for wanted: Vector2 in [scene.dimensions*Vector2(.25,.90),scene.dimensions*Vector2(.73,.72)]:
			var nearest:=wanted;var distance:=INF;var grid: AStarGrid2D=scene.navigation.astar
			for y: int in range(grid.region.size.y):
				for x: int in range(grid.region.size.x):
					var cell:=Vector2i(x,y)
					if grid.is_point_solid(cell):continue
					var point: Vector2=grid.get_point_position(cell)
					if point.distance_squared_to(wanted)<distance:distance=point.distance_squared_to(wanted);nearest=point
			feet.append(((nearest-center)*camera.zoom+Vector2(640,360))/Vector2(1280,720))
		ally_foot=feet[0];enemy_foot=feet[1]
	add_child(camera);queue_redraw()
	return view.get_texture()

func copy_static(source: Node2D) -> void:
	var clone: Node2D
	if source is Sprite2D:
		clone=Sprite2D.new();clone.texture=source.texture;clone.centered=source.centered
		clone.offset=source.offset;clone.region_enabled=source.region_enabled;clone.region_rect=source.region_rect
		clone.flip_h=source.flip_h;clone.flip_v=source.flip_v;copied_sprites+=1
	elif source is Polygon2D:
		clone=Polygon2D.new();clone.polygon=source.polygon;clone.color=source.color
	else:return
	clone.transform=source.global_transform;clone.z_index=source.z_index
	clone.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;add_child(clone)
	for child: Node in source.get_children():
		if child is Polygon2D:copy_static(child)

func _draw() -> void:
	if room_style in ["house","seal"]:
		for y: int in range(60,205,12):draw_line(Vector2(0,y),Vector2(307,y),Color("708080"),.45,true)
	if room_style=="library":
		for x: int in [65,110,155]:
			draw_rect(Rect2(x,39,35,29),Color("5b4430"));draw_rect(Rect2(x+2,42,31,21),Color("2c3234"))
			for n: int in range(9):draw_rect(Rect2(x+3+n*3,44,2,17),[Color("a46551"),Color("7b9398"),Color("c3ad72")][n%3])
	if room_style in ["ritual","seal"]:
		draw_arc(Vector2(151,85),23,0,TAU,64,Color("c5a977"),1.2,true)
		draw_arc(Vector2(151,85),18,0,TAU,64,Color("738da3"),.8,true)
