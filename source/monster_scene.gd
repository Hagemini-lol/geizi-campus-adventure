extends Node2D

var game: Node2D
var scene: Node2D
var records: Array[Dictionary]=[]
var key: String
var textures: Dictionary={}
var idle_frames: Dictionary={}
var animation_clock:=0.0
var animation_step:=0

static func portrait(path: String) -> Texture2D:
	var image:=Image.load_from_file(path)
	if image==null:return null
	# The monster sheets contain four directions in a 2 x 2 layout.
	var crop:=image.get_region(Rect2i(0,0,image.get_width()/2,image.get_height()/2))
	crop=crop.get_region(crop.get_used_rect())
	crop.generate_mipmaps()
	return ImageTexture.create_from_image(crop)

func setup(owner_game: Node2D, owner_scene: Node2D) -> void:
	game=owner_game;scene=owner_scene
	key=game.monster_world.zone_key(game.interior_state)
	y_sort_enabled=true
	refresh()

func refresh() -> void:
	for child: Node in get_children():remove_child(child);child.queue_free()
	records.clear();textures.clear();idle_frames.clear()
	var rule: Dictionary=game.monster_world.zone_rule(game.interior_state)
	if rule.is_empty():return
	var population: Array=game.monster_world.activate(game.interior_state)
	for monster: Dictionary in population:
		var at:=spawn_point(monster,rule)
		if not is_finite(at.x):continue
		monster["position"]=[at.x,at.y]
		var spec: Dictionary=game.combat_rules.data["monsters"][monster["id"]]
		if not textures.has(monster["id"]):
			textures[monster["id"]]=portrait(game.battle_asset_root.path_join(spec["art"]))
			load_idle_frames(str(monster["id"]),spec)
		var texture: Texture2D=textures[monster["id"]]
		if texture==null:continue
		var sprite:=Sprite2D.new();sprite.texture=texture;sprite.z_index=10
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var height:=float(spec.get("world_height",40.8))
		sprite.scale=Vector2.ONE*height/texture.get_height();sprite.offset=Vector2(0,-texture.get_height()*.5)
		sprite.position=at;add_child(sprite)
		records.append({"uid":monster["uid"],"name":spec["name"],"at":at,"height":height,"width":texture.get_width()*sprite.scale.x,"monster":monster,"sprite":sprite})
	set_process(not records.is_empty())

func load_idle_frames(id: String, spec: Dictionary) -> void:
	var path: String=spec.get("portrait_atlas","")
	if path.is_empty():return
	var image:=Image.load_from_file(game.battle_asset_root.path_join(path))
	if image==null:return
	# World animation only needs three small poses; it never uploads the
	# full battle atlas into every monster's texture memory.
	var frames: Array[Texture2D]=[]
	for i: int in range(3):
		var crop:=image.get_region(Rect2i(i*256,0,256,320));crop.resize(96,120,Image.INTERPOLATE_LANCZOS)
		crop.generate_mipmaps();frames.append(ImageTexture.create_from_image(crop))
	idle_frames[id]=frames

func _process(delta: float) -> void:
	if game.player.frozen or game.transition_busy:return
	animation_clock+=delta
	if animation_clock<1.0/3.0:return
	animation_clock=fmod(animation_clock,1.0/3.0);animation_step=(animation_step+1)%2
	for record: Dictionary in records:
		var frames: Array=idle_frames.get(record["monster"]["id"],[])
		if frames.is_empty():continue
		var sprite: Sprite2D=record["sprite"]
		var alert: bool=game.player.position.distance_squared_to(record["at"])<1600
		sprite.texture=frames[2 if alert else animation_step]
		sprite.scale=Vector2.ONE*float(record["height"])/120.0;sprite.offset=Vector2(0,-60)

func spawn_point(monster: Dictionary, rule: Dictionary) -> Vector2:
	var limits:=Rect2(Vector2.ZERO,scene.dimensions)
	if rule.has("bounds"):limits=game.rect(rule["bounds"])
	if monster.get("position") is Array and monster["position"].size()==2:
		var saved: Vector2=game.point(monster["position"])
		if usable(saved,limits,false):return saved
	for attempt: int in range(200):
		var candidate:=Vector2(game.monster_world.rng.randf_range(limits.position.x,limits.end.x),game.monster_world.rng.randf_range(limits.position.y,limits.end.y))
		if usable(candidate,limits,true):return candidate
	# Bounded fallback avoids an invisible monster when the room is narrow.
	var grid: AStarGrid2D=scene.navigation.astar
	for y: int in range(grid.region.size.y):
		for x: int in range(grid.region.size.x):
			var cell:=Vector2i(x,y)
			if grid.is_point_solid(cell):continue
			var candidate:=grid.get_point_position(cell)
			if usable(candidate,limits,false):return candidate
	return Vector2(INF,INF)

func usable(at: Vector2, limits: Rect2, avoid_player: bool) -> bool:
	if not limits.has_point(at) or not scene.navigation.walkable(at):return false
	if avoid_player and at.distance_to(game.player.position)<55:return false
	for portal: Dictionary in scene.portals:
		if at.distance_to(portal["at"])<28:return false
	for record: Dictionary in records:
		if at.distance_to(record["at"])<24:return false
	return true

func find(uid: String) -> Dictionary:
	for record: Dictionary in records:
		if record["uid"]==uid:return record
	return {}

func interactions() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for record: Dictionary in records:
		var at: Vector2=record["at"]
		result.append({"action":"monster","uid":record["uid"],"name":record["name"],"at":at,"trigger":Rect2(),"art_rect":Rect2(at-Vector2(record["width"]*.5,record["height"]),Vector2(record["width"],record["height"]))})
	return result

func approach(uid: String, from: Vector2) -> PackedVector2Array:
	var record:=find(uid)
	if record.is_empty():return PackedVector2Array()
	var at: Vector2=record["at"]
	for radius: int in [9,11]:
		for step: int in range(12):
			var target:=at+Vector2.from_angle(step*TAU/12)*radius
			if scene.navigation.walkable(target):
				var route: PackedVector2Array=scene.navigation.route(from,target)
				if not route.is_empty():return route
	return PackedVector2Array()
