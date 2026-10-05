extends SceneTree

var game: Node2D
var checks:=0
var failures: Array[String]=[]
var travel_targets:=0
var movement_frames:=0

func _initialize() -> void:call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition:failures.append(message);push_error(message)

func walk_to(target: Vector2) -> bool:
	if not game.request_path(target):
		print("PATH_REJECT ",game.player.position," -> ",target)
		return false
	var frames:=0
	var initial_route: PackedVector2Array=game.player.path.duplicate()
	while not game.player.path.is_empty():
		await physics_frame
		frames+=1
		movement_frames+=1
		if frames>2000:return false
	var arrived: bool=game.player.position.distance_to(target)<3
	if not arrived:print("MOVE_STOP ",game.player.position," -> ",target," initial ",initial_route," remaining ",game.player.path," stuck ",game.player.stuck_time)
	return arrived

func run() -> void:
	game=(load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	Engine.time_scale=4
	Engine.physics_ticks_per_second=240
	for room: int in [0,1]:
		game.change_interior({"kind":"classroom","building":"B12","floor":3,"room":room})
		while game.transition_busy:await process_frame
		await physics_frame
		game.interaction_delay=100000
		var scene: Node2D=game.terrain.current_scene
		check(scene.blockers.size()==34,"32 desks/chairs, lectern and cupboard retain collision cores")
		check(scene.furniture_footprints.size()==34,"all furniture reduced")
		var physical:=0
		for body: Node in scene.get_children():
			if not body is StaticBody2D:continue
			var shape: RectangleShape2D=body.get_child(0).shape
			if body.name.begins_with("Furniture_"):
				check(shape.size==Vector2.ONE,"actual furniture physics is 1x1")
				physical+=1
			elif body.name.begins_with("Wall_"):
				check(shape.size.x>1 and is_equal_approx(shape.size.y,.2),"wall remains full boundary")
		check(physical==34,"all furniture collision bodies present")
		for i: int in range(34):
			var box: Rect2=scene.blockers[i]
			var footprint: Rect2=scene.furniture_footprints[i]
			check(box.size==Vector2.ONE and footprint.encloses(box),"tiny core inside furniture footprint")
			check(box.get_center().distance_to(footprint.get_center())<.01,"core remains on floor footprint")
			check(not scene.navigation.walkable(box.get_center()),"navigation retains collision core")
		# Real CharacterBody movement through the newly opened part of each
		# desk footprint and every gap between adjacent desks, for both images.
		for row: int in range(4):
			for column: int in range(8):
				var original: Rect2=scene.furniture_footprints[row*8+column]
				var target:=original.get_center()-Vector2(original.size.x*.5-1,0)
				check(original.has_point(target),"test point was inside old furniture box")
				check(scene.navigation.walkable(target),"old furniture edge now passable")
				check(await walk_to(target),"actual movement through old desk collision "+str(room)+"/"+str(row)+"/"+str(column))
				travel_targets+=1
				if column<7:
					var next: Rect2=scene.furniture_footprints[row*8+column+1]
					var gap: Vector2=(original.get_center()+next.get_center())*.5
					check(await walk_to(gap),"actual passage between adjacent desks")
					travel_targets+=1
		for portal: Dictionary in scene.portals:
			check(await walk_to(portal["at"]),"front/rear door remains reachable")
			travel_targets+=1
		check(not scene.navigation.walkable(Vector2.ZERO),"classroom exterior remains blocked")
	var report: Dictionary={"checks":checks,"passed":failures.is_empty(),"failures":failures,"furniture_collision_logical_pixels":[1,1],"classroom_types":2,"actual_walk_targets":travel_targets,"physics_frames":movement_frames,"wall_collisions_preserved":true}
	var file:=FileAccess.open(game.package_root.path_join("室内家具通行验证.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("FURNITURE_CHECK ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
