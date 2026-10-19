extends SceneTree
var game: Node2D
var checks:=0
var failures: Array[String]=[]
var report_path:=""
var captured:=false
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(n: int=3) -> void:
	for i: int in range(n):await process_frame
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(report_path.get_base_dir().path_join("v19-"+name+".png"))
func verify_gait(gait: RefCounted, sprite: Sprite2D, label: String) -> void:
	for d: int in range(4):
		gait.face(d);gait.stop()
		var sequence: Array=[]
		for beat: int in range(4):
			gait.advance(.001 if beat==0 else .25,100.8)
			sequence.append(sprite.texture)
		check(sequence[0]!=sequence[1] and sequence[0]!=sequence[2] and sequence[1]==sequence[3],label+" four beats bridge both steps with planted feet "+str(d))
		var saved: Texture2D=sprite.texture;var phase: float=gait.phase
		gait.advance(0,100);gait.face(d)
		check(sprite.texture==saved and gait.phase==phase,label+" zero delta and repeated facing preserve phase")
		gait.advance(20.125,10000)
		check(gait.rate<=8 and is_finite(gait.phase),label+" bounded fast-forward after frame stall")
		gait.stop();check(not gait.moving and gait.rate==0,label+" stopping restores idle")
	# Actual named students move at 12 px/s. A planted bridge must not hold
	# for two seconds at that speed, even though physical movement stays slow.
	gait.stop();var slow: Array=[]
	for beat: int in range(4):
		gait.advance(.001 if beat==0 else 1.0/gait.rate,12);slow.append(sprite.texture)
	check(is_equal_approx(gait.rate,3 if label=="staff" else 2),label+" slow walk uses bounded natural cadence")
	check(slow[0]!=slow[1] and slow[0]!=slow[2] and slow[1]==slow[3],label+" actual 12px/s cadence reaches both feet without long planted pause")
	gait.stop()
