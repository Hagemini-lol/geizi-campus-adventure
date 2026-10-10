extends Node2D

const Player = preload("res://player.gd")
const Space = preload("res://map_space.gd")
const Stream = preload("res://district_stream.gd")
const RoadNavigation = preload("res://road_navigation.gd")
const InteriorScene = preload("res://interior_scene.gd")
const GameMenu = preload("res://game_menu.gd")
const DayClock = preload("res://day_clock.gd")
const SaveStore = preload("res://save_store.gd")
const Preferences = preload("res://preferences.gd")
const FrontEnd = preload("res://front_end.gd")
const NpcCatalog=preload("res://npc_catalog.gd")
const NpcDialogue=preload("res://npc_dialogue.gd")
const CombatRules=preload("res://combat_rules.gd")
const MonsterWorld=preload("res://monster_world.gd")
const MonsterScene=preload("res://monster_scene.gd")
const BattleView=preload("res://battle_view.gd")
const LessonSystem=preload("res://lesson_system.gd")
const StorySystem=preload("res://story_system.gd")
var campaign: Node2D
var story_system: Node2D
var mobile_controls: Control
const INTERACTION_RADIUS:=12.0
var lesson_view: Control
const OfficePlan=preload("res://office_plan.gd")
const TaskSystem=preload("res://task_system.gd")
var task_system:=TaskSystem.new()
var mods:=preload("res://mod_loader.gd").new()
var side_quests:=preload("res://side_quests.gd").new()
const Economy=preload("res://economy.gd")
var economy:=Economy.new()
var office_plan:=OfficePlan.new()
var walk_library: Dictionary={}
var combat_rules:=CombatRules.new()
var monster_world:=MonsterWorld.new()
var battle_view: Control
var battle_asset_root: String
var pending_monster:=""
var npc_catalog:=NpcCatalog.new()
var dialogue_view: Control
var dialogue_path: String
var pending_npc_talk:=""
var save_store:=SaveStore.new()
var preferences:=Preferences.new()
var front_end: Control
var cover_path: String
var game_started:=false
var event_state: Dictionary={}
var play_clock:=preload("res://play_clock.gd").new()
var pending_restore: Dictionary={}
var restore_position_guard:=false
var sounds=preload("res://sound_bank.gd").new()
const TIME_SKIP_COOLDOWN_SECONDS:=2.0
var campus_life=preload("res://campus_life.gd").new()
var day_clock:=DayClock.new()
var time_label: Label
var time_skip_button: Button
var time_skip_ready_at_ms:=0
var time_skip_busy:=false
var menu_view: Control
var gameplay_hud: CanvasLayer
var menu_assets: Dictionary={}
var interior_info: Dictionary={}
var interior_directory := ""
var interior_state: Dictionary={}
var music:=preload("res://music_director.gd").new()
var relationships:=preload("res://relationships.gd").new()
var world_editor:=preload("res://world_editor.gd").new()
var phone: Control
var farming:=preload("res://farming_regions.gd").new()
var story_regions:=preload("res://story_regions.gd").new()
var interaction_delay := 0.0
var nearby: Dictionary={}
var interaction_label: Label
var outdoor_zoom := 1.5
var package_root := ""
var data: Dictionary = {}
var model: Dictionary = {}
var navigation := RoadNavigation.new()
var player: CharacterBody2D
var terrain: Node2D
var bounds: Rect2
var spawn: Vector2
var overlay: PanelContainer
var fade: ColorRect
var location_label: Label
var map_view: Control
var ui_font: FontFile
var debug_geometry := false
var collision_overlay: Node2D
var paused := false
var transition_busy := false
var load_error := ""
var notice := ""
var notice_time := 0.0

func _ready() -> void:
	y_sort_enabled=true
	package_root=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	if OS.has_feature("android") or ProjectSettings.get_setting("application/config/mobile_bundle",false):package_root="res://package"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--game-root="): package_root=arg.trim_prefix("--game-root=")
	ui_font=FontFile.new()
	if ui_font.load_dynamic_font(package_root.path_join("资源/字体/NotoSansSC-Regular.ttf"))!=OK:
		fail("内置中文字体缺失，请重新安装完整包");return
	ui_font.allow_system_fallback=false
	var config_value: Variant=JSON.parse_string(FileAccess.get_file_as_string(package_root.path_join("素材引用.json")))
	if not config_value is Dictionary:
		fail("素材引用配置缺失或格式错误")
		return
	var config: Dictionary=config_value
	mods.configure(package_root)
	menu_assets=config.get("menu_assets",{})
	battle_asset_root=resolve_path(str(config.get("battle_asset_root","../Projects/赵慕gei的牙林冒险")))
	if not combat_rules.configure(resolve_path(str(config.get("combat_rules","战斗与刷新配置.json"))),mods.merged.get("combat",{})):
		fail("战斗数值配置缺失或格式错误");return
	relationships.game=self;world_editor.game=self;combat_rules.world_editor=world_editor;farming.game=self;monster_world.configure(combat_rules,self)
	if not task_system.configure(resolve_path(str(config.get("task_rules","任务配置.json"))),mods.merged.get("tasks",{})):
		fail("任务配置缺失或格式错误");return
	if not economy.configure(resolve_path(str(config.get("economy_rules","物资与交易配置.json"))),mods.merged.get("economy",{})):
		fail("物资与交易配置缺失或格式错误");return
	day_clock.period_advanced.connect(on_period_advanced)
	cover_path=str(config.get("cover",""))
	var save_directory:=package_root.path_join("存档")
	var settings_path:=package_root.path_join("设置.json")
	if OS.has_feature("android") or ProjectSettings.get_setting("application/config/mobile_bundle",false):
		save_directory="user://存档";settings_path="user://设置.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--save-dir="):save_directory=arg.trim_prefix("--save-dir=")
		if arg.begins_with("--settings-path="):settings_path=arg.trim_prefix("--settings-path=")
	save_store.configure(save_directory)
	preferences.configure(settings_path)
	create_ui_audio()
	var geometry: Variant=JSON.parse_string(FileAccess.get_file_as_string(resolve_path(str(config["geometry"]))))
	var model_path:=resolve_path(str(config.get("district_model","")))
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(model_path))
	if not parsed is Dictionary or not geometry is Dictionary:
		fail("地图区块数据缺失，请保留地图重绘预览文件夹")
		return
	model=parsed
	data=geometry
	interior_directory=resolve_path(str(config.get("interior_model",""))).get_base_dir()
	var interiors: Variant=JSON.parse_string(FileAccess.get_file_as_string(interior_directory.path_join("内外对应.json")))
	if not interiors is Dictionary:
		fail("室内地图数据缺失，请保留外部内景素材")
		return
	interior_info=interiors
	for key: String in interior_info["assets"]:interior_info["assets"][key]=resolve_path(str(interior_info["assets"][key]))
	if not office_plan.configure(resolve_path(str(config.get("office_rules","办公室配置.json")))):
		fail("办公室配置缺失或格式错误");return
	office_plan.apply(interior_info,package_root)
	dialogue_path=str(config.get("dialogue",""))
	if not npc_catalog.configure(resolve_path(str(config.get("npc_library","")))):
		fail("NPC 素材索引缺失或不完整")
		return
	var walks: Variant=JSON.parse_string(FileAccess.get_file_as_string(resolve_path(str(config.get("walk_library","")))))
	if not walks is Dictionary:
		fail("角色行走素材索引缺失");return
	for entry: Dictionary in walks.get("characters",[]):walk_library[entry["id"]]=entry
	walk_library["fei_yan"]={"id":"fei_yan","source":"res://assets/characters/leon_v15/atlas.png","pixel_grid":true}
	if not walk_library.has("zhao_mugei"):
		fail("主角行走素材缺失");return
	var hero:=Image.load_from_file(resolve_path(str(config["hero"])))
	if hero==null or hero.get_size()!=Vector2i(1265,1243):
		fail("主角素材缺失或尺寸错误")
		return
	navigation.configure(model)
	terrain=Node2D.new()
	terrain.set_script(Stream)
	add_child(terrain)
	terrain.configure(model,model_path.get_base_dir())
	player=CharacterBody2D.new()
	player.set_script(Player)
	player.game=self
	add_child(player)
	player.set_art(hero)
	if not player.set_walk_art(npc_catalog.project_root,walk_library["zhao_mugei"]):
		fail("主角行走差分加载失败");return
	collision_overlay=Node2D.new()
	collision_overlay.set_script(preload("res://collision_debug.gd"))
	collision_overlay.game=self
	add_child(collision_overlay)
	collision_overlay.hide()
	bounds=rect(data["campus_bounds"])
	spawn=Space.project(point(data["hub_spawn"]))
	player.position=spawn
	create_ui()
	var curtain:=CanvasLayer.new()
	curtain.layer=100
	add_child(curtain)
	fade=ColorRect.new()
	fade.color=Color.BLACK
	fade.modulate.a=0.0
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	curtain.add_child(fade)
	var front_layer:=CanvasLayer.new()
	front_layer.layer=80
	add_child(front_layer)
	front_end=Control.new()
	front_end.set_script(FrontEnd)
	front_end.game=self
	front_end.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	front_layer.add_child(front_end)
	var dialogue_layer:=CanvasLayer.new()
	dialogue_layer.layer=90
	add_child(dialogue_layer)
	dialogue_view=NpcDialogue.new()
	dialogue_view.game=self
	dialogue_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialogue_layer.add_child(dialogue_view)
	var battle_layer:=CanvasLayer.new();battle_layer.layer=95;add_child(battle_layer)
	battle_view=BattleView.new();battle_view.game=self
	battle_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);battle_layer.add_child(battle_view)
	var lesson_layer:=CanvasLayer.new();lesson_layer.layer=96;add_child(lesson_layer)
	lesson_view=LessonSystem.new();lesson_view.game=self;lesson_layer.add_child(lesson_view)
	story_system=StorySystem.new();story_system.game=self
	if not story_system.configure(package_root.path_join("剧情配置.json"),mods.merged.get("story",{})):
		fail("剧情素材或配置缺失");return
	add_child(story_system)
	campaign=preload("res://campaign.gd").new();campaign.game=self
	campaign.configure(story_system.data.get("campaign",{}));add_child(campaign)
	relationships.configure()
	campus_life.configure(self)
	farming.install()
	side_quests.game=self
	task_system.changed.connect(campaign.queue_redraw)
	var mobile_layer:=CanvasLayer.new();mobile_layer.layer=99;add_child(mobile_layer)
	mobile_controls=preload("res://mobile_controls.gd").new();mobile_controls.game=self
	mobile_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mobile_layer.add_child(mobile_controls)
	var phone_layer:=CanvasLayer.new();phone_layer.layer=96;add_child(phone_layer)
	phone=preload("res://phone.gd").new();phone.game=self;phone.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);phone_layer.add_child(phone)
	if "--skip-title" in OS.get_cmdline_user_args():
		game_started=true
		if not load_district(navigation.region_at(spawn)):fail("高清地图文件缺失，请保留地图重绘预览文件夹");return
	else:
		player.hide();gameplay_hud.hide()
		front_end.show_title()
	DisplayServer.window_set_title("gei子的冒险")
	print("CAMPUS_READY: 20 districts, viewport HD tiles, 17 corridors, 150 rooms, one active scene")

