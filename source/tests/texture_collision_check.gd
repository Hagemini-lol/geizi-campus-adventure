extends SceneTree
var game: Node2D
var checks: Array[String]=[]
var failures: Array[String]=[]
var texture_rows: Array[Dictionary]=[]
var tested_rects:=0
var tested_trees:=0

func _initialize() -> void: call_deferred("run")
func require(condition: bool, name: String) -> void:
	checks.append(name)
	if not condition: failures.append(name); push_error(name)

func hit(at: Vector2, radius: float=.3*24) -> bool:
	var query:=PhysicsShapeQueryParameters2D.new()
	var shape:=CircleShape2D.new()
	shape.radius=radius
	query.shape=shape
	query.transform.origin=at
	query.exclude=[game.player.get_rid()]
	return not game.player.get_world_2d().direct_space_state.intersect_shape(query).is_empty()

func run() -> void:
	game=(load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await physics_frame
	game.player.set_physics_process(false)
	require(game.load_error.is_empty(),"all_external_references_resolve")
	for index: int in range(20):
		game.load_district(index)
		await physics_frame
		await physics_frame
		var id: String=game.model["regions"][index]["id"]
		var details: Node2D
		var sprites: Array[Sprite2D]=[]
		var bodies: Array[StaticBody2D]=[]
		for child: Node in game.terrain.current_scene.get_children():
			if child is Sprite2D: sprites.append(child)
			elif child is StaticBody2D: bodies.append(child)
			elif child.get_script()==load("res://static_map_details.gd"): details=child
		require(details!=null,"baked_geometry_metadata_exists_"+id)
		require(not details.is_processing() and not details.has_method("_draw"),"no_runtime_facade_drawing_"+id)
		var actual_areas: Array=game.model["regions"][index].get("visual_areas",game.model["regions"][index]["world_areas"])
		var mapping_ok:=sprites.size()==actual_areas.size()
		for j: int in range(sprites.size()):
			var sprite: Sprite2D=sprites[j]
			var atlas: AtlasTexture=sprite.texture
			var values: Array=actual_areas[j]
			var expected:=Rect2(values[0]*24,values[1]*24,values[2]*24,values[3]*24)
			var uv:=atlas.region
			mapping_ok=mapping_ok and sprite.position.distance_to(expected.position)<.01 and (sprite.texture.get_size()*sprite.scale).distance_to(expected.size)<.1
			mapping_ok=mapping_ok and uv.position.x>=-.01 and uv.position.y>=-.01 and uv.end.x<=atlas.atlas.get_width()+.01 and uv.end.y<=atlas.atlas.get_height()+.01
		require(mapping_ok,"texture_uv_and_world_areas_match_"+id)
		var aligned:=true
		for part: Dictionary in details.parts:
			var full: Rect2=part["box"]
			var found:=false
			for body: StaticBody2D in bodies:
				if not body.has_meta("world_box") or body.get_meta("owner")!=part["owner"]: continue
				var shape: Shape2D=body.get_child(0).shape
				if shape is RectangleShape2D and body.position.distance_to(full.get_center())<.01 and shape.size.distance_to(full.size)<.01:
					found=true
					tested_rects+=1
					require(hit(full.get_center(),.1),"physical_body_exists_"+id+"_"+str(tested_rects))
					break
			aligned=aligned and found
		require(aligned,"visible_solid_footprints_equal_colliders_"+id)
		for body: StaticBody2D in bodies:
			var child: CollisionShape2D=body.get_child(0)
			if not child.shape is CircleShape2D: continue
			var art: Sprite2D=body.get_child(1)
			tested_trees+=1
			aligned=aligned and is_equal_approx(child.shape.radius,4.2) and (art.texture.get_size()*art.scale).distance_to(Vector2(84,108))<.01
			require(hit(body.position,.1),"tree_trunk_collision_"+str(tested_trees))
		require(aligned,"tree_art_scale_and_trunk_match_"+id)
		var pixels: Vector2i=details.map_texture.get_size()
		texture_rows.append({"id":id,"pixels":[pixels.x,pixels.y],"parts":details.parts.size(),"colliders":bodies.size()})
	game.load_district(8)
	await physics_frame
	await physics_frame
	var e: Array=game.model["ellipses"][0]
	var ellipse:=Rect2(e[0]*24,e[1]*24,e[2]*24,e[3]*24)
	require(hit(ellipse.get_center()),"fountain_water_blocks_player")
	require(not hit(ellipse.position+Vector2.ONE*12),"fountain_rectangular_corner_is_walkable")
	require(not game.navigation.walkable(ellipse.get_center()),"fountain_navigation_matches_physics")
	require(game.navigation.walkable(ellipse.position+Vector2.ONE*12),"fountain_corner_navigation_is_walkable")
	game.load_district(15)
	await physics_frame
	await physics_frame
	var court: Vector2=game.Space.project(Vector2(910,1190))
	require(not hit(court) and game.navigation.walkable(court),"dormitory_inner_courtyard_remains_open")
	game.load_district(4)
	await physics_frame
	await physics_frame
	require(not hit(game.Space.project(Vector2(556,335))),"covered_passage_between_posts_is_open")
	var building: Array=game.model["solids"][1]
	var center:=Vector2(building[0]+building[2]/2,building[1]+building[3]/2)*24
	require(game.navigation.route(game.spawn,center).is_empty(),"clicking_inside_building_does_not_route_into_wall")
	require(not game.navigation.segment_clear(center-Vector2((building[2]/2+1)*24,0),center+Vector2((building[2]/2+1)*24,0)),"movement_segment_cannot_tunnel_through_building")
	var all_gates_safe:=true
	game.load_district(0)
	await physics_frame
	require(not hit(game.Space.project(Vector2(245,55))),"north_gate_passage_open_in_physics")
	require(game.navigation.walkable(game.Space.project(Vector2(245,55))),"north_gate_passage_open_in_navigation")
	game.load_district(19)
	await physics_frame
	require(not hit(game.Space.project(Vector2(527,1354))),"south_gate_passage_open_in_physics")
	require(game.navigation.walkable(game.Space.project(Vector2(527,1354))),"south_gate_passage_open_in_navigation")
	require(hit(game.Space.project(Vector2(395,1250))),"outdoor_screen_has_matching_solid_body")
	for gate: Array in game.model["gates"]:
		var at:=Vector2(gate[2],gate[3])*24
		all_gates_safe=all_gates_safe and game.navigation.walkable(at)
	require(all_gates_safe,"all_road_gate_arrivals_clear_buildings_and_trees")
	for prop: Dictionary in game.model["props"]:
		game.load_district(int(prop["region"]))
		await physics_frame
		await physics_frame
		var r: Array=prop["rect"]
		var at:=Vector2(r[0]+r[2]/2,r[1]+r[3]/2)*24
		require(hit(at,.1),"sport_fixture_blocks_"+str(checks.size()))
		require(not game.navigation.walkable(at),"sport_fixture_navigation_blocks_"+str(checks.size()))
		var a: Array=game.model["regions"][int(prop["region"])]["world_bounds"]
		var uv: Array=prop["texture_anchor"]
		var image_point:=Vector2(a[0]+uv[0]*a[2],a[1]+uv[1]*a[3])*24
		require(image_point.distance_to(at)<.01,"sport_fixture_texture_anchor_matches_"+str(checks.size()))
	game.debug_geometry=true
	await process_frame
	await process_frame
	require(game.collision_overlay.visible and game.collision_overlay.z_index>game.player.z_index,"f3_overlay_is_above_textures_and_player")
	var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"rectangles_verified":tested_rects,"trees_verified":tested_trees,"regions":texture_rows,"road_gates":game.model["gates"].size()}
	var file:=FileAccess.open(game.package_root.path_join("贴图碰撞验证报告.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("TEXTURE_COLLISION_TEST checks=",checks.size()," rectangles=",tested_rects," trees=",tested_trees," failures=",failures)
	quit(0 if failures.is_empty() else 1)
