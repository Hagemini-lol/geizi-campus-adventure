extends Node2D

const PPM := 24.0
var model: Dictionary
var index := -1
var texture: Texture2D
var tree_texture: Texture2D
var texture_bytes := 0
var hd_manifest: Dictionary={}
var hd_directory: String
var hd_layer: Node2D

func _ready() -> void:
	y_sort_enabled = true
	var region: Dictionary = model["regions"][index]
	name = str(region["id"])
	var v: Array = region.get("visual_bounds",region["world_bounds"])
	var bounds := Rect2(v[0],v[1],v[2],v[3])
	for area: Array in region.get("visual_areas",region["world_areas"]):
		var box := Rect2(area[0],area[1],area[2],area[3])
		var slice := AtlasTexture.new()
		slice.atlas = texture
		slice.region = Rect2((box.position-bounds.position)/bounds.size*texture.get_size(),box.size/bounds.size*texture.get_size())
		slice.filter_clip = true
		var sprite := Sprite2D.new()
		sprite.texture = slice
		sprite.centered = false
		sprite.position = box.position * PPM
		sprite.scale = box.size * PPM / slice.get_size()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.z_index = -5
		add_child(sprite)
	if not hd_manifest.is_empty():
		hd_layer=Node2D.new()
		hd_layer.set_script(preload("res://hd_tiles.gd"))
		hd_layer.manifest=hd_manifest
		hd_layer.directory=hd_directory
		hd_layer.region_bounds=Rect2(bounds.position*PPM,bounds.size*PPM)
		add_child(hd_layer)
	var details := Node2D.new()
	details.name="StaticMap"
	details.set_script(preload("res://static_map_details.gd"))
	details.map_texture = texture
	details.map_bounds = Rect2(bounds.position*PPM,bounds.size*PPM)
	for j: int in range(model["solids"].size()):
		var a: Array=model["solids"][j]
		var box:=Rect2(a[0],a[1],a[2],a[3])
		if not box.intersects(bounds): continue
		var owner: String=model["solid_owners"][j]
		details.parts.append({"box":Rect2(box.position*PPM,box.size*PPM),"owner":owner})
	add_child(details)
	for j: int in range(model["solids"].size()):
		var values: Array=model["solids"][j]
		var box := Rect2(values[0],values[1],values[2],values[3])
		if box.intersects(bounds.grow(1.0)): add_box(box,str(model["solid_owners"][j]))
	for values: Array in model.get("ellipses",[]):
		var box:=Rect2(values[0],values[1],values[2],values[3])
		if box.intersects(bounds): add_ellipse(box)
	for tree: Array in model["trees"]:
		if bounds.grow(3).has_point(Vector2(tree[0],tree[1])): add_tree(Vector2(tree[0],tree[1])*PPM)
	# Only the campus perimeter is physical; administrative boundaries use road gates.
	for box: Rect2 in [Rect2(-1,-1,322,1),Rect2(-1,360,322,1),Rect2(-1,0,1,360),Rect2(320,0,1,360)]:
		if box.intersects(bounds.grow(1)): add_box(box)

func add_box(box: Rect2, owner: String="campus_boundary") -> void:
	var body := StaticBody2D.new()
	body.set_meta("owner",owner)
	body.set_meta("world_box",Rect2(box.position*PPM,box.size*PPM))
	body.position = box.get_center()*PPM
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = box.size*PPM
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func add_ellipse(box: Rect2) -> void:
	var body:=StaticBody2D.new()
	body.position=box.get_center()*PPM
	body.set_meta("owner","fountain_basin")
	body.set_meta("world_box",Rect2(box.position*PPM,box.size*PPM))
	var collision:=CollisionShape2D.new()
	var shape:=ConvexPolygonShape2D.new()
	var points:=PackedVector2Array()
	for i: int in range(48): points.append(Vector2(cos(i*TAU/48),sin(i*TAU/48))*box.size*PPM/2)
	shape.points=points
	collision.shape=shape
	body.add_child(collision)
	add_child(body)

func add_tree(at: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = at
	body.z_index = 10
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 0.175*PPM
	collision.shape = shape
	body.add_child(collision)
	var sprite := Sprite2D.new()
	sprite.texture = tree_texture
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.scale = Vector2(3.5,4.5)*PPM/tree_texture.get_size()
	sprite.position = Vector2(0,-4.5*PPM*0.5+2)
	body.add_child(sprite)
	add_child(body)