func clip(motion: RefCounted, action: String, side: float) -> void:
	var slot: Control=motion.view;var body: Control=slot.portrait_view
	var anchor:=slot.position;var label_at: Vector2=slot.name_label.position
	var start:=body.position;var minimum:=0.0;var maximum:=0.0
	motion.play(action,.5 if action=="combo" else .4)
	var anchored:=true;var until:=Time.get_ticks_msec()+5000
	while motion.acting and Time.get_ticks_msec()<until:
		await process_frame
		minimum=minf(minimum,(body.position.x-start.x)*side);maximum=maxf(maximum,(body.position.x-start.x)*side)
		if not captured and action=="physical" and side==1 and maximum>12:
			captured=true
			check(slot.displayed_pose==motion.texture("physical"),"physical strike uses dedicated punch without spell overlay")
			await shot("attack-forward")
		anchored=anchored and slot.position.is_equal_approx(anchor) and slot.name_label.position.is_equal_approx(label_at)
	check(not motion.acting,action+" finishes")
	check(anchored,action+" keeps layout/name/shadow anchored")
	check(body.position.is_equal_approx(start) and body.scale.is_equal_approx(Vector2.ONE),action+" returns to current layout without jump")
	if action in ["attack","physical","combo"]:check(maximum>12 and minimum<-.5,action+" anticipation then forward lunge")
	if action=="evade":check(minimum< -12,action+" retreats away from opponent")
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report-path="):report_path=arg.trim_prefix("--report-path=")
	game=load("res://main.tscn").instantiate();root.add_child(game);await frames()
	game.game_started=true;game.front_end.hide_title();game.story_system.stage=6;game.story_system.reward_given=true;game.campaign.index=31;game.day_clock.current_period=4
	game.player.set_physics_process(false)
	verify_gait(game.player.gait,game.player.artwork,"hero")
	for id: String in ["lao_li","english_teacher"]:
		var standing: Array[Texture2D]=[]
		for d: int in range(4):standing.append(ImageTexture.create_from_image(game.npc_catalog.frame(id,d)))
		var other:=preload("res://walk_animation.gd").new();var actor:=Sprite2D.new();root.add_child(actor)
		check(other.configure(game.npc_catalog.project_root,game.walk_library[id],actor,game.npc_catalog.height(id),standing),"named NPC gait loads "+id)
		verify_gait(other,actor,id);actor.queue_free()
	var pixel:=preload("res://walk_animation.gd").new();var sprite:=Sprite2D.new();root.add_child(sprite)
	check(pixel.configure(game.npc_catalog.project_root,game.npc_catalog.characters["fei_yan"],sprite,40.8,[]),"Leon atlas loads")
	verify_gait(pixel,sprite,"Leon")
	var life:=preload("res://life_walk.gd").new()
	check(life.configure(game.npc_catalog.project_root,game.npc_catalog.characters["cook_hu"],sprite,40.8,[]),"staff atlas loads")
	verify_gait(life,sprite,"staff")
	for gait: RefCounted in [pixel,life]:
		var ids: Array=[];var sheet: Texture2D=gait.pixel_sheet if gait==pixel else gait.texture
		var cells: Array=gait.pixel_frames if gait==pixel else gait.frames
		for row: Array in cells:
			for cell: AtlasTexture in row:ids.append(cell.get_instance_id());check(cell.atlas==sheet,"one shared sheet for cached regions")
		var seen: Dictionary={}
		for i: int in range(1200):
			gait.face(i%4);gait.advance(.125,10000);seen[sprite.texture.get_instance_id()]=true
		check(seen.keys().all(func(id: int):return id in ids) and ids.size()==12,"1200 updates allocate no extra pose textures")
		check(gait.rate<=4,"pixel and staff remain capped at four pose keys per second")
	sprite.queue_free()
	# Real farming room: initial pose, alert hysteresis, shared small textures and pause.
	var zone: Dictionary=game.farming.ZONES[0];game.campaign.done.append(zone["after"])
	await game.change_interior({"building":zone["building"],"floor":zone["floor"],"kind":"classroom","room":zone["room"]});await frames()
	var manager: Node2D=game.terrain.current_scene.monsters
	check(manager!=null and not manager.records.is_empty(),"actual farming monsters spawn")
	if manager!=null and not manager.records.is_empty():
		manager.set_process(false);manager.refresh();manager.set_process(false)
		var row: Dictionary=manager.records[0];var monster_sprite: Sprite2D=row["sprite"]
		var small: Array=manager.idle_frames[row["monster"]["id"]]
		check(monster_sprite.texture==small[0] and monster_sprite.texture.get_size()==Vector2(96,120),"spawn begins in same geometry as animated poses")
		var at: Vector2=monster_sprite.position
		game.player.frozen=false
		for distance: int in [39,44,49]:
			game.player.position=at+Vector2(distance,0);manager._process(.34)
			check(row["alert"]==(distance<49),"alert hysteresis "+str(distance))
			check(monster_sprite.position==at and (monster_sprite.offset.y+monster_sprite.texture.get_height()*.5)==0,"breathing leaves monster feet fixed")
		var old_texture: Texture2D=monster_sprite.texture;var clock: float=manager.breath_clock
		game.player.frozen=true;manager._process(2)
		check(clock==manager.breath_clock and old_texture==monster_sprite.texture,"modal pause freezes monster animation")
	# Real responsive battle UI, not a fake Control. Layout changes after configure.
	game.combat_rules.set_hero_level(35,true)
	for skill: String in game.combat_rules.data["skills"]:game.combat_rules.learn(skill)
	game.combat_rules.refill_hero()
	var view: Control=game.battle_view
	check(view.start({"monster":{"uid":"animation-check","id":"ink_slime","level":35,"hp":10000000}},"animation-check"),"actual battle opens")
	await frames();view.set_process(false)
	for width: int in [1280,960]:
		view.interface.size=Vector2(width,800);view.interface.sync_layout();await frames()
		for motion: RefCounted in [view.hero_motion,view.enemy_motion]:
			for action: String in ["attack","combo","hit","guard","rest"]:await clip(motion,action,motion.toward)
		await clip(view.hero_motion,"physical",1)
		await clip(view.hero_motion,"evade",1)
		await shot("battle-"+str(width))
	var before: Vector2=view.interface.ally_slot.portrait_view.position
	view.hero_motion.tick(.1);var foot: Vector2=view.interface.ally_slot.portrait_view.pivot_offset
	check(foot.y==view.interface.ally_slot.portrait_view.size.y and before==view.interface.ally_slot.portrait_view.position,"idle breath pivots at portrait feet")
	# A resized viewport at low frame rate must complete both coroutine turns.
	Engine.max_fps=8;view.set_process(true)
	var turn: int=view.turn;var hp: int=view.enemy["hp_current"]
	await view.perform("physical")
	check(not view.busy and view.turn==turn+1 and int(view.enemy["hp_current"])<hp,"8fps actual physical turn completes and damages enemy")
	await view.perform("wind_step")
	check(not view.busy and view.turn==turn+2,"8fps actual evasive turn completes")
	Engine.max_fps=60
	view.finish("escape");view.close();await frames()
	check(not view.visible and view.hero_motion==null and view.enemy_motion==null,"battle close releases motion/atlas references")
	var file:=FileAccess.open(report_path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"method":"Actual hero/Leon/staff four-beat gait, 2400 cached region updates, real farming spawn/hysteresis/fixed feet/pause, real battle responsive 1280/960 layout anchored actions, forward attacks/backward evade, actual physical and evasion turns at 8fps. Desktop rendering; no Android device or emulator."},"  "))
	print("ANIMATION_FLOW_CHECKS ",checks," FAILURES ",failures.size());game.queue_free();game=null;await frames();quit(0 if failures.is_empty() else 1)