func resolve_path(value: String) -> String:
	return value if value.is_absolute_path() else package_root.path_join(value).simplify_path()

func record_game_event(id: String, amount: int=1) -> void:
	if amount<=0:return
	event_state[id]=int(event_state.get(id,0))+amount
	task_system.record_event(id,amount)

func on_period_advanced(previous: int, current: int) -> void:
	if previous==4 and current==0:
		var amount:=economy.next_day()
		record_game_event("days_passed")
		if amount>0:record_game_event("allowance_received",amount);show_notice("收到生活费 %dg" % amount)

func trade_supply(id: String, count: int, buying: bool) -> Dictionary:
	if not game_started or transition_busy or front_end.visible or dialogue_view.visible or battle_view.visible or lesson_blocked():return {"ok":false,"message":"当前不能交易"}
	if buying and not str(economy.catalog.get(id,{}).get("merchant","")).is_empty():return {"ok":false,"message":"请向对应同学购买或委托制作"}
	if buying and not str(economy.catalog.get(id,{}).get("vendor","")).is_empty():return {"ok":false,"message":"请到对应校园服务人员处购买"}
	var result: Dictionary=economy.trade(id,count,buying)
	if result["ok"]:
		record_game_event("items_bought/"+id if buying else "items_sold/"+id,count)
		record_game_event("trade_completed")
	if result["ok"]:sounds.play("trade")
	show_notice(result["message"]);return result

func use_supply(id: String) -> Dictionary:
	if not game_started or transition_busy or front_end.visible or dialogue_view.visible or battle_view.visible or lesson_blocked():return {"ok":false,"message":"当前不能使用物资"}
	var previous_san: int=int(combat_rules.hero["san_current"])
	var result: Dictionary=economy.use(id,combat_rules.hero)
	if result["ok"]:
		record_game_event("item_used/"+id)
		if campaign!=null and campaign.active() and int(combat_rules.hero["san_current"])>previous_san:campaign.flags["SAN"]=clampi(ceili(float(combat_rules.hero["san_current"])*100/maxi(1,int(combat_rules.hero["san"]))),0,100)
	show_notice(result["message"]);return result

func purchase_equipment(id: String, merchant: String) -> Dictionary:
	var spec: Dictionary=economy.catalog.get(id,{})
	if not game_started or not menu_view.visible or menu_view.service_actor!=merchant or not story_system.reward_given or spec.get("merchant","")!=merchant:return {"ok":false,"message":"请与对应同学交谈"}
	if economy.quantity(id)>0:return {"ok":false,"message":"已经拥有该装备"}
	if id=="tech_amulet" and economy.quantity("ink_fragment")<2:return {"ok":false,"message":"需要 2 份墨渣才能委托制作"}
	var extra: int=equipment_price(id)-int(spec.get("buy_price",0))
	if economy.money<equipment_price(id):return {"ok":false,"message":"资金不足"}
	var result: Dictionary=economy.trade(id,1,true)
	if result["ok"]:
		economy.money-=extra
		if id=="tech_amulet":economy.inventory["ink_fragment"]=economy.quantity("ink_fragment")-2;economy.changed.emit()
		combat_rules.equip(id);record_game_event("equipment_received/"+id)
	return result

func equipment_price(id: String) -> int:
	var spec: Dictionary=economy.catalog.get(id,{})
	var base: int=int(spec.get("buy_price",0))
	return floori(base*1.2) if spec.get("merchant","")=="lao_li" and campaign!=null and campaign.active() and campaign.index>=15 and not campaign.flags["F_LI_CLEAR"] and not campaign.flags["F_LI_PARTIAL"] else base

func learn_skill(id: String, teacher: String) -> Dictionary:
	var spec: Dictionary=combat_rules.data.get("skills",{}).get(id,{})
	if not game_started or not menu_view.visible or menu_view.service_actor!=teacher or not story_system.reward_given or spec.get("teacher","")!=teacher:return {"ok":false,"message":"请向对应同学学习技能"}
	if id in combat_rules.hero["skills"]:return {"ok":false,"message":"已经习得该技能"}
	if spec.get("chapter_reward",false):return {"ok":false,"message":"这个技能由章节事件习得"}
	if int(combat_rules.hero["level"])<int(spec["level"]):return {"ok":false,"message":"等级不足"}
	if economy.money<int(spec["price"]):return {"ok":false,"message":"资金不足"}
	if not relationships.alive(teacher) and not menu_view.service_archive:return {"ok":false,"message":"老师已不在，请从遗留档案整理教案后自行学习"}
	if not combat_rules.learn(id):return {"ok":false,"message":"无法学习该技能"}
	economy.money-=int(spec["price"]);economy.changed.emit();record_game_event("skill_learned/"+id)
	return {"ok":true,"message":"习得 "+str(spec["name"])}

