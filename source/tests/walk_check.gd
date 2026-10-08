extends SceneTree

class MotionTick extends Node:
	signal completed
	var player: CharacterBody2D
	func _physics_process(delta: float) -> void:
		player._physics_process(delta)
		completed.emit()

var game: Node2D
var checks:=0
var failures: Array[String]=[]
var rates: Array[float]=[]
var probe: MotionTick
var direction_samples: Array[Dictionary]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func frames() -> void:
	await process_frame;await physics_frame;await process_frame
func transition() -> void:
	var until:=Time.get_ticks_msec()+20000
	while game.transition_busy and Time.get_ticks_msec()<until:await process_frame
	check(not game.transition_busy,"scene transition completes");await frames()
func key(code: Key, pressed: bool) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed
	Input.parse_input_event(event)
func tick() -> void:
	probe.set_physics_process(true)
	await probe.completed
	probe.set_physics_process(false)
func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	var folder: String=game.package_root.path_join("runtime/行走动画预览")
	DirAccess.make_dir_recursive_absolute(folder)
	root.get_texture().get_image().save_png(folder.path_join(name+".png"))
func verify_art(gait: RefCounted, label: String) -> void:
	check(gait.ready and gait.poses.size()==4,label+" has four walking directions")
	for direction: int in range(4):
		check(gait.poses[direction].size()==2,label+" has two distinct poses per direction")
		var first: Texture2D=gait.poses[direction][0]["texture"]
		var second: Texture2D=gait.poses[direction][1]["texture"]
		check(first.get_height()>200 and second.get_height()>200,label+" uses original HD poses")
		check(first.get_image().get_data()!=second.get_image().get_data(),label+" has different leg poses")
		check(first.get_image().has_mipmaps() and second.get_image().has_mipmaps(),label+" has mipmaps")

