extends Node2D

const Effect=preload("res://magic_effect.gd")
var game: Node2D
var data: Dictionary={}
var effects: Dictionary={}
var stage:=0
var running:=false
var reward_given:=false
var leave_permission:=false
var actors: Array[Sprite2D]=[]
var rear_point:=Vector2.ZERO
var window_point:=Vector2.ZERO
var rear_wall:=Rect2()
var black_text: Label
var objective: Label
var observed_door_x:=0.0
var scene_token:=""
var vibrating_door: Sprite2D
var mentor_gait: RefCounted
var mentor_sprite: Sprite2D
var mentor_previous:=Vector2.ZERO
var effect_audio: AudioStreamPlayer
var played_effects: Array[String]=[]
var black_durations: Array[float]=[]
var draw_stamp:=""
var redraw_elapsed:=0.0

func configure(path: String) -> bool:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:return false
	data=parsed
	var index: Variant=JSON.parse_string(FileAccess.get_file_as_string(game.resolve_path(data["effects_index"])))
	if not index is Dictionary:return false
	for spec: Dictionary in index["entries"]:effects[spec["id"]]=spec
	return true

func _ready() -> void:
	z_index=12
	black_text=game.label("",27);black_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black_text.offset_left=80;black_text.offset_right=-80;black_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	black_text.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;black_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	game.fade.add_child(black_text);black_text.hide()
	effect_audio=AudioStreamPlayer.new();effect_audio.volume_db=-15;add_child(effect_audio)
	var audio:=AudioStreamWAV.new();audio.format=AudioStreamWAV.FORMAT_16_BITS;audio.mix_rate=22050
	var samples:=PackedByteArray();samples.resize(13230*2)
	for i: int in range(13230):
		var t:=float(i)/22050
		var value: float=(sin(TAU*(80*t+90*t*t))*.5+sin(TAU*317*t)*.25+sin(TAU*919*t)*.15)*pow(1.0-float(i)/13230,2)
		samples.encode_s16(i*2,int(value*20000))
	audio.data=samples;effect_audio.stream=audio
	for entry: Dictionary in game.interior_info["entrances"]:
		if entry["id"]!="B02":continue
		var box: Array=entry["box"]
		window_point=Vector2(float(box[0])+14.4,float(box[1]))*24+Vector2(0,32)
		rear_wall=Rect2(Vector2(float(box[0]),float(box[1]))*24+Vector2(0,4),Vector2(float(box[2])*24,57))
		rear_point=game.safe_outdoor(window_point-Vector2(0,44))
	var room: Dictionary=game.interior_info["buildings"]["B02"]["floors"][0]["rooms"][int(data["lab_room"])]
	observed_door_x=float(room["front_door_x"])*24
	refresh_objective()

func snapshot() -> Dictionary:
	return {"version":1,"stage":stage,"reward_given":reward_given,"leave_permission":leave_permission,"campaign":game.campaign.snapshot() if game.campaign!=null else {}}

func valid_snapshot(value: Variant) -> bool:
	if not value is Dictionary or value.get("version")!=1:return false
	if value.has("campaign"):
		if not value["campaign"] is Dictionary:return false
		if not value["campaign"].is_empty() and not game.campaign.valid_snapshot(value["campaign"]):return false
	var number: Variant=value.get("stage")
	if not (number is float or number is int) or number!=floor(float(number)) or int(number)<0 or int(number)>6:return false
	return value.get("reward_given") is bool and value.get("leave_permission",false) is bool and bool(value["reward_given"])==(int(number)>=5)

func restore(value: Dictionary) -> void:
	clear_actors();stage=int(value.get("stage",0));reward_given=bool(value.get("reward_given",false))
	leave_permission=bool(value.get("leave_permission",false));running=false
	if game.campaign!=null:game.campaign.restore(value.get("campaign",{}))
	refresh_objective()

func chapter_room() -> bool:
	return not game.interior_state.is_empty() and game.interior_state["kind"]=="classroom" and game.interior_state["building"]=="B01" and int(game.interior_state["floor"])==3 and int(game.interior_state.get("room",-1))==0

func objective_text() -> String:
	if stage>=6 and game.campaign!=null:return game.campaign.objective_text()
	return ["秋实楼 3F 十班 → 自己的白圈座位","实验楼北侧后墙 → 闪光窗户","实验楼南侧正门 → 进入","实验楼 1F → 震动的 102 教室门","实验楼 1F → 震动的 102 教室门","返回秋实楼 3F 十班 → 晚自习","第一章完成 · 自由探索 / 学习技能"][stage]

func refresh_objective() -> void:
	if objective!=null:objective.text="任务："+objective_text()
	queue_redraw()

func set_stage(value: int, event: String="") -> void:
	stage=value
	if not event.is_empty():game.record_game_event(event)
	refresh_objective()