func create_ui_audio() -> void:
	sounds.configure(package_root)
	add_child(sounds)
	music.game=self;add_child(music);music.configure(package_root)

func play_ui_click() -> void:
	sounds.play("ui_confirm")

func refresh_player_freeze() -> void:
	if player==null:return
	player.frozen=transition_busy or paused or (phone!=null and phone.visible) or (map_view!=null and map_view.visible) or (menu_view!=null and menu_view.visible) or (front_end!=null and front_end.visible) or (dialogue_view!=null and dialogue_view.visible) or (battle_view!=null and battle_view.visible) or lesson_blocked() or story_blocked() or not game_started

func start_new_game() -> void:
	if transition_busy:return
	var region: Dictionary=model["regions"][navigation.region_at(spawn)]
	queue_restore({"scene":{"kind":"outdoor","region":region["id"]},"position":[spawn.x,spawn.y],"period":"上午","camera_zoom":1.5,"outdoor_zoom":1.5,"facing":0,"events":{}},"第一章 · 去秋实楼十班")

func save_game_slot(slot: int) -> Dictionary:
	if not game_started or transition_busy or battle_view.visible or lesson_blocked() or story_blocked() or dialogue_view.visible:return {"ok":false,"error":"场景切换或战斗结束后才能保存"}
	var scene: Dictionary=interior_state.duplicate(true)
	var location: String
	if scene.is_empty():
		var region: Dictionary=model["regions"][terrain.current_id]
		scene={"kind":"outdoor","region":region["id"]}
		location=region["name"]
	else:location=terrain.current_scene.title
	var state: Dictionary={"scene":scene,"position":[player.position.x,player.position.y],"period":day_clock.display_text(),"camera_zoom":player.camera.zoom.x,"outdoor_zoom":outdoor_zoom,"facing":player.facing,"events":event_state.duplicate(true)}
	state["combat"]={"hero":combat_rules.hero.duplicate(true),"world":monster_world.snapshot()}
	state["quests"]=task_system.snapshot()
	state["economy"]=economy.snapshot()
	state["story"]=story_system.snapshot()
	state["playtime"]=play_clock.snapshot()
	state["relationships"]=relationships.snapshot()
	state["world_edits"]=world_editor.snapshot();state["phone"]=phone.snapshot()
	return save_store.write_slot(slot,state,location)

func validate_snapshot(state: Dictionary) -> Dictionary:
	if state.has("world_edits") and not world_editor.valid(state["world_edits"]):return {"ok":false,"error":"禁忌力量数值记录无效"}
	if state.has("phone") and not phone.valid(state["phone"]):return {"ok":false,"error":"手机记录无效"}
	world_editor.validation=state.get("world_edits",{"hero":{},"monsters":{}})
	var result:=validate_snapshot_contents(state)
	world_editor.validation={}
	return result

func validate_snapshot_contents(state: Dictionary) -> Dictionary:
	if state.has("relationships") and not relationships.valid(state["relationships"]):return {"ok":false,"error":"人际关系或生存记录无效"}
	if state.has("playtime") and not play_clock.valid(state["playtime"]):return {"ok":false,"error":"游玩时长数据无效"}
	var error: Dictionary={"ok":false,"error":"存档中的场景或位置数据无效"}
	if not state.get("scene") is Dictionary or not state.get("position") is Array:return error
	var xy: Array=state["position"]
	if xy.size()!=2:return error
	for value: Variant in xy:
		if not (value is float or value is int) or not is_finite(float(value)):return error
	var at:=Vector2(float(xy[0]),float(xy[1]))
	var scene: Dictionary=state["scene"].duplicate(true)
	var kind: String=str(scene.get("kind",""))
	if kind=="outdoor":
		var index: int=-1
		for i: int in range(model["regions"].size()):
			if model["regions"][i]["id"]==scene.get("region"):index=i;break
		if index<0 or navigation.region_at(at)!=index:return error
		var entry: Dictionary=terrain.static_regions.get(str(scene["region"]),{})
		if entry.is_empty() or not FileAccess.file_exists(terrain.asset_root.path_join(str(entry.get("image","")))):return {"ok":false,"error":"存档对应的室外地图贴图缺失"}
	elif kind in ["corridor","classroom"]:
		if not interior_info["buildings"].has(scene.get("building")):return error
		var building: Dictionary=interior_info["buildings"][scene["building"]]
		if not (scene.get("floor") is float or scene.get("floor") is int):return error
		var level: int=int(scene["floor"])
		if level!=float(scene["floor"]) or level<1 or level>building["floors"].size():return error
		scene["floor"]=level
		var floor_data: Dictionary=building["floors"][level-1]
		if kind=="corridor":
			if not Rect2(3,70,float(building["width_pixels"])-6,110).has_point(at):return error
			if not FileAccess.file_exists(interior_directory.path_join(floor_data["image"])):return {"ok":false,"error":"存档对应的走廊贴图缺失"}
		else:
			if not (scene.get("room") is float or scene.get("room") is int):return error
			var room_index: int=int(scene["room"])
			if room_index!=float(scene["room"]) or room_index<0 or room_index>=floor_data["rooms"].size():return error
			scene["room"]=room_index
			var ten: bool=floor_data["rooms"][room_index]["class10"]
			var life: String=floor_data["rooms"][room_index].get("life_layout","")
			var polygon: PackedVector2Array=campus_life.polygon(life) if not life.is_empty() else InteriorScene.classroom_floor(ten)
			if not Geometry2D.is_point_in_polygon(at,polygon):return error
			if not FileAccess.file_exists(campus_life.source(life) if not life.is_empty() else interior_info["assets"]["class10" if ten else "ordinary"]):return {"ok":false,"error":"存档对应的教室贴图缺失"}
	else:return error
	var period: String=str(state.get("period",""))
	var period_valid:=false
	for item: Dictionary in DayClock.PERIODS:
		if item["name"]==period:period_valid=true
	if not period_valid:return {"ok":false,"error":"存档中的时间段无效"}
	for key: String in ["camera_zoom","outdoor_zoom","facing"]:
		if not (state.get(key) is float or state.get(key) is int) or not is_finite(float(state[key])):return error
	if float(state["facing"])!=int(state["facing"]) or int(state["facing"])<0 or int(state["facing"])>3:return error
	if not state.get("events",{}) is Dictionary:return error
	if state.has("quests") and not task_system.valid_snapshot(state["quests"]):return {"ok":false,"error":"存档中的任务进度数据无效"}
	if state.has("economy") and not economy.valid_snapshot(state["economy"]):return {"ok":false,"error":"存档中的资金或物资数据无效"}
	if state.has("story") and not story_system.valid_snapshot(state["story"]):return {"ok":false,"error":"存档中的剧情进度无效"}
	if state.has("combat"):
		if not combat_rules.valid_snapshot(state["combat"]) or not monster_world.valid_snapshot(state["combat"].get("world")):return {"ok":false,"error":"存档中的战斗或刷新区数据无效"}
	var clean: Dictionary=state.duplicate(true)
	clean["scene"]=scene
	clean["camera_zoom"]=clampf(float(state["camera_zoom"]),.6,2.4)
	clean["outdoor_zoom"]=clampf(float(state["outdoor_zoom"]),.6,2.4)
	return {"ok":true,"state":clean}

func load_game_slot(slot: int) -> Dictionary:
	if transition_busy or battle_view.visible or story_blocked():return {"ok":false,"error":"请等待场景切换或剧情结束"}
	var record: Dictionary=save_store.read_slot(slot)
	if not record["ok"]:return record
	return queue_restore(record["state"],"已读取存档 %d%s" % [slot,"（备份）" if record["backup"] else ""])

