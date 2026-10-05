extends SceneTree

var game: Node2D
var failures: Array[String] = []
var checks: Array[String] = []

func _initialize() -> void:
	call_deferred("run_checks")

func require(condition: bool, message: String) -> void:
	checks.append(message)
	if not condition:
		failures.append(message)
		push_error(message)

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func travel(start: Vector2, codes: Array[int], frames: int) -> Vector2:
	game.player.position = game.Space.project(start)
	game.player.set_physics_process(false)
	for code: int in codes: key(code, true)
	for index: int in range(frames):
		await physics_frame
		game.player._physics_process(1.0 / 60.0)
	for code: int in codes: key(code, false)
	var result: Vector2 = game.Space.unproject(game.player.position)
	game.player.velocity = Vector2.ZERO
	return result

func run_checks() -> void:
	game = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	require(game.load_error.is_empty(), "external_assets_load")
	if game.player == null:
		quit(1)
		return
	require(game.player.frames.size() == 4, "four_hero_directions")
	require(game.blockers.size() > 20, "map_physics_created")
	var begin := Vector2(527, 1310)
	var walking: Vector2 = await travel(begin, [KEY_W], 30)
	var running: Vector2 = await travel(begin, [KEY_W, KEY_SHIFT], 30)
	require(walking.y < begin.y - 2, "W_moves_player")
	require(begin.distance_to(running) > begin.distance_to(walking) * 1.7, "shift_runs_faster")
	require(game.player.facing == 1, "up_faces_back")
	var straight: Vector2 = await travel(Vector2(245, 500), [KEY_RIGHT], 20)
	var diagonal: Vector2 = await travel(Vector2(245, 500), [KEY_RIGHT, KEY_DOWN], 20)
	var anchor: Vector2 = game.Space.project(Vector2(245, 500))
	require(absf(game.Space.project(straight).distance_to(anchor) - game.Space.project(diagonal).distance_to(anchor)) < 0.5, "diagonal_normalized")
	await travel(Vector2(245, 500), [KEY_LEFT], 1)
	require(game.player.facing == 2, "left_faces_left")
	await travel(Vector2(245, 500), [KEY_RIGHT], 1)
	require(game.player.facing == 3, "right_faces_right")
	await travel(Vector2(245, 500), [KEY_DOWN], 1)
	require(game.player.facing == 0, "down_faces_front")
	var roof: Vector2 = await travel(Vector2(197, 185), [KEY_W, KEY_SHIFT], 45)
	require(roof.y >= 171.9, "building_blocks_movement")
	var west: Vector2 = await travel(Vector2(46, 500), [KEY_DOWN, KEY_SHIFT], 140)
	require(west.y > 520, "west_perimeter_passable")
	var east: Vector2 = await travel(Vector2(1051, 540), [KEY_DOWN, KEY_SHIFT], 140)
	require(east.y > 560, "east_perimeter_passable")
	var wall: Vector2 = await travel(Vector2(300, 68), [KEY_UP, KEY_SHIFT], 30)
	require(wall.y >= 57.0, "north_wall_blocks")
	var gate: Vector2 = await travel(Vector2(245, 68), [KEY_UP, KEY_SHIFT], 200)
	require(game.Space.project(gate).y >= 7.0, "world_boundary_blocks")
	for zone: Dictionary in game.data["zones"]:
		var query := PhysicsShapeQueryParameters2D.new()
		var shape := CircleShape2D.new()
		shape.radius = game.player.RADIUS
		query.shape = shape
		query.transform.origin = game.Space.project(game.point(zone["spawn"]))
		query.exclude = [game.player.get_rid()]
		require(game.player.get_world_2d().direct_space_state.intersect_shape(query).is_empty(), "zone_spawn_clear_" + str(zone["id"]))
	game.toggle_map()
	require(game.map_view.visible and game.player.frozen, "map_pauses_movement")
	var stopped: Vector2 = await travel(begin, [KEY_W], 10)
	require(stopped.distance_to(begin) < 0.1, "frozen_player_stays_still")
	game.toggle_map()
	require(not game.player.frozen, "map_close_resumes")
	game.toggle_pause()
	require(game.paused and game.player.frozen and game.overlay.visible, "pause_menu")
	game.toggle_pause()
	game.reset_player()
	require(game.player.position.distance_to(game.spawn) < 0.1, "reset_to_south_gate")
	var campus: Vector2 = game.Space.box_to_world(game.bounds).size / game.Space.PIXELS_PER_METER
	require(campus.distance_to(Vector2(320, 360)) < 0.001, "campus_320_by_360_meters")
	var track: Vector2 = (game.Space.project(Vector2(447, 957)) - game.Space.project(Vector2(88, 223))) / game.Space.PIXELS_PER_METER
	require(track.distance_to(Vector2(150, 250)) < 0.001, "track_150_by_250_meters")
	var pitch: Vector2 = (game.Space.project(Vector2(391, 805)) - game.Space.project(Vector2(146, 355))) / game.Space.PIXELS_PER_METER
	require(pitch.distance_to(Vector2(120, 180)) < 0.001, "football_120_by_180_meters")
	require(absf(game.player.HEIGHT / game.Space.PIXELS_PER_METER - 1.7) < 0.001, "hero_1_7_meters")
	var seam_begin: Vector2 = game.Space.unproject(Vector2(79, 180) * game.Space.PIXELS_PER_METER)
	var seam_end: Vector2 = await travel(seam_begin, [KEY_D], 60)
	require(game.Space.project(seam_end).x / game.Space.PIXELS_PER_METER > 80.7, "walk_across_region_seam")
	var before: Vector2 = game.player.position
	game.terrain.update_position(before)
	require(game.player.position == before, "scene_switch_preserves_position")
	for x: int in range(4):
		for y: int in range(4):
			game.terrain.update_position(Vector2(x * 80 + 40, y * 90 + 45) * game.Space.PIXELS_PER_METER)
			require(game.terrain.active.has(Vector2i(x, y)), "map_region_%d_%d_loads" % [x + 1, y + 1])
			require(game.terrain.active.size() <= 9, "region_stream_count_%d_%d" % [x + 1, y + 1])
	var report := {"checks": checks, "failures": failures, "passed": failures.is_empty()}
	var file := FileAccess.open(game.package_root.path_join("验证报告.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("WALK_TEST ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