func seat_active() -> bool:return chapter_room() and stage in [0,5]

func extra_interactions() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if stage==1 and game.interior_state.is_empty():result.append({"action":"story_window","at":rear_point,"trigger":Rect2(),"art_rect":Rect2(rear_point-Vector2(10,10),Vector2(20,20))})
	if seat_active():
		var at: Vector2=game.terrain.current_scene.hero_seat
		result.append({"action":"story_seat","at":at,"trigger":Rect2(),"art_rect":Rect2(at-Vector2(8,8),Vector2(16,16))})
	return result

func door_active() -> bool:
	return stage in [3,4] and game.interior_state.get("building","")=="B02" and int(game.interior_state.get("floor",0))==1 and game.interior_state.get("kind","")=="corridor"

func blocks_lab_spawns() -> bool:return stage<5

func interaction_label(item: Dictionary) -> String:
	if item["action"]=="story_window":return "查看闪光的窗户"
	if item["action"]=="story_seat":return "开始今天的课程" if stage==0 else "回座位上晚自习"
	if door_active() and item["action"]=="room" and int(item["room"])==int(data["lab_room"]):return "查看震动的 102 教室门"
	return ""

func handle(item: Dictionary) -> bool:
	if running:return true
	if item["action"]=="story_seat":
		if stage==0:morning_sequence()
		elif stage==5:finish_chapter()
		return true
	if item["action"]=="story_window" and stage==1:window_sequence();return true
	if item["action"]=="entrance" and item.get("building")=="B02":
		if stage in [0,1]:game.show_notice("先按任务提示调查实验楼后面的窗户。");return true
		if stage==2:entrance_sequence();return true
	if door_active() and item["action"]=="room" and int(item["room"])==int(data["lab_room"]):initiation_sequence();return true
	if item["action"]=="npc":
		var record: Dictionary=game.terrain.current_scene.npcs.find(item["uid"])
		var id: String=record.get("character","")
		if data["role_greetings"].has(id):named_conversation(record);return true
	return false

func _process(delta: float) -> void:
	if not game.game_started or game.terrain.current_scene==null:return
	if mentor_gait!=null and is_instance_valid(mentor_sprite):
		var travel: Vector2=mentor_sprite.position-mentor_previous
		if not travel.is_zero_approx():mentor_gait.face(2 if travel.x<0 else 3)
		mentor_gait.advance(delta,travel.length()/maxf(.001,delta));mentor_previous=mentor_sprite.position
	if door_active():
		if not is_instance_valid(vibrating_door):
			var background: Sprite2D=game.terrain.current_scene.background
			var density: float=1.0/background.scale.x
			vibrating_door=Sprite2D.new();vibrating_door.texture=background.texture
			vibrating_door.region_enabled=true
			vibrating_door.region_rect=Rect2((observed_door_x-12)*density,21.88*density,24*density,50.4*density)
			vibrating_door.centered=false;vibrating_door.scale=Vector2.ONE/density
			vibrating_door.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;add_child(vibrating_door)
		vibrating_door.position=Vector2(observed_door_x-12+sin(Time.get_ticks_msec()*.038)*.8,21.88)
	else:
		if is_instance_valid(vibrating_door):vibrating_door.queue_free();vibrating_door=null
	redraw_elapsed+=delta
	var stamp:=str(stage)+"/"+str(running)+"/"+str(game.interior_state)+"/"+str(game.player.position.distance_to(rear_point)<=1100)
	var flashing: bool=stage in [1,2] and game.interior_state.is_empty() and game.player.position.distance_to(rear_point)<=1100
	if stamp!=draw_stamp or (flashing and redraw_elapsed>=.05):
		draw_stamp=stamp;redraw_elapsed=0;queue_redraw()

func _draw() -> void:
	if not game.game_started:return
	var phase:=float(Time.get_ticks_msec())/1000.0
	if stage>=1 and game.interior_state.is_empty():
		if game.player.position.distance_to(rear_point)>1100:return
		# Only this rear window is dynamic; the facade remains baked.
		draw_rect(rear_wall,Color("8b5148"))
		for y: float in [12.0,24.0,36.0,48.0]:draw_line(rear_wall.position+Vector2(0,y),Vector2(rear_wall.end.x,rear_wall.position.y+y),Color("71483f"),.7,true)
		draw_line(rear_wall.position,rear_wall.position+Vector2(rear_wall.size.x,0),Color("dddcd2"),2.0,true)
		draw_line(Vector2(rear_wall.position.x,rear_wall.end.y),rear_wall.end,Color("a99481"),2.0,true)
		draw_rect(Rect2(window_point-Vector2(25,28),Vector2(50,57)),Color("8b5148"))
		draw_rect(Rect2(window_point-Vector2(19,20),Vector2(38,38)),Color("dddcd2"))
		draw_rect(Rect2(window_point-Vector2(16,17),Vector2(32,32)),Color("52798a"))
		if stage in [1,2]:draw_rect(Rect2(window_point-Vector2(16,17),Vector2(32,32)),Color(.6,.83,1,.35+.3*sin(phase*12)))
		draw_line(window_point+Vector2(0,-19),window_point+Vector2(0,17),Color("dddcd2"),1.3,true)
		draw_line(window_point+Vector2(-17,-5),window_point+Vector2(17,-5),Color("dddcd2"),1.3,true)
		if stage==1 and not running:draw_arc(rear_point,6,0,TAU,40,Color.WHITE,1.3,true)
	if seat_active() and not running:draw_arc(game.terrain.current_scene.hero_seat,6,0,TAU,40,Color.WHITE,1.3,true)
	if door_active() and not running:
		draw_arc(Vector2(observed_door_x,97),6,0,TAU,40,Color.WHITE,1.3,true)