func queue_restore(state: Dictionary, message: String) -> Dictionary:
	if battle_view.visible:return {"ok":false,"error":"战斗结束后才能读档"}
	var checked:=validate_snapshot(state)
	if not checked["ok"]:return checked
	pending_restore=checked["state"]
	pending_restore["notice"]=message
	pending_npc_talk=""
	pending_monster=""
	if dialogue_view.visible:dialogue_view.close(false)
	player.path.clear()
	player.velocity=Vector2.ZERO
	paused=false;overlay.hide()
	if map_view.visible:map_view.close_map()
	var scene: Dictionary=pending_restore["scene"]
	var at:=point(pending_restore["position"])
	if scene["kind"]=="outdoor":begin_transition(navigation.region_at(at),at)
	else:change_interior(scene,at)
	return {"ok":true}

func apply_pending_restore() -> void:
	if pending_restore.is_empty():return
	for i: int in range(DayClock.PERIODS.size()):
		if DayClock.PERIODS[i]["name"]==pending_restore["period"]:day_clock.current_period=i
	player.show_direction(int(pending_restore["facing"]))
	player.camera.zoom=Vector2.ONE*minf(float(pending_restore["camera_zoom"]),maximum_clear_zoom())
	outdoor_zoom=float(pending_restore["outdoor_zoom"])
	event_state=pending_restore.get("events",{}).duplicate(true)
	play_clock.restore(pending_restore.get("playtime",{}))
	task_system.restore(pending_restore.get("quests",{}))
	economy.restore(pending_restore.get("economy",{}))
	world_editor.restore(pending_restore.get("world_edits",{}))
	combat_rules.restore(pending_restore.get("combat",{}))
	monster_world.restore(pending_restore.get("combat",{}).get("world",{}))
	story_system.restore(pending_restore.get("story",{}))
	if world_editor.used and pending_restore.get("combat",{}).get("hero",{}).has("san_current"):
		combat_rules.hero["san_current"]=int(pending_restore["combat"]["hero"]["san_current"])
	relationships.restore(pending_restore.get("relationships",{}))
	phone.restore(pending_restore.get("phone",{}))
	time_skip_ready_at_ms=0
	game_started=true
	front_end.hide_title();menu_view.hide();gameplay_hud.show();player.show()
	show_notice(pending_restore["notice"])
	pending_restore={}
	restore_position_guard=true
	sync_classroom_period()
	apply_time_lighting();update_time_display();player.camera.reset_smoothing()

func restore_position_if_blocked() -> void:
	if not restore_position_guard:return
	restore_position_guard=false
	if not interior_state.is_empty() and not motion_navigation().walkable(player.position):place_player_safely(player.position)
	var query:=PhysicsShapeQueryParameters2D.new()
	var shape:=CircleShape2D.new()
	shape.radius=Player.RADIUS
	query.shape=shape
	query.collision_mask=1
	query.exclude=[player.get_rid()]
	query.transform=Transform2D(0,player.position)
	if get_world_2d().direct_space_state.intersect_shape(query,1).is_empty():return
	# Recover a save on a changed wall/furniture boundary without moving valid saves.
	var original:=player.position
	for radius: int in range(1,21):
		for step: int in range(16):
			var candidate:=original+Vector2.from_angle(step*TAU/16)*radius*3
			if interior_state.is_empty() and navigation.region_at(candidate)!=terrain.current_id:continue
			if not motion_navigation().walkable(candidate):continue
			query.transform.origin=candidate
			if get_world_2d().direct_space_state.intersect_shape(query,1).is_empty():
				player.position=candidate;player.camera.reset_smoothing();show_notice("已读取存档，位置移至邻近空地")
				return
	# The validated map polygon provides a safe route-grid fallback.
	var grid: AStarGrid2D=motion_navigation().astar
	var closest:=Vector2(INF,INF)
	var best:=INF
	for y: int in range(grid.region.size.y):
		for x: int in range(grid.region.size.x):
			var cell:=Vector2i(x,y)
			if grid.is_point_solid(cell):continue
			var candidate:=grid.get_point_position(cell)
			if interior_state.is_empty() and navigation.region_at(candidate)!=terrain.current_id:continue
			var distance:=original.distance_squared_to(candidate)
			if distance>=best:continue
			query.transform.origin=candidate
			if not get_world_2d().direct_space_state.intersect_shape(query,1).is_empty():continue
			closest=candidate;best=distance
	if is_finite(closest.x):player.position=closest;player.camera.reset_smoothing()

func place_player_safely(preferred: Vector2) -> void:
	var at: Vector2=safe_outdoor(preferred) if interior_state.is_empty() else motion_navigation().safe_landing(preferred)
	if not is_finite(at.x):return
	player.position=at;player.velocity=Vector2.ZERO;player.path.clear()
	player.camera.reset_smoothing()

func return_to_title() -> void:
	if transition_busy or battle_view.visible or story_blocked():return
	pending_npc_talk=""
	pending_monster=""
	if dialogue_view.visible:dialogue_view.close(false)
	transition_busy=true;player.frozen=true;player.path.clear();player.velocity=Vector2.ZERO
	var cover:=create_tween()
	cover.tween_property(fade,"modulate:a",1.0,.18)
	await cover.finished
	if map_view.visible:map_view.close_map()
	menu_view.hide();overlay.hide();paused=false
	terrain.unload();interior_state={};nearby={}
	game_started=false;player.hide();gameplay_hud.hide();collision_overlay.hide()
	front_end.show_title()
	var reveal:=create_tween()
	reveal.tween_property(fade,"modulate:a",0.0,.22)
	await reveal.finished
	transition_busy=false;refresh_player_freeze()

func toggle_fullscreen() -> void:
	var next:=preferences.values.duplicate()
	next["fullscreen"]=not bool(next["fullscreen"])
	preferences.apply(next)

func rect(a: Array) -> Rect2:
	return Rect2(a[0],a[1],a[2],a[3])

func point(a: Array) -> Vector2:
	return Vector2(a[0],a[1])

func label(text_value: String, font_size: int) -> Label:
	var item := Label.new()
	item.text = text_value
	item.add_theme_font_override("font", ui_font)
	item.add_theme_font_size_override("font_size", font_size)
	return item