func run() -> void:
	game=(load("res://main.tscn") as PackedScene).instantiate();root.add_child(game);await frames()
	check(game.load_error.is_empty(),"all local animation assets load")
	if not game.load_error.is_empty():quit(1);return
	game.start_new_game();await transition()
	var turf: Vector2=game.Space.project(Vector2(245,500))
	game.teleport_outdoor(turf);await transition()
	game.player.set_physics_process(false)
	var player: CharacterBody2D=game.player
	probe=MotionTick.new();probe.player=player;root.add_child(probe);probe.set_physics_process(false)
	verify_art(player.gait,"hero")
	# A clear horizontal lane allows a fair comparison of real motion at all speeds.
	for mode: int in range(3):
		player.position=turf;player.path.clear();player.gait.stop()
		if mode<2:key(KEY_D,true)
		if mode==1:key(KEY_SHIFT,true)
		if mode==2:player.path=PackedVector2Array([turf+Vector2(300,0)])
		var begin: Vector2=player.position
		var prior: float=player.gait.frames_advanced
		var textures: Array=[]
		for i: int in range(24):
			await tick()
			if not player.artwork.texture in textures:textures.append(player.artwork.texture)
		var advance: float=player.gait.frames_advanced-prior
		rates.append(advance/.4)
		check(absf(rates[-1]-[4.0,8.0,8.0][mode])<.08,"actual animation rate is capped at 4/8/8 fps")
		check(absf(player.position.distance_to(begin)-[100.8,201.6,504.0][mode]*.4)<.3,"movement speed unchanged")
		check(textures.size()==2,"real motion displays both walking poses")
		check(player.artwork.rotation==0,"no rotation substitute for step animation")
		key(KEY_D,false);key(KEY_SHIFT,false);player.path.clear()
		await tick()
		check(not player.gait.moving and player.artwork.texture==player.frames[player.facing],"stop restores correct idle")
	check(absf(rates[1]/rates[0]-2.0)<.02 and absf(rates[2]/rates[0]-2.0)<.02,"playback follows speed up to an 8 fps ceiling")
	for direction: int in range(4):
		player.position=turf;player.path.clear();player.gait.stop()
		var code: Key=[KEY_S,KEY_W,KEY_A,KEY_D][direction]
		key(code,true)
		for i: int in range(40):
			await tick()
			if player.facing==direction and player.gait.displayed_frame==1:break
		var sample: Dictionary={"direction":direction,"player_facing":player.facing,"animation_facing":player.gait.facing,"phase":player.gait.phase,"frame":player.gait.displayed_frame,"moving":player.gait.moving,"rate":player.gait.rate}
		direction_samples.append(sample)
		check(player.facing==direction and player.artwork.texture==player.gait.poses[direction][1]["texture"],"four-way physical input selects correct B pose")
		check(is_equal_approx(player.artwork.texture.get_height()*player.artwork.scale.y,40.8),"hero height remains 1.70 metres")
		await shot("主角_"+str(direction)+"_迈步")
		key(code,false);await tick()
	player.position=turf;key(KEY_D,true);await tick();game.toggle_menu();await tick()
	check(not player.gait.moving and player.gait.rate==0,"menu pauses animation and restores idle")
	key(KEY_D,false);game.close_menu()
	game.change_interior({"building":"B12","floor":2,"kind":"classroom","room":1});await transition()
	# Holding into a wall must not keep walking on the spot.
	player.position=Vector2(12,190);key(KEY_A,true)
	for i: int in range(45):await tick()
	check(not player.gait.moving and player.gait.rate==0,"blocked movement stops playback")
	key(KEY_A,false)
	game.save_game_slot(1);var saved: int=player.facing
	game.load_game_slot(1);await transition()
	check(player.facing==saved and not player.gait.moving,"loading preserves facing and standing pose")
	# Only the non-teaching periods have roaming named classmates.
	game.day_clock.current_period=3;game.apply_time_lighting()
	for building: String in ["B12","B05","B01"]:
		game.change_interior({"building":building,"floor":3,"kind":"classroom","room":0});await transition()
		var manager: Node2D=game.terrain.current_scene.npcs
		manager.set_process(false)
		for other: Dictionary in manager.movers:other["path"]=PackedVector2Array();other["wait"]=100
		check(manager.records.size()==10 and manager.movers.size()==10,"ten class still contains named students only")
		for record: Dictionary in manager.movers:
			check(record.has("gait"),"named NPC has walking animation")
			if not record.has("gait"):continue
			verify_art(record["gait"],record["character"])
			var start:=Vector2(INF,INF)
			var goal:=Vector2(INF,INF)
			for y: int in range(96,220,10):
				for x: int in range(40,330,10):
					var a:=Vector2(x,y);var b:=a+Vector2(38,0)
					if record["range"].has_point(a) and record["range"].has_point(b) and game.terrain.current_scene.navigation.segment_clear(a,b):start=a;goal=b;break
				if is_finite(start.x):break
			check(record["range"].has_point(goal) and game.terrain.current_scene.navigation.segment_clear(start,goal),"NPC test route is clear and bounded")
			if not is_finite(start.x):continue
			record["at"]=start;record["sprite"].position=start;record["gait"].stop()
			record["path"]=PackedVector2Array([goal]);record["wait"]=0
			var prior: float=record["gait"].frames_advanced
			for i: int in range(22):manager._process(.1)
			check(absf(record["gait"].rate-4.0*.5/4.2)<.01,"slow NPC rate corresponds to 0.5 m/s")
			check(record["gait"].phase>1.0 and record["gait"].phase<1.1,"same-direction movement does not reset animation phase")
			check(record["gait"].frames_advanced>prior+1 and record["gait"].displayed_frame==1,"NPC reaches second actual step pose")
			check(is_equal_approx(record["sprite"].texture.get_height()*record["sprite"].scale.y,float(record["height"])),"NPC keeps body proportions")
			record["path"]=PackedVector2Array();record["wait"]=1;manager._process(.1)
			check(not record["gait"].moving,"waiting NPC returns to idle")
			for other: Dictionary in manager.movers:other["path"]=PackedVector2Array();other["wait"]=100
		manager.set_process(true);await shot(building+"_十班行走")
	var report: Dictionary={"checks":checks,"failures":failures,"actual_player_rates":rates,"direction_samples":direction_samples,"walking_directions":4,"poses_per_direction":2,"named_npc_instances":30,"npc_rate_fps":4.0*.5/4.2,"only_current_scene":true,"uses_hd_original_poses":true}
	var file:=FileAccess.open(game.package_root.path_join("行走动画验证.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("WALK_CHECK ",JSON.stringify(report));game.queue_free();await frames();quit(0 if failures.is_empty() else 1)
