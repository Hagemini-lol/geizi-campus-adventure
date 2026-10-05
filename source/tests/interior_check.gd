extends SceneTree
const Scene=preload("res://interior_scene.gd")
var game: Node2D
var checks:=0
var failures: Array[String]=[]
var rooms:=0
var floors:=0
var maximum_bytes:=0

func _initialize() -> void: call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition: failures.append(message); push_error(message)

func wait_transition() -> void:
	while game.transition_busy: await process_frame
	await physics_frame

func walk_to(target: Vector2) -> bool:
	if not game.request_path(target):return false
	var elapsed:=0.0
	while not game.player.path.is_empty() or game.transition_busy:
		await physics_frame
		elapsed+=1.0/Engine.physics_ticks_per_second
		if elapsed>60: return false
	return game.player.position.distance_to(target)<4

func run() -> void:
	game=(load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	check(game.load_error.is_empty(),"main ready")
	game.player.set_physics_process(false)
	for entry: Dictionary in game.interior_info["entrances"]:
		check(game.navigation.walkable(game.point(entry["arrival"])*24),"outdoor arrival "+str(entry["id"]))
		check(game.navigation.walkable(game.point(entry["board_arrival"])*24),"board reachable "+str(entry["id"]))
	for id: String in game.interior_info["buildings"]:
		var building: Dictionary=game.interior_info["buildings"][id]
		for row: Dictionary in building["floors"]:
			floors+=1
			var corridor:=Scene.new()
			check(corridor.setup(game.interior_info,{"kind":"corridor","building":id,"floor":row["floor"]},game.interior_directory),"corridor texture "+id+str(row["floor"]))
			maximum_bytes=maxi(maximum_bytes,corridor.texture_bytes)
			check(corridor.navigation.walkable(corridor.landing()),"corridor landing")
			var up:=0
			var down:=0
			for item: Dictionary in corridor.portals:
				if item["action"]=="up":up+=1
				if str(item["action"]).begins_with("down"):down+=1
				if item["action"]!="room": check(corridor.navigation.walkable(item["at"]),"portal walkable "+id+str(row["floor"])+str(item["action"]))
			check(up==(1 if int(row["floor"])<int(building["floor_count"]) else 0),"top floor no upward portal")
			check(down==(2 if int(row["floor"])>1 else 0),"ground floor no downward portal")
			for room: Dictionary in row["rooms"]:
				rooms+=1
				check(room["windows"].size()==3,"three exterior windows per classroom")
				check(bool(room["class10"])==(int(row["floor"])==3 and int(room["index"])==0),"class10 on left at third floor")
				var door_x:=float(room["front_door_x"])*24
				check(not corridor.navigation.route(corridor.landing(),Vector2(door_x,97)).is_empty(),"front corridor door reachable "+id+str(row["floor"])+str(room["index"]))
				if room["rear_door_x"]!=null:
					check(not corridor.navigation.route(corridor.landing(),Vector2(float(room["rear_door_x"])*24,97)).is_empty(),"rear corridor door reachable")
				var classroom:=Scene.new()
				check(classroom.setup(game.interior_info,{"kind":"classroom","building":id,"floor":row["floor"],"room":room["index"]},game.interior_directory),"classroom loaded")
				maximum_bytes=maxi(maximum_bytes,classroom.texture_bytes)
				check(classroom.navigation.walkable(classroom.landing()),"classroom front landing clear")
				for portal: Dictionary in classroom.portals:
					check(not classroom.navigation.route(classroom.landing(),portal["at"]).is_empty(),"classroom exit reachable "+id+str(row["floor"])+str(room["index"])+str(portal["side"]))
				check(not classroom.navigation.walkable(classroom.blockers[0].get_center()),"desk collision in navigation")
				check(classroom.get_child_count()>=39,"actual furniture and wall physics")
				classroom.free()
			corridor.free()
	# Real movement and automatic stair/classroom triggers, not just data checks.
	game.player.set_physics_process(true)
	Engine.time_scale=4
	Engine.physics_ticks_per_second=240
	for id: String in game.interior_info["buildings"]:
		var entrance: Dictionary={}
		for entry: Dictionary in game.interior_info["entrances"]:
			if entry["id"]==id:entrance=entry;break
		game.teleport_outdoor(game.point(entrance["arrival"])*24)
		await wait_transition()
		await create_timer(.8).timeout
		check(game.click_interaction(game.point(entrance["door"])*24-Vector2(0,24)),"click exterior pictured door")
		var entry_steps:=0
		while game.interior_state.is_empty() or game.transition_busy:
			await physics_frame
			entry_steps+=1
			if entry_steps>5000:break
		check(not game.interior_state.is_empty() and int(game.interior_state.get("floor",0))==1,"actual exterior entry "+id)
		for level: int in [1,2]:
			var up: Dictionary={}
			for item: Dictionary in game.terrain.current_scene.portals:
				if item["action"]=="up":up=item
			game.request_path(up["at"])
			var limit:=0
			while int(game.interior_state["floor"])==level or game.transition_busy:
				await physics_frame
				limit+=1
				if limit>5000: break
			check(int(game.interior_state["floor"])==level+1,"actual ascending "+id+str(level))
		await create_timer(.8).timeout
		var door: Dictionary={}
		for item: Dictionary in game.terrain.current_scene.portals:
			if item["action"]=="room" and int(item["room"])==0:door=item;break
		game.request_path(door["at"])
		var steps:=0
		while game.interior_state["kind"]=="corridor" or game.transition_busy:
			await physics_frame
			steps+=1
			if steps>10000:break
		check(game.interior_state["kind"]=="classroom" and game.terrain.current_scene.title.contains("十班"),"actually enter class10 "+id)
		check(game.terrain.get_child_count()==1,"one active interior chunk")
		await create_timer(.8).timeout
		game.request_path(game.terrain.current_scene.portals[0]["at"])
		steps=0
		while game.interior_state["kind"]=="classroom" or game.transition_busy:
			await physics_frame
			steps+=1
			if steps>5000:break
		check(game.interior_state["kind"]=="corridor","actual classroom exit "+id)
		await create_timer(.8).timeout
		var normal_door: Dictionary={}
		for item: Dictionary in game.terrain.current_scene.portals:
			if item["action"]=="room" and int(item["room"])==1 and item["side"]=="front":normal_door=item;break
		check(game.click_interaction(normal_door["art_rect"].get_center()),"click pictured classroom door")
		steps=0
		while game.interior_state["kind"]=="corridor" or game.transition_busy:
			await physics_frame
			steps+=1
			if steps>5000:break
		check(game.interior_state.get("room",-1)==1,"selected room without entering other doors")
		await create_timer(.8).timeout
		var rear: Dictionary=game.terrain.current_scene.portals[1]
		check(game.click_interaction(rear["art_rect"].get_center()),"click pictured rear classroom door")
		steps=0
		while game.interior_state["kind"]=="classroom" or game.transition_busy:
			await physics_frame
			steps+=1
			if steps>10000:break
		check(game.interior_state["kind"]=="corridor","actual furniture navigation to rear exit "+id)
		var normal: Dictionary=game.interior_info["buildings"][id]["floors"][2]["rooms"][1]
		check(absf(game.player.position.x-float(normal["rear_door_x"])*24)<2,"return to matching corridor rear door")
		for level: int in [3,2]:
			await create_timer(.8).timeout
			var down: Dictionary={}
			for item: Dictionary in game.terrain.current_scene.portals:
				if item["action"]=="down_right":down=item;break
			game.request_path(down["at"])
			steps=0
			while int(game.interior_state["floor"])==level or game.transition_busy:
				await physics_frame
				steps+=1
				if steps>5000:break
			check(int(game.interior_state["floor"])==level-1,"actual descending "+id+str(level))
		await create_timer(.8).timeout
		for item: Dictionary in game.terrain.current_scene.portals:
			if item["action"]=="outside":game.request_path(item["at"]);break
		steps=0
		while not game.interior_state.is_empty() or game.transition_busy:
			await physics_frame
			steps+=1
			if steps>5000:break
		check(game.interior_state.is_empty(),"actual ground-floor campus exit "+id)
		for entry: Dictionary in game.interior_info["entrances"]:
			if entry["id"]!=id:continue
			game.teleport_outdoor(game.point(entry["arrival"])*24)
			await wait_transition()
			check(game.interior_state.is_empty() and game.terrain.get_child_count()==1,"interior unloaded outdoors")
			game.player.position=game.point(entry["board_arrival"])*24
			game.interaction_delay=0
			await process_frame
			await process_frame
			check(game.nearby.get("action","")=="board","wall board proximity "+id)
			game.interact()
			check(game.map_view.visible and game.map_view.teleport_mode,"board opens teleport map")
			check(game.map_view.map_texture!=null and game.map_view.map_texture.get_size()==Vector2(1108,1420),"original whole campus image")
			game.map_view.choose(0)
			await wait_transition()
			check(game.map_view.map_texture==null and game.terrain.get_child_count()==1,"map texture released after teleport")
	var result: Dictionary={"checks":checks,"failures":failures,"floors":floors,"rooms":rooms,"largest_interior_texture_bytes":maximum_bytes,"max_active_scenes":game.terrain.max_scene_count}
	var file:=FileAccess.open(game.interior_directory.path_join("内景检查.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	file.close()
	print("INTERIOR_CHECK ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