func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.09, 0.10, 0.93)
	style.border_color = Color(0.23, 0.46, 0.43, 0.65)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func create_ui() -> void:
	var hud := CanvasLayer.new()
	gameplay_hud=hud
	hud.layer = 30
	add_child(hud)
	var top := PanelContainer.new()
	top.position = Vector2(18, 16)
	top.add_theme_stylebox_override("panel", panel_style())
	hud.add_child(top)
	var column := VBoxContainer.new()
	top.add_child(column)
	column.add_child(label("gei子的冒险", 23))
	location_label = label("南门广场", 15)
	location_label.modulate = Color("9ce0ce")
	column.add_child(location_label)
	var time_row:=HBoxContainer.new()
	time_row.add_theme_constant_override("separation",10)
	column.add_child(time_row)
	var objective:=label("",15);objective.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;objective.custom_minimum_size=Vector2(335,0)
	column.add_child(objective);objective.hide()
	# Story node is created after the HUD; bind once all systems exist.
	call_deferred("bind_story_objective",objective)
	time_label=label(day_clock.display_text(),15)
	time_label.modulate=Color("f4e4bb")
	time_label.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	time_row.add_child(time_label)
	time_skip_button=Button.new()
	time_skip_button.text="快进 >>"
	time_skip_button.custom_minimum_size=Vector2(100,28)
	time_skip_button.add_theme_font_override("font",ui_font)
	time_skip_button.add_theme_font_size_override("font_size",14)
	time_skip_button.tooltip_text="快进到下一个时间段 · 冷却 2 秒"
	time_skip_button.focus_mode=Control.FOCUS_NONE
	time_skip_button.pressed.connect(fast_forward_time)
	time_row.add_child(time_skip_button)
	var help_panel := PanelContainer.new()
	help_panel.position = Vector2(18, 727)
	help_panel.add_theme_stylebox_override("panel", panel_style())
	hud.add_child(help_panel)
	if OS.has_feature("android") or "--mobile-controls" in OS.get_cmdline_user_args():
		help_panel.position=Vector2(250,745)
		help_panel.add_child(label("摇杆移动 · 点击 5倍寻路 · X 交互 · Y 菜单",16))
	else:help_panel.add_child(label("WASD 移动  Shift 2倍速  点击 5倍寻路  E 交互  M 全图  右键 菜单  R 南门  Esc 暂停", 16))
	interaction_label=label("",18)
	interaction_label.add_theme_color_override("font_outline_color",Color("152824"))
	interaction_label.add_theme_constant_override("outline_size",4)
	interaction_label.position=Vector2(440,675)
	hud.add_child(interaction_label)
	var map_button := Button.new()
	map_button.position = Vector2(1110, 18)
	map_button.anchor_left=1;map_button.anchor_right=1;map_button.offset_left=-250;map_button.offset_right=-100
	map_button.size = Vector2(150, 46)
	map_button.text = "M · 校园全图"
	map_button.add_theme_font_override("font", ui_font)
	map_button.pressed.connect(toggle_map)
	hud.add_child(map_button)
	map_view = Control.new()
	map_view.set_script(load("res://overview.gd"))
	map_view.game = self
	map_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_view.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(map_view)
	map_view.hide()
	overlay = PanelContainer.new()
	overlay.position = Vector2(470, 260)
	overlay.size = Vector2(340, 265)
	overlay.add_theme_stylebox_override("panel", panel_style())
	hud.add_child(overlay)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 12)
	overlay.add_child(menu)
	menu.add_child(label("已暂停", 26))
	for entry: String in ["继续漫游", "回到南门", "退出游戏"]:
		var button := Button.new()
		button.text = entry
		button.custom_minimum_size.y = 45
		button.add_theme_font_override("font", ui_font)
		if entry == "继续漫游":
			button.pressed.connect(toggle_pause)
		elif entry == "回到南门":
			button.pressed.connect(func(): paused=false; overlay.hide(); reset_player())
		else:
			button.pressed.connect(func(): get_tree().quit())
		menu.add_child(button)
	overlay.hide()
	var menu_layer:=CanvasLayer.new()
	menu_layer.layer=40
	add_child(menu_layer)
	menu_view=Control.new()
	menu_view.set_script(GameMenu)
	menu_view.game=self
	menu_view.assets=menu_assets
	menu_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(menu_view)

func fail(message: String) -> void:
	load_error=message
	push_error(message)
	var hud:=CanvasLayer.new()
	add_child(hud)
	var item:=label("无法打开gei子的冒险\n\n"+message,22)
	item.position=Vector2(40,120)
	hud.add_child(item)

func load_district(index: int) -> bool:
	if index<0 or not terrain.load_region(index): return false
	if not interior_state.is_empty():player.camera.zoom=Vector2.ONE*outdoor_zoom
	interior_state={}
	var region: Dictionary=model["regions"][index]
	var values: Array=region.get("visual_bounds",region["world_bounds"])
	player.camera.limit_left=int(values[0]*24)
	player.camera.limit_top=int(values[1]*24)
	player.camera.limit_right=int((values[0]+values[2])*24)
	player.camera.limit_bottom=int((values[1]+values[3])*24)
	player.camera.reset_smoothing()
	apply_time_lighting()
	return true

func apply_time_lighting() -> void:
	if terrain==null or player==null:return
	var color:=day_clock.tint(not interior_state.is_empty())
	terrain.modulate=color
	player.modulate=color

func time_skip_cooldown() -> float:
	return maxf(0.0,float(time_skip_ready_at_ms-Time.get_ticks_msec())/1000.0)

func update_time_display() -> void:
	time_label.text=day_clock.display_text()
	var remaining:=time_skip_cooldown()
	time_skip_button.disabled=remaining>0 or transition_busy or paused or map_view.visible or menu_view.visible or front_end.visible or dialogue_view.visible or (battle_view!=null and battle_view.visible) or lesson_blocked() or story_blocked() or not game_started
	time_skip_button.text="冷却中" if remaining>0 else "快进 >>"

func fast_forward_time() -> void:
	if not game_started or (phone!=null and phone.visible) or front_end.visible or dialogue_view.visible or (battle_view!=null and battle_view.visible) or transition_busy or paused or map_view.visible or menu_view.visible or lesson_blocked() or story_blocked() or time_skip_cooldown()>0:return
	time_skip_ready_at_ms=Time.get_ticks_msec()+int(TIME_SKIP_COOLDOWN_SECONDS*1000)
	advance_time_period()

func advance_time_from_event() -> bool:
	# Gameplay events call this explicitly. Ordinary movement and scene/menu
	# changes do not advance time, and events do not consume the button's CD.
	if not game_started or transition_busy or battle_view.visible or lesson_blocked() or story_blocked():return false
	advance_time_period()
	return true

func advance_world_period() -> void:
	day_clock.next_period()
	monster_world.advance(interior_state)
	sync_monsters()
	sync_classroom_period()
	apply_time_lighting()
	update_time_display()

func advance_world_to(target: int) -> void:
	if target not in DayClock.ORDER:return
	# Story transitions move forward, including the midnight allowance boundary.
	for step: int in range(DayClock.ORDER.size()):
		if day_clock.current_period==target:return
		advance_world_period()

func advance_time_period() -> void:
	time_skip_busy=true
	transition_busy=true
	player.frozen=true
	player.velocity=Vector2.ZERO
	update_time_display()
	var cover:=create_tween()
	cover.tween_property(fade,"modulate:a",1.0,.18)
	await cover.finished
	advance_world_period()
	await get_tree().create_timer(.06).timeout
	var reveal:=create_tween()
	reveal.tween_property(fade,"modulate:a",0.0,.22)
	await reveal.finished
	time_skip_busy=false
	transition_busy=false
	refresh_player_freeze()
	interaction_delay=maxf(interaction_delay,.25)
	update_time_display()

func reset_player() -> void:
	if not game_started or (phone!=null and phone.visible) or front_end.visible or dialogue_view.visible or (battle_view!=null and battle_view.visible) or transition_busy:return
	player.path.clear()
	begin_transition(navigation.region_at(spawn),spawn)

func toggle_map() -> void:
	if not game_started or (phone!=null and phone.visible) or front_end.visible or dialogue_view.visible or (battle_view!=null and battle_view.visible) or lesson_blocked() or paused or transition_busy:return
	if menu_view.visible:close_menu()
	if map_view.visible: map_view.close_map()
	else: map_view.open_map(not interior_state.is_empty())
	refresh_player_freeze()
	map_view.queue_redraw()

func toggle_pause() -> void:
	if not game_started or (phone!=null and phone.visible) or front_end.visible or dialogue_view.visible or (battle_view!=null and battle_view.visible) or lesson_blocked() or story_blocked() or transition_busy:return
	if menu_view.visible:
		close_menu()
		return
	if map_view.visible:
		toggle_map()
		return
	paused=not paused
	overlay.visible=paused
	refresh_player_freeze()

func toggle_menu() -> void:
	if not game_started or (phone!=null and phone.visible) or front_end.visible or dialogue_view.visible or (battle_view!=null and battle_view.visible) or lesson_blocked() or story_blocked() or transition_busy:return
	if menu_view.visible:
		close_menu()
		return
	if map_view.visible:map_view.close_map()
	paused=false
	overlay.hide()
	player.path.clear()
	pending_npc_talk=""
	pending_monster=""
	player.velocity=Vector2.ZERO
	player.frozen=true
	gameplay_hud.hide()
	menu_view.service_actor=""
	menu_view.open_menu()