func speak(id: String) -> void:
	game.dialogue_view.begin_script(data["dialogues"][id])
	await game.dialogue_view.script_finished

func begin_sequence() -> void:
	running=true;game.player.path.clear();game.player.velocity=Vector2.ZERO
	game.refresh_player_freeze();game.update_time_display()

func end_sequence() -> void:
	running=false;game.interaction_delay=.4;game.gameplay_hud.show()
	game.refresh_player_freeze();game.update_time_display();refresh_objective()

func black_scene(text: String, target_period: int=-1) -> void:
	var cover:=game.create_tween();cover.tween_property(game.fade,"modulate:a",1,.18);await cover.finished
	black_text.text=text;black_text.show()
	var begin:=Time.get_ticks_msec();await get_tree().create_timer(2.0).timeout
	black_durations.append(float(Time.get_ticks_msec()-begin)/1000.0)
	if target_period>=0:
		game.day_clock.current_period=target_period
		game.sync_classroom_period();game.apply_time_lighting();game.update_time_display()
	black_text.hide()
	var reveal:=game.create_tween();reveal.tween_property(game.fade,"modulate:a",0,.22);await reveal.finished

func morning_sequence() -> void:
	begin_sequence()
	# A player's manual fast-forward cannot skip the mandatory morning event.
	if game.day_clock.current_period!=1:
		game.day_clock.current_period=1;game.sync_classroom_period();game.apply_time_lighting()
	await speak("morning")
	await black_scene("上午的课程、午后的练习……\n\n一天的课终于结束，晚自习还没开始。",3)
	await speak("evening")
	set_stage(1,"story/morning");end_sequence()

func window_sequence() -> void:
	begin_sequence()
	for i: int in range(3):
		await play_effect("world_explosion",window_point,65,.35)
	await speak("window");set_stage(2,"story/window");end_sequence()

func entrance_sequence() -> void:
	begin_sequence();await speak("entrance")
	set_stage(3,"story/entrance")
	await game.change_interior({"building":"B02","floor":1,"kind":"corridor"})
	end_sequence();game.show_notice("走廊空无一人。102 教室的门正在震动……")

func make_actor(id: String, at: Vector2, height: float) -> Sprite2D:
	var image: Image
	if game.npc_catalog.characters.has(id):image=game.npc_catalog.frame(id,0)
	else:
		image=preload("res://monster_scene.gd").portrait(game.battle_asset_root.path_join(game.combat_rules.data["monsters"][id]["art"])).get_image()
	image.generate_mipmaps()
	var sprite:=Sprite2D.new();sprite.texture=ImageTexture.create_from_image(image)
	sprite.scale=Vector2.ONE*height/image.get_height();sprite.offset.y=-image.get_height()*.5
	sprite.position=at;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(sprite);actors.append(sprite);return sprite

func clear_actors() -> void:
	mentor_gait=null;mentor_sprite=null
	for sprite: Sprite2D in actors:
		if is_instance_valid(sprite):sprite.queue_free()
	actors.clear()

func play_effect(id: String, at: Vector2, width: float, seconds: float=.6) -> void:
	var effect:=Effect.new()
	if not effect.setup(game,id,width,seconds):effect.free();return
	effect.position=at;add_child(effect)
	played_effects.append(id)
	if effect_audio!=null:effect_audio.play()
	await effect.completed

