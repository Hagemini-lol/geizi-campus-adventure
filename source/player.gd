extends CharacterBody2D

const WalkAnimation=preload("res://walk_animation.gd")
var gait:=WalkAnimation.new()

var frozen := false
var camera: Camera2D
var artwork: Sprite2D
var frames: Array[Texture2D] = []
var facing := 0
var walking_speed := 100.8 # 4.2 meters / second: former running speed
var running_speed := 201.6 # 8.4 meters / second: 2x
var auto_speed := 504.0 # 21 meters / second: 5x
var game: Node2D
var path := PackedVector2Array()
var stuck_time := 0.0
const HEIGHT := 40.8 # 1.70 meters
const RADIUS := 7.2 # 0.30 meters

func _ready() -> void:
	z_index = 10
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	collision.shape = shape
	add_child(collision)
	artwork = Sprite2D.new()
	artwork.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(artwork)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.zoom = Vector2.ONE * 1.5
	add_child(camera)
	camera.make_current()

func set_art(image: Image) -> void:
	# Crop four static directions in memory; never write sprite files to disk.
	var boxes: Array[Rect2i] = [Rect2i(285, 28, 295, 594), Rect2i(674, 28, 294, 594), Rect2i(962 - 632, 637, 202, 585), Rect2i(734, 637, 203, 585)]
	for box: Rect2i in boxes:
		var crop := image.get_region(box)
		crop.generate_mipmaps()
		frames.append(ImageTexture.create_from_image(crop))
	show_direction(0)

func show_direction(index: int) -> void:
	facing = index
	if gait.ready:
		gait.face(index)
		return
	if frames.is_empty():
		return
	artwork.texture = frames[index]
	var factor := HEIGHT / float(frames[index].get_height())
	artwork.scale = Vector2(factor, factor)
	artwork.position = Vector2(0, -HEIGHT * 0.5 + 1)

func set_walk_art(root: String, entry: Dictionary) -> bool:
	artwork.position=Vector2.ZERO
	return gait.configure(root,entry,artwork,HEIGHT,frames,1.0)

func input_direction() -> Vector2:
	if game!=null and game.mobile_controls!=null and not game.mobile_controls.direction.is_zero_approx():
		return game.mobile_controls.direction
	return Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))).normalized()

func _physics_process(delta: float) -> void:
	var direction := Vector2.ZERO if frozen else input_direction()
	var sprint: bool=Input.is_physical_key_pressed(KEY_SHIFT) or (game!=null and game.mobile_controls!=null and game.mobile_controls.running)
	var speed := running_speed if sprint else walking_speed
	if not direction.is_zero_approx():
		path.clear()
	elif not frozen:
		while not path.is_empty() and position.distance_to(path[0]) < 3.0:
			var target:=path[0]
			if game!=null:
				# A waypoint can lie exactly on a road border. Do not consume it
				# on the previous side merely because it is within the arrival radius.
				if game.motion_navigation().region_at(position)!=game.motion_navigation().region_at(target):
					if game.allow_motion(position,target): position=target
					elif game.transition_busy: return
					else: break
				elif game.motion_navigation().segment_clear(position,target): position=target
				else: break
			path.remove_at(0)
		if not path.is_empty():
			direction = position.direction_to(path[0])
			speed = minf(auto_speed,position.distance_to(path[0])/maxf(delta,0.001))
	velocity = direction * speed
	if not direction.is_zero_approx():
		var index := (3 if direction.x > 0 else 2) if absf(direction.x) > absf(direction.y) else (0 if direction.y > 0 else 1)
		if index != facing:
			show_direction(index)
	if game != null and not velocity.is_zero_approx() and not game.allow_motion(position,position+velocity*delta):
		velocity = Vector2.ZERO
	var before := position
	move_and_slide()
	if not path.is_empty() and not frozen:
		stuck_time = stuck_time + delta if position.distance_to(before)<0.05 else 0.0
		if stuck_time > 0.4:
			path.clear()
			game.show_notice("路线被阻挡，请重新点击目的地")
	else: stuck_time = 0.0
	gait.advance(delta,position.distance_to(before)/maxf(delta,.001) if not frozen else 0.0)
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, 9.0, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO)