func close_menu() -> void:
	menu_view.hide()
	menu_view.service_actor=""
	gameplay_hud.show()
	refresh_player_freeze()
	interaction_delay=maxf(interaction_delay,.25)

func menu_action(action: String) -> void:
	match action:
		"resume":close_menu()
		"map":close_menu();toggle_map()
		"south":close_menu();reset_player()
		"fullscreen":toggle_fullscreen()
		"preferences":front_end.open_settings()
		"journal":campaign.open_journal()
		"save":front_end.open_slots("save")
		"load":front_end.open_slots("load")
		"title":return_to_title()
		"exit":get_tree().quit()

func show_notice(value: String) -> void:
	notice=value
	notice_time=2.5

func request_path(destination: Vector2) -> bool:
	if not game_started or (phone!=null and phone.visible) or front_end.visible or dialogue_view.visible or (battle_view!=null and battle_view.visible) or transition_busy or paused or menu_view.visible or story_blocked():return false
	pending_npc_talk=""
	pending_monster=""
	var path: PackedVector2Array=motion_navigation().route(player.position,destination)
	if path.is_empty():
		show_notice("目的地无法到达，请点击道路或空地")
		return false
	player.path=path
	return true

func allow_motion(from: Vector2, proposed: Vector2) -> bool:
	if transition_busy:return false
	if not interior_state.is_empty(): return terrain.current_scene.navigation.segment_clear(from,proposed)
	var destination:=navigation.region_at(proposed)
	if destination==terrain.current_id:return true
	if destination<0:return false
	var from_cell:=Vector2i((from/24).floor())
	var on_road: bool=navigation.astar.is_in_boundsv(from_cell) and model["roads"][from_cell.y*320+from_cell.x]=="1"
	if on_road and navigation.can_cross(terrain.current_id,destination,proposed) and navigation.segment_clear(from,proposed):begin_transition(destination,proposed)
	return false

func begin_transition(destination: int, landing: Vector2) -> void:
	if transition_busy or (battle_view!=null and battle_view.visible):return
	pending_npc_talk=""
	pending_monster=""
	transition_busy=true
	player.frozen=true
	player.velocity=Vector2.ZERO
	var cover:=create_tween()
	cover.tween_property(fade,"modulate:a",1.0,0.18)
	await cover.finished
	terrain.unload()
	await get_tree().process_frame
	if not load_district(destination):
		fail("区块加载失败，请检查高清地图文件")
		return
	player.position=landing
	apply_pending_restore()
	sync_monsters()
	interaction_delay=.7
	player.camera.reset_smoothing()
	await get_tree().physics_frame
	restore_position_if_blocked()
	if terrain.current_scene.get("hd_layer")!=null:await terrain.current_scene.hd_layer.wait_for_view()
	var reveal:=create_tween()
	reveal.tween_property(fade,"modulate:a",0.0,0.22)
	await reveal.finished
	transition_busy=false
	refresh_player_freeze()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed or event is InputEventMouseButton and event.pressed or event is InputEventScreenTouch and event.pressed:play_clock.activity()
	if player==null or menu_view==null or transition_busy:return
	if phone!=null and phone.visible:
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:phone.back_page();get_viewport().set_input_as_handled()
		return
	if story_blocked() and not dialogue_view.visible:
		# A story choice is modal GUI: let its buttons receive mouse/touch input.
		# World movement and interactions remain blocked by _unhandled_input.
		if campaign!=null and is_instance_valid(campaign.panel):return
		get_viewport().set_input_as_handled();return
	if lesson_blocked():
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode==KEY_ESCAPE:lesson_view.close()
			elif event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_E]:lesson_view.start_lesson()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
			lesson_view.close();get_viewport().set_input_as_handled()
		return
	if battle_view!=null and battle_view.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode in [KEY_ENTER,KEY_KP_ENTER] and not battle_view.result.is_empty():battle_view.close()
			elif event.keycode==KEY_ESCAPE and not battle_view.busy:
				if not battle_view.result.is_empty():battle_view.close()
				elif battle_view.escape_confirmation.visible:battle_view.escape_confirmation.hide()
				else:battle_view.perform("escape")
			elif event.keycode in [KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6]:battle_view.perform(["physical","magic","dodge","guard","rest","auto"][event.keycode-KEY_1])
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
			if not battle_view.busy and battle_view.result.is_empty():battle_view.perform("escape")
			get_viewport().set_input_as_handled()
		return
	if dialogue_view!=null and dialogue_view.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_E]:dialogue_view.accept();get_viewport().set_input_as_handled()
			elif event.keycode==KEY_ESCAPE:dialogue_view.close();get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
			dialogue_view.close();get_viewport().set_input_as_handled()
		return
	if front_end!=null and front_end.visible:
		if front_end.has_modal() and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
			front_end.close_modal();get_viewport().set_input_as_handled()
		elif front_end.has_modal() and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
			front_end.close_modal();get_viewport().set_input_as_handled()
		return
	if not game_started:return
	# Handle before Control input so right-click works over menu buttons too.
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
		toggle_menu()
		get_viewport().set_input_as_handled()
	elif menu_view.visible and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		close_menu()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_Y:
		toggle_menu();get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if phone!=null and phone.visible:return
	if player==null or not game_started or front_end.visible or dialogue_view.visible or (battle_view!=null and battle_view.visible) or transition_busy or menu_view.visible or lesson_blocked() or story_blocked():return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_M:toggle_map()
			KEY_E,KEY_X:
				if not paused and not map_view.visible: interact()
			KEY_ESCAPE:toggle_pause()
			KEY_R:
				if not paused and not map_view.visible:reset_player()
			KEY_F3:debug_geometry=not debug_geometry
			KEY_F11:toggle_fullscreen()
	if event is InputEventMouseButton and event.pressed and not paused and not map_view.visible:
		if event.button_index==MOUSE_BUTTON_LEFT:
			# Touch-generated clicks do not move the OS mouse cursor. Resolve
			# this event's viewport position rather than its stale mouse cache.
			var destination: Vector2=get_global_transform_with_canvas().affine_inverse()*event.position
			if click_interaction(destination): return
			request_path(destination)
			return
		var amount:=0.1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else (-0.1 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else 0.0)
		player.camera.zoom=Vector2.ONE*clampf(player.camera.zoom.x+amount,0.6,maximum_clear_zoom())