func initiation_sequence() -> void:
	begin_sequence()
	# Stage 4 is transient and cannot be saved halfway through the rewards.
	stage=4
	var context: Dictionary={"building":"B02","floor":1,"kind":"classroom","room":int(data["lab_room"])}
	await game.change_interior(context)
	# The old fixed point lies inside a desk since furniture collisions changed.
	game.place_player_safely(Vector2(84,153))
	var nav: RefCounted=game.motion_navigation()
	var mentor:=make_actor("fei_yan",nav.safe_landing(Vector2(142,143)),game.npc_catalog.height("fei_yan"))
	mentor_sprite=mentor;mentor_previous=mentor.position
	var idle: Array[Texture2D]=[]
	for direction: int in range(4):
		var art: Image=game.npc_catalog.frame("fei_yan",direction);art.generate_mipmaps();idle.append(ImageTexture.create_from_image(art))
	mentor_gait=preload("res://walk_animation.gd").new()
	if not mentor_gait.configure(game.npc_catalog.project_root,game.walk_library["fei_yan"],mentor,game.npc_catalog.height("fei_yan"),idle):mentor_gait=null
	var first:=make_actor("empty_uniform",nav.safe_landing(Vector2(213,115)),40.8)
	var second:=make_actor("empty_uniform",nav.safe_landing(Vector2(249,147)),40.8)
	await speak("encounter")
	await play_effect("world_barrier",mentor.position-Vector2(0,20),70,.6)
	await play_effect("light_medium",first.position-Vector2(0,20),82,.6)
	await play_effect("world_explosion",first.position-Vector2(0,15),68,.5)
	var fade_first:=create_tween();fade_first.tween_property(first,"modulate:a",0,.25);await fade_first.finished
	await play_effect("lightning_high",second.position-Vector2(0,20),102,.65)
	await play_effect("world_explosion",second.position-Vector2(0,15),70,.5)
	var fade_second:=create_tween();fade_second.tween_property(second,"modulate:a",0,.25);await fade_second.finished
	await speak("reveal")
	var route: PackedVector2Array=nav.route(mentor.position,nav.safe_landing(game.player.position+Vector2(28,0)))
	if not route.is_empty():
		var approach:=create_tween()
		var previous: Vector2=mentor.position
		for target: Vector2 in route:
			approach.tween_property(mentor,"position",target,maxf(.03,previous.distance_to(target)/55.0));previous=target
		await approach.finished
	await play_effect("world_magic_circle",game.player.position-Vector2(0,7),86,1.4)
	grant_rewards()
	await speak("gifts")
	clear_actors();set_stage(5,"story/initiation")
	# Begin normal refresh only after the scripted encounter; this room is cleared.
	game.monster_world.set_zone_rule(context,{"initial_count":0})
	var key: String=game.monster_world.zone_key(context)
	if game.monster_world.zones.has(key):game.monster_world.zones[key]["monsters"]=[]
	game.sync_monsters();game.place_player_safely(game.player.position);end_sequence()

func grant_rewards() -> void:
	if reward_given:return
	reward_given=true
	for id: String in ["special_uniform","basic_amulet","basic_magic_book"]:game.economy.add_item(id)
	game.combat_rules.equip("special_uniform");game.combat_rules.equip("basic_amulet")
	game.combat_rules.set_hero_level(int(game.combat_rules.hero["level"])+1,true)
	for id: String in ["fire_low","lightning_low","frost_low","light_low"]:game.combat_rules.learn(id)
	game.record_game_event("magic_awakened")

func finish_chapter() -> void:
	begin_sequence()
	await black_scene("晚上 · 晚自习\n\n赵慕gei回到靠窗的座位，翻开基础魔法书。\n四种法术的知识逐渐清晰。\n\n第一章 · 完",4)
	set_stage(6,"story/complete");end_sequence();game.show_notice(data["end_hint"])

func named_conversation(record: Dictionary) -> void:
	var id: String=record["character"]
	var greetings: Array=data["role_greetings"][id]
	var text: String=greetings[game.dialogue_view.rng.randi_range(0,greetings.size()-1)]
	if id=="fei_yan" and not reward_given:text="你又整什么活呢，gei子？"
	var lines: Array=[{"actor":id,"text":text}]
	if id in ["lao_li","fei_yan","lao_shuo"]:
		lines.append({"actor":id,"text":("想学法术就打开技能页看看。" if id=="fei_yan" else "需要装备或委托制作？我给你列个清单。") if reward_given else "现在先按任务去自己的座位上课吧。有事下课再说。"})
	if id=="la_jiao" and stage in [1,2,3] and not leave_permission:
		lines.append({"actor":"zhao_mugei","text":"我去实验楼附近看看，一会儿就回来，不耽误晚自习。"})
		lines.append({"actor":id,"text":"说好了，回来坐自己的座位，我会记出勤。"})
	var callback:=Callable()
	if reward_given and id in ["lao_li","fei_yan","lao_shuo"]:callback=func():game.menu_view.open_service(id)
	if id=="la_jiao" and stage in [1,2,3] and not leave_permission:callback=func():leave_permission=true;game.record_game_event("story/leave_permission")
	game.dialogue_view.begin_script(lines,false,callback)
