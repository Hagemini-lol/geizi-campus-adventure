extends Node2D

const District = preload("res://district_scene.tscn")
var model: Dictionary
var asset_root := ""
var tree_texture: Texture2D
var current_scene: Node2D
var current_id := -1
var transition_count := 0
var active_texture_bytes := 0
var max_scene_count := 0
var static_regions: Dictionary={}
var hd_manifest: Dictionary={}

func configure(value: Dictionary, directory: String) -> void:
	y_sort_enabled = true
	model = value
	asset_root = directory
	var hd: Variant=JSON.parse_string(FileAccess.get_file_as_string(asset_root.path_join("静态区块/高清切片/清单.json"))) if FileAccess.file_exists(asset_root.path_join("静态区块/高清切片/清单.json")) else null
	if hd is Dictionary:hd_manifest=hd
	var manifest: Variant=JSON.parse_string(FileAccess.get_file_as_string(asset_root.path_join("静态区块/清单.json")))
	if manifest is Dictionary:
		for entry: Dictionary in manifest.get("regions",[]): static_regions[str(entry["id"])]=entry
		for region: Dictionary in model["regions"]:
			var entry: Dictionary=static_regions.get(str(region["id"]),{})
			if entry.has("visual_bounds"):
				region["visual_bounds"]=entry["visual_bounds"]
				region["visual_areas"]=entry["visual_areas"]
	var tree := Image.load_from_file(asset_root.path_join("高清区块/tree.png"))
	tree = tree.get_region(tree.get_used_rect())
	tree.generate_mipmaps()
	tree_texture = ImageTexture.create_from_image(tree)

func unload() -> void:
	if is_instance_valid(current_scene):
		current_scene.free()
	current_scene = null
	current_id = -1
	active_texture_bytes = 0

func load_region(index: int) -> bool:
	if current_scene != null: unload()
	var region: Dictionary = model["regions"][index]
	var entry: Dictionary=static_regions.get(str(region["id"]),{})
	if entry.is_empty(): return false
	var path := asset_root.path_join(str(entry["image"]))
	if not FileAccess.file_exists(path): return false
	var image := Image.load_from_file(path)
	if image == null or image.is_empty(): return false
	var pixels: Array=entry["pixels"]
	if image.get_size()!=Vector2i(pixels[0],pixels[1]): return false
	# These PNGs already include the complete ground, facade and window layers.
	# Do not crop: exact bounds keep artwork and physical coordinates aligned.
	active_texture_bytes = image.get_width()*image.get_height()*4
	var map_texture := ImageTexture.create_from_image(image)
	current_scene = District.instantiate()
	current_scene.model = model
	current_scene.index = index
	current_scene.texture = map_texture
	current_scene.tree_texture = tree_texture
	current_scene.hd_manifest=hd_manifest
	current_scene.hd_directory=asset_root.path_join("静态区块/高清切片")
	add_child(current_scene)
	current_id = index
	transition_count += 1
	max_scene_count = maxi(max_scene_count,get_child_count())
	return true

func trim_frame(image: Image) -> Image:
	# The generator sometimes letterboxes wide/tall maps. Remove empty black
	# margins only in memory; the external original PNG remains untouched.
	var left:=0
	var right:=image.get_width()-1
	var top:=0
	var bottom:=image.get_height()-1
	while top<bottom and blank_row(image,top):top+=1
	while bottom>top and blank_row(image,bottom):bottom-=1
	while left<right and blank_column(image,left,top,bottom):left+=1
	while right>left and blank_column(image,right,top,bottom):right-=1
	return image.get_region(Rect2i(left,top,right-left+1,bottom-top+1))

func blank_row(image: Image, y: int) -> bool:
	for x: int in range(0,image.get_width(),8):
		var c:=image.get_pixel(x,y)
		if c.r+c.g+c.b>0.12 and c.a>0.1:return false
	return true

func blank_column(image: Image, x: int, top: int, bottom: int) -> bool:
	for y: int in range(top,bottom+1,8):
		var c:=image.get_pixel(x,y)
		if c.r+c.g+c.b>0.12 and c.a>0.1:return false
	return true