func _process(delta: float) -> void:
	if player==null or location_label==null or not game_started or terrain.current_scene==null:return
	if not transition_busy and (not paused or menu_view.visible):
		var category: String="combat" if battle_view.visible else "dialogue" if dialogue_view.visible or story_system.running else "menu" if menu_view.visible or map_view.visible or (phone!=null and phone.visible) else "exploration"
		play_clock.tick(delta,category,get_window().has_focus(),player.velocity.length_squared()>1)
	update_time_display()
	player.camera.zoom=Vector2.ONE*minf(player.camera.zoom.x,maximum_clear_zoom())
	collision_overlay.visible=debug_geometry
	if debug_geometry: collision_overlay.queue_redraw()
	notice_time=maxf(0.0,notice_time-delta)
	interaction_delay=maxf(0,interaction_delay-delta)
	if not pending_npc_talk.is_empty() and not transition_busy and not player.frozen:
		if not player.input_direction().is_zero_approx():pending_npc_talk=""
		elif player.path.is_empty():
			var record: Dictionary=terrain.current_scene.npcs.find(pending_npc_talk) if not interior_state.is_empty() and terrain.current_scene.npcs!=null else {}
			pending_npc_talk=""
			pending_monster=""
			if not record.is_empty() and within_interaction(record["at"]):execute_interaction({"action":"npc","at":record["at"],"uid":record["uid"],"name":record["name"]})
	if not pending_monster.is_empty() and not transition_busy and not player.frozen:
		if not player.input_direction().is_zero_approx():pending_monster=""
		elif player.path.is_empty():
			var manager: Node2D=active_monsters()
			var record: Dictionary=manager.find(pending_monster) if manager!=null else {}
			pending_monster=""
			if not record.is_empty() and within_interaction(record["at"]):battle_view.start(record,manager.key)
	if terrain.current_id>=0:
		var place: String=model["regions"][terrain.current_id]["name"]
		location_label.text=notice if notice_time>0 else place+" · "+("5倍自动寻路" if not player.path.is_empty() else "赵慕gei")
	elif not interior_state.is_empty(): location_label.text=notice if notice_time>0 else terrain.current_scene.title
	story_regions.game=self
	if story_regions.tick():interaction_label.text="";return
	nearby={}
	if not transition_busy and not paused and not map_view.visible and not menu_view.visible and not front_end.visible and not dialogue_view.visible and not battle_view.visible and not lesson_blocked() and not story_blocked():
		var best:=INF
		for item: Dictionary in interactions():
			if not OS.get_cmdline_user_args().has("--manual-story-checks") and story_system.door_active() and item["action"]=="room" and int(item.get("room",-1))==int(story_system.data["lab_room"]):continue
			var distance: float=player.position.distance_to(item["at"])
			if distance<=INTERACTION_RADIUS and distance<best:
				best=distance
				nearby=item
			if distance<=INTERACTION_RADIUS and item["action"] in ["story_seat","story_window"]:
				best=-1;nearby=item
			var selected: bool=player.path.is_empty() or item["trigger"].has_point(player.path[-1])
			if selected and interaction_delay<=0 and not item["action"] in ["board","npc","monster","lesson","story_window","story_seat"] and within_interaction(item["at"]) and item["trigger"].has_point(player.position):
				if not (story_system.door_active() and item["action"]=="room" and int(item["room"])==int(story_system.data["lab_room"])):execute_interaction(item)
				break
	var interaction_key: String="X" if mobile_controls!=null and mobile_controls.active else "E"
	interaction_label.text=interaction_key+" · "+interaction_text(nearby) if not nearby.is_empty() and not map_view.visible and not menu_view.visible and not front_end.visible and not dialogue_view.visible and not battle_view.visible and not lesson_blocked() else ""

func lesson_blocked() -> bool:
	return lesson_view!=null and (lesson_view.visible or lesson_view.running)

func within_interaction(at: Vector2) -> bool:
	return player.position.distance_to(at)<=INTERACTION_RADIUS

func approach_interaction(at: Vector2) -> PackedVector2Array:
	var best:=PackedVector2Array()
	var length:=INF
	var nav: RefCounted=motion_navigation()
	for radius: float in [9.0,11.0]:
		for direction: int in range(16):
			var target:=at+Vector2.from_angle(direction*TAU/16)*radius
			if not nav.walkable(target):continue
			var route: PackedVector2Array=nav.route(player.position,target)
			if route.is_empty():continue
			var distance:=0.0
			var previous:=player.position
			for point: Vector2 in route:distance+=previous.distance_to(point);previous=point
			if distance<length:length=distance;best=route
	return best

func sync_classroom_period() -> void:
	if terrain==null or terrain.current_scene==null or interior_state.is_empty():return
	var scene: Node2D=terrain.current_scene
	if scene.has_method("refresh_cast"):scene.refresh_cast(self)
	if scene.npcs!=null and scene.state["building"]!="B02":
		scene.refresh_npcs(self)
		terrain.active_texture_bytes=scene.texture_bytes

func motion_navigation() -> RefCounted:
	return navigation if interior_state.is_empty() else terrain.current_scene.navigation

func maximum_clear_zoom() -> float:
	var display_scale:=get_viewport().get_stretch_transform().get_scale().abs()
	var raster_density:=4.0
	if not interior_state.is_empty():
		if interior_state["kind"]=="corridor":raster_density=float(interior_info.get("corridor_image_density",1))
		else:raster_density=1.0/terrain.current_scene.background.scale.x
	return minf(2.4,raster_density/maxf(display_scale.x,display_scale.y))

func interactions() -> Array[Dictionary]:
	if not interior_state.is_empty():
		var result: Array[Dictionary]=terrain.current_scene.portals.duplicate()
		if terrain.current_scene.npcs!=null:result.append_array(terrain.current_scene.npcs.interactions())
		if active_monsters()!=null:result.append_array(active_monsters().interactions())
		if lesson_view.available() and not story_system.seat_active():
			var seat: Vector2=terrain.current_scene.hero_seat
			result.append({"action":"lesson","at":seat,"trigger":Rect2(),"art_rect":Rect2(seat-Vector2(8,8),Vector2(16,16))})
		if OS.get_cmdline_user_args().has("--manual-story-checks"):
			result.append_array(story_system.extra_interactions())
			if campaign!=null:result.append_array(campaign.extra_interactions())
		return result
	var items: Array[Dictionary]=[]
	for entry: Dictionary in interior_info["entrances"]:
		var door:=point(entry["door"])*24
		var board:=point(entry["board"])*24
		items.append({"action":"board","building":entry["id"],"at":point(entry["board_arrival"])*24,"art_at":board,"art_rect":Rect2(board-Vector2(.9,.6)*24,Vector2(1.8,1.2)*24),"trigger":Rect2()})
		if entry["has_interior"]:
			items.append({"action":"entrance","building":entry["id"],"at":door+Vector2(0,25),"art_rect":Rect2(door+Vector2(-.95,-2.1)*24,Vector2(1.9,2.1)*24),"trigger":Rect2(door+Vector2(-20,8),Vector2(40,22))})
	if OS.get_cmdline_user_args().has("--manual-story-checks"):
		items.append_array(story_system.extra_interactions())
		if campaign!=null:items.append_array(campaign.extra_interactions())
	return items

func click_interaction(at: Vector2) -> bool:
	# The hero's empty seat marker takes priority over nearby seated artwork.
	if lesson_view.available():
		var seat: Vector2=terrain.current_scene.hero_seat
		if seat.distance_to(at)<=8:
			if within_interaction(seat):lesson_view.open()
			else:
				player.path=approach_interaction(seat)
				show_notice("走到自己的座位后，按 E 上课")
			return true
	var monsters: Node2D=active_monsters()
	if monsters!=null:
		for item: Dictionary in monsters.interactions():
			if not item["art_rect"].has_point(at):continue
			if within_interaction(item["at"]):execute_interaction(item)
			else:
				var route: PackedVector2Array=monsters.approach(item["uid"],player.position)
				if route.is_empty():show_notice("请走近怪物，再按 E 战斗")
				else:pending_npc_talk="";player.path=route;pending_monster=item["uid"]
			return true
	if not interior_state.is_empty() and terrain.current_scene.npcs!=null:
		var selected: Dictionary={}
		var nearest:=INF
		for item: Dictionary in terrain.current_scene.npcs.interactions():
			if not item["art_rect"].has_point(at):continue
			var centre: Vector2=item["art_rect"].get_center()
			var distance:=centre.distance_squared_to(at)
			if distance<nearest:selected=item;nearest=distance
		if not selected.is_empty():
			if within_interaction(selected["at"]):execute_interaction(selected)
			else:
				var route: PackedVector2Array=terrain.current_scene.npcs.approach(selected["uid"],player.position)
				if route.is_empty():show_notice("请走近这位同学，再按 E 问候")
				else:player.path=route;pending_npc_talk=selected["uid"]
			return true
	for item: Dictionary in interactions():
		if not item.get("art_rect",Rect2()).has_point(at): continue
		if item["action"]=="lesson":
			if within_interaction(item["at"]):execute_interaction(item)
			else:
				player.path=approach_interaction(item["at"])
				show_notice("走到自己的座位后，按 E 上课")
		elif item["action"]=="board":
			if within_interaction(item["at"]):
				execute_interaction(item)
			else:
				request_path(item["at"])
				show_notice("到达告示牌后，按 E 打开全图传送")
		else: request_path(item["at"])
		return true
	return false

func interaction_text(item: Dictionary) -> String:
	if item["action"] in ["campaign","campaign_house","side_quest"]:return item.get("name","继续剧情")
	var story_hint: String=story_system.interaction_label(item)
	if not story_hint.is_empty():return story_hint
	match str(item.get("action","")):
		"lesson":return "坐到自己的座位上课"
		"monster":return "与"+str(item["name"])+"战斗"
		"npc":return "和"+str(item["name"])+"打招呼"
		"board": return "查看校园全图并传送"
		"entrance": return "进入"+str(interior_info["buildings"][item["building"]]["name"])
		"up": return "上楼"
		"down_left","down_right": return "下楼"
		"outside": return "返回校园"
		"room":
			var room: Dictionary=interior_info["buildings"][interior_state["building"]]["floors"][int(interior_state["floor"])-1]["rooms"][int(item["room"])]
			return "进入办公室" if room.get("office",false) else "进入教室"
		"corridor": return "返回走廊"
	return ""

func interact() -> void:
	if (phone!=null and phone.visible) or dialogue_view.visible or (battle_view!=null and battle_view.visible) or transition_busy or lesson_blocked() or nearby.is_empty() or interaction_delay>0:return
	execute_interaction(nearby)

func execute_interaction(item: Dictionary) -> void:
	if dialogue_view.visible or (battle_view!=null and battle_view.visible) or transition_busy or lesson_blocked() or not within_interaction(item["at"]):return
	if item["action"] in ["entrance","room","corridor","outside"]:sounds.play("door")
	elif item["action"] in ["npc","board"]:sounds.play("interact")
	if item["action"]=="npc" and not OS.get_cmdline_user_args().has("--manual-story-checks"):
		var record: Dictionary=terrain.current_scene.npcs.find(item["uid"])
		if not record.is_empty():relationships.open(record)
		return
	if campus_life.handle(item):return
	if campaign!=null and campaign.handle(item):return
	if story_system.handle(item):return
	var context: Dictionary=interior_state.duplicate()
	match str(item["action"]):
		"lesson":lesson_view.open()
		"monster":
			var manager: Node2D=active_monsters()
			if manager!=null:
				var record: Dictionary=manager.find(item["uid"])
				if not record.is_empty():battle_view.start(record,manager.key)
		"npc":
			var record: Dictionary=terrain.current_scene.npcs.find(item["uid"])
			if not record.is_empty():dialogue_view.greet(record)
		"board":
			map_view.open_map(true)
			player.frozen=true
		"entrance":
			change_interior({"building":item["building"],"floor":1,"kind":"corridor"})
		"room":
			context["kind"]="classroom"
			context["room"]=item["room"]
			change_interior(context,Vector2(INF,INF),str(item["side"]))
		"corridor":
			var room: Dictionary=interior_info["buildings"][context["building"]]["floors"][int(context["floor"])-1]["rooms"][int(context["room"])]
			var x: float=room[str(item["side"])+"_door_x"]
			context["kind"]="corridor"
			context.erase("room")
			change_interior(context,Vector2(x*24,122))
		"up","down_left","down_right":
			context["floor"]=int(context["floor"])+(1 if item["action"]=="up" else -1)
			var building: Dictionary=interior_info["buildings"][context["building"]]
			var source_x:=728.0 if item["action"]=="up" else 941.0
			var x:=float(building["stairs_center_x"])-72+(source_x-605)*144/670
			change_interior(context,Vector2(x,120))
		"outside":
			for entry: Dictionary in interior_info["entrances"]:
				if entry["id"]==context["building"]:
					teleport_outdoor(point(entry["arrival"])*24)
					break

func change_interior(context: Dictionary, landing: Vector2=Vector2(INF,INF), side: String="front") -> void:
	context=context.duplicate()
	context["floor"]=int(context["floor"])
	if context.has("room"):context["room"]=int(context["room"])
	if transition_busy or (battle_view!=null and battle_view.visible):return
	pending_npc_talk=""
	pending_monster=""
	if interior_state.is_empty():outdoor_zoom=player.camera.zoom.x
	transition_busy=true
	player.frozen=true
	player.path.clear()
	player.velocity=Vector2.ZERO
	var cover:=create_tween()
	cover.tween_property(fade,"modulate:a",1.0,.18)
	await cover.finished
	terrain.unload()
	await get_tree().process_frame
	var scene: Node2D=preload("res://campaign_room.gd").new() if context["building"] in ["B06","B15","STORY_HOUSE","STORY_SEAL"] else InteriorScene.new()
	if not scene.setup(interior_info,context,interior_directory,self):
		scene.free()
		fail("室内贴图加载失败")
		return
	terrain.add_child(scene)
	terrain.current_scene=scene
	terrain.current_id=-1
	terrain.active_texture_bytes=scene.texture_bytes
	terrain.transition_count+=1
	terrain.max_scene_count=maxi(terrain.max_scene_count,terrain.get_child_count())
	interior_state=context.duplicate()
	apply_time_lighting()
	player.position=scene.landing(side) if landing.x==INF else landing
	# Also repairs old saves made while stuck in the initiation cinematic.
	if not scene.navigation.walkable(player.position):place_player_safely(player.position)
	player.camera.limit_left=0
	player.camera.limit_top=0
	player.camera.limit_right=ceili(scene.dimensions.x)
	player.camera.limit_bottom=ceili(scene.dimensions.y)
	player.camera.zoom=Vector2.ONE*2.4
	apply_pending_restore()
	sync_monsters()
	restore_position_guard=true
	player.camera.reset_smoothing()
	interaction_delay=.7
	await get_tree().physics_frame
	restore_position_if_blocked()
	var reveal:=create_tween()
	reveal.tween_property(fade,"modulate:a",0.0,.22)
	await reveal.finished
	transition_busy=false
	refresh_player_freeze()

func safe_outdoor(at: Vector2) -> Vector2:
	if navigation.walkable(at) and navigation.region_at(at)>=0 and navigation.closest_cell(at).x>=0:return at
	for radius: int in range(1,21):
		for offset: Vector2 in [Vector2(0,radius),Vector2(radius,0),Vector2(-radius,0),Vector2(0,-radius)]:
			var candidate:=at+offset*24
			if navigation.walkable(candidate) and navigation.region_at(candidate)>=0 and navigation.closest_cell(candidate).x>=0:return candidate
	return spawn

func teleport_outdoor(at: Vector2) -> void:
	var destination:=safe_outdoor(at)
	player.path.clear()
	if map_view.visible: map_view.close_map()
	begin_transition(navigation.region_at(destination),destination)

func active_monsters() -> Node2D:
	return terrain.current_scene.monsters if terrain!=null and terrain.current_scene!=null and not interior_state.is_empty() else null

func sync_monsters() -> void:
	if terrain==null or terrain.current_scene==null or interior_state.is_empty():return
	var scene: Node2D=terrain.current_scene
	if interior_state.get("building")=="B02" and story_system.blocks_lab_spawns():
		if scene.monsters!=null:scene.monsters.queue_free();scene.monsters=null
		return
	if scene.monsters==null:
		if monster_world.zone_rule(interior_state).is_empty():return
		scene.monsters=MonsterScene.new();scene.add_child(scene.monsters)
		scene.monsters.setup(self,scene)
	else:scene.monsters.refresh()

# Event API: overrides may enable/disable a scene, change level, count, or
# bounds [x,y,width,height] in local map pixels. No story is introduced here.
func story_blocked() -> bool:
	return story_system!=null and story_system.running

func bind_story_objective(value: Label) -> void:
	if story_system!=null:story_system.objective=value;story_system.refresh_objective()

func set_monster_region(context: Dictionary, patch: Dictionary) -> void:
	monster_world.set_zone_rule(context,patch)
	if monster_world.zone_key(context)==monster_world.zone_key(interior_state):sync_monsters()
